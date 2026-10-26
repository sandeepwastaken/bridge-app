import SwiftUI

struct SpeakView: View {
    let mode: TalkMode
    @ObservedObject var model: TalkModel
    @ObservedObject var recognizer: SpeechRecognizer
    @ObservedObject var settings: AppSettings
    @ObservedObject var speaker: Speaker
    let access: AccessController

    @State private var isFixing = false
    @State private var fixWord: String?
    @State private var isTyping = false
    @State private var isShowing = false
    @State private var isShowingHistory = false
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    init(mode: TalkMode, model: TalkModel, access: AccessController) {
        self.mode = mode
        self.model = model
        self.recognizer = model.recognizer
        self.settings = model.settings
        self.speaker = model.speaker
        self.access = access
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                if typeSize >= .xxLarge { controls }
                if mode == .translate { languageSwitch }
                wordsCard
            }
            .padding(Theme.gutter)
        }
        .accessScrolling()
        .background(Theme.background)
        .navigationTitle(mode == .translate ? "Translate" : "Speak for me")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isShowingHistory = true } label: { Label("Earlier", systemImage: "clock.arrow.circlepath") }
                    .accessibilityLabel("Earlier words")
                    .accessTarget("earlier", label: "Earlier words", order: 20) { isShowingHistory = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if typeSize < .xxLarge { controls }
        }
        .onAppear { if model.mode != mode { model.mode = mode } }
        .onChange(of: model.phase) { _, phase in announce(phase) }
        .sheet(isPresented: $isFixing) {
            if let message = model.current {
                FixWordsSheet(message: message, words: model.words, initialWord: fixWord) { text, remember, changed in
                    Task { await model.applyFix(text: text, remember: remember, wordsChanged: changed) }
                }
                .accessHost("fix", controller: access)
            }
        }
        .sheet(isPresented: $isTyping) {
            TypeSheet(language: model.sourceLanguage) { text in Task { await model.useTyped(text) } }
                .accessHost("type", controller: access)
        }
        .sheet(isPresented: $isShowingHistory) {
            HistorySheet(history: model.history, model: model)
                .accessHost("history", controller: access)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowing) {
            if let message = model.current {
                ShowView(message: message).accessHost("show", controller: access)
            }
        }
        #endif
    }

    private var languageSwitch: some View {
        Button(action: swapLanguages) {
            HStack(spacing: Theme.Space.md) {
                languageLabel("From", settings.myLanguage)
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.accent)
                languageLabel("To", settings.partnerLanguage)
            }
            .frame(maxWidth: .infinity)
            .card(padding: Theme.Space.md, radius: Theme.Radius.lg)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(model.isLive)
        .accessibilityLabel("From \(settings.myLanguage.englishName) to \(settings.partnerLanguage.englishName)")
        .accessibilityHint("Swaps the two languages.")
        .accessTarget("swap", label: "Swap languages", order: 0, action: swapLanguages)
    }

    private func languageLabel(_ caption: String, _ language: Language) -> some View {
        VStack(spacing: 2) {
            Text(caption).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Text(language.nativeName).font(.title2.weight(.bold)).foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func swapLanguages() {
        let mine = settings.myLanguage
        settings.myLanguage = settings.partnerLanguage
        settings.partnerLanguage = mine
    }

    private var wordsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                status
                Spacer()
                if model.phase == .listening { LevelBars(level: recognizer.level) }
            }
            .frame(minHeight: 32)

            words

            if let message = model.current, let target = message.targetLanguage {
                Divider().padding(.vertical, Theme.Space.xs)
                Text("In \(target.englishName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                if let translation = message.translation {
                    Text(readAlong(translation, active: model.phase == .speaking))
                        .font(Theme.message(for: translation))
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                } else if model.phase == .translating {
                    ProgressView().controlSize(.large)
                } else if message.translationFailed {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        Text("Couldn't translate into \(target.englishName). Say it will use \(message.sourceLanguage.englishName).")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Try translating again") { Task { await model.retryTranslation() } }
                            .buttonStyle(.pillSecondary)
                            .disabled(model.isLive)
                            .accessTarget("retry-translation", label: "Try translating again", order: 9) {
                                Task { await model.retryTranslation() }
                            }
                    }
                }
            }

            if let message = model.current { notes(message) }

            #if os(iOS)
            if let message = model.current, !model.isLive {
                Divider().padding(.vertical, Theme.Space.xs)
                SendActions(text: message.translation ?? message.text)
            }
            #endif
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .card()
        .animation(.easeOut(duration: 0.25), value: model.current?.id)
    }

    @ViewBuilder private var status: some View {
        switch model.phase {
        case .listening: StatusPill(text: "Listening", dot: Theme.recording)
        case .speaking: StatusPill(text: "Speaking")
        case .translating: StatusPill(text: "Translating")
        case .review: StatusPill(text: "Ready to say")
        case .idle where model.current?.wasSpoken == true: StatusPill(text: "Said")
        default: EmptyView()
        }
    }

    @ViewBuilder private var words: some View {
        switch model.phase {
        case .listening:
            Text(recognizer.partial.isEmpty ? "Listening…" : recognizer.partial)
                .font(Theme.message(for: recognizer.partial))
                .foregroundStyle(recognizer.partial.isEmpty ? Theme.textSecondary : Theme.textPrimary)
        case .failed(let failure) where model.current == nil:
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text(failure.message)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                #if os(iOS)
                if failure == .permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(url) }.buttonStyle(.pillSecondary)
                        .accessTarget("open-settings", label: "Open Settings", order: 9) { openURL(url) }
                }
                #endif
            }
        default:
            if let message = model.current {
                Text(Self.attributed(message, spoken: model.phase == .speaking && message.translation == nil
                                     ? model.speaker.spokenRange : nil))
                    .font(Theme.message(for: message.text))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.textPrimary)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == "bridge-fix" else { return .systemAction }
                        fixWord = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == "w" })?.value
                        isFixing = true
                        return .handled
                    })
                    .accessibilityLabel(message.text)
            } else if model.needsPermissionPrimer {
                Text("Tap Talk, then speak.")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text(mode == .translate
                     ? "Tap Talk, then speak \(settings.myLanguage.englishName)."
                     : "Tap Talk, then speak.")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder private func notes(_ message: Message) -> some View {
        if !message.uncertainWords.isEmpty, model.phase == .review {
            Label("Tap a highlighted word to fix it.", systemImage: "questionmark.circle")
                .font(.body).foregroundStyle(Theme.textSecondary)
        }
        if !message.replacements.isEmpty {
            Label("Changed " + message.replacements.map { "\($0.heard) to \($0.saved)" }.joined(separator: ", ") + ".",
                  systemImage: "character.book.closed")
                .font(.body).foregroundStyle(Theme.textSecondary)
        }
    }

    static func attributed(_ message: Message, spoken: NSRange? = nil) -> AttributedString {
        if let spoken, let range = Range(spoken, in: message.text) {
            var text = AttributedString(message.text)
            if let attrRange = Range(range, in: text) {
                text[attrRange].backgroundColor = Theme.accent.opacity(0.18)
                text[attrRange].foregroundColor = Theme.accent
            }
            return text
        }
        let ns = message.text as NSString
        let uncertain = Set(message.uncertainWords)
        var result = AttributedString()
        var cursor = 0
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byWords) { word, range, _, _ in
            guard let word, uncertain.contains(word.lowercased()) else { return }
            result += AttributedString(ns.substring(with: NSRange(location: cursor, length: range.location - cursor)))
            var chip = AttributedString("\u{202F}\(word)\u{202F}")
            chip.backgroundColor = Theme.unsure
            var link = URLComponents()
            link.scheme = "bridge-fix"
            link.host = "word"
            link.queryItems = [URLQueryItem(name: "w", value: word)]
            chip.link = link.url
            result += chip
            cursor = range.location + range.length
        }
        result += AttributedString(ns.substring(from: cursor))
        return result
    }

    private func readAlong(_ text: String, active: Bool) -> AttributedString {
        var attributed = AttributedString(text)
        if active, let spoken = model.speaker.spokenRange, let range = Range(spoken, in: text),
           let attrRange = Range(range, in: attributed) {
            attributed[attrRange].backgroundColor = Theme.accent.opacity(0.18)
            attributed[attrRange].foregroundColor = Theme.accent
        }
        return attributed
    }

    private var controls: some View {
        let layout = typeSize >= .xxLarge
            ? AnyLayout(VStackLayout(spacing: Theme.Space.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Space.md))
        return layout {
            if typeSize >= .xxLarge {
                main
                left
                if model.current != nil && !model.isLive { right }
            } else {
                left.frame(maxWidth: .infinity)
                main.frame(maxWidth: .infinity)
                right.frame(maxWidth: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, typeSize >= .xxLarge ? 0 : Theme.gutter)
        .padding(.top, Theme.Space.md)
        .padding(.bottom, Theme.Space.sm)
        .background(.bar)
    }

    @ViewBuilder private var main: some View {
        switch model.phase {
        case .listening:
            control("Stop", "stop.fill", .main, tint: Theme.recording, filled: true, order: 10) { model.talkTapped() }
        case .speaking:
            control("Stop", "stop.fill", .main, tint: Theme.recording, filled: true, order: 10) { model.stopSpeaking() }
        case .translating:
            control("Translating", "ellipsis", .main, filled: true, order: 10) {}.disabled(true)
        case .review:
            control(sayTitle, "speaker.wave.2.fill", .main, filled: true, order: 10) { Task { await model.sayItAloud() } }
        case .failed:
            control("Try again", "mic.fill", .main, filled: true, order: 10) { talk() }
        case .idle:
            control("Talk", "mic.fill", .main, filled: true, order: 10) { talk() }
        }
    }

    @ViewBuilder private var left: some View {
        switch model.phase {
        case .listening:
            control("Cancel", "xmark", order: 11) { model.cancelListening() }
        case .review, .translating, .speaking:
            control("Fix words", "pencil", order: 11) { fixWord = nil; isFixing = true }
                .disabled(model.phase == .speaking)
        case .idle where model.current?.wasSpoken == true:
            control("Say again", "arrow.counterclockwise", order: 11) { Task { await model.sayItAloud() } }
        default:
            control("Type", "keyboard", order: 11) { isTyping = true }
        }
    }

    @ViewBuilder private var right: some View {
        if model.current != nil && !model.isLive {
            control("Show big", "arrow.up.left.and.arrow.down.right", order: 12) { isShowing = true }
        } else {
            Color.clear
                .frame(width: 88, height: 110)
                .accessibilityHidden(true)
        }
    }

    private func control(_ title: String, _ symbol: String, _ size: CircleControl.Size = .side,
                         tint: Color = Theme.accent, filled: Bool = false,
                         order: Int, action: @escaping () -> Void) -> some View {
        CircleControl(title: title, symbol: symbol, size: size, tint: tint, filled: filled, action: action)
            .accessTarget("control-\(order)", label: title, order: order, action: action)
    }

    private var sayTitle: String {
        guard mode == .translate, let language = model.willSpeakIn else { return "Speak my words" }
        return "Say in \(language.englishName)"
    }

    private func talk() {
        if model.needsPermissionPrimer {
            Task { await model.allowMicrophone() }
        } else {
            model.talkTapped()
        }
    }

    private func announce(_ phase: TalkModel.Phase) {
        let text: String? = switch phase {
        case .listening: "Listening"
        case .speaking: "Speaking"
        case .review: "Ready. Tap \(sayTitle)."
        case .failed(let failure): failure.message
        default: nil
        }
        if let text { AccessibilityNotification.Announcement(text).post() }
    }
}

struct HistorySheet: View {
    @ObservedObject var history: HistoryStore
    let model: TalkModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(history.messages.reversed()) { message in
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text).font(.title3.weight(.semibold))
                    if let translation = message.translation {
                        Text(translation).font(.title3).foregroundStyle(Theme.textSecondary)
                    }
                    Text(message.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
            .overlay {
                if history.messages.isEmpty {
                    ContentUnavailableView("Nothing yet", systemImage: "clock",
                                           description: Text("Things you say show up here."))
                }
            }
            .navigationTitle("Earlier words")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .safeAreaInset(edge: .bottom) {
                Button("Done") { dismiss() }
                    .buttonStyle(.pill)
                    .padding(Theme.gutter)
                    .accessTarget("done", label: "Done") { dismiss() }
            }
        }
    }
}
