import SwiftUI

struct QuickPhrase: Identifiable, Hashable {
    let id: String
    let english: String
    let hindi: String
    let symbol: String
    var onlyIn: Language? = nil

    func text(in language: Language, translated: String? = nil) -> String {
        if let onlyIn { return onlyIn == .english ? english : hindi }
        if language == .english { return english }
        if language == .hindi { return hindi }
        return translated ?? english
    }

    func spokenLanguage(for language: Language) -> Language { onlyIn ?? language }
}

struct PhraseGroup: Identifiable {
    let id: String
    let title: String
    let phrases: [QuickPhrase]
}

enum PhraseBook {
    static let groups: [PhraseGroup] = [
        PhraseGroup(id: "now", title: "Right now", phrases: [
            QuickPhrase(id: "yes", english: "Yes", hindi: "हाँ", symbol: "checkmark.circle.fill"),
            QuickPhrase(id: "no", english: "No", hindi: "नहीं", symbol: "xmark.circle.fill"),
            QuickPhrase(id: "help", english: "Please help me.", hindi: "कृपया मेरी मदद करें।", symbol: "hand.raised.fill"),
            QuickPhrase(id: "wait", english: "Please wait a moment.", hindi: "कृपया थोड़ा रुकिए।", symbol: "clock.fill"),
            QuickPhrase(id: "slow", english: "Please speak slowly.", hindi: "कृपया धीरे बोलिए।", symbol: "tortoise.fill"),
            QuickPhrase(id: "repeat", english: "Could you say that again?", hindi: "क्या आप फिर से कहेंगे?", symbol: "arrow.counterclockwise"),
            QuickPhrase(id: "thanks", english: "Thank you.", hindi: "धन्यवाद।", symbol: "heart.fill"),
            QuickPhrase(id: "understand", english: "I don't understand.", hindi: "मुझे समझ नहीं आया।", symbol: "questionmark.circle.fill"),
        ]),
        PhraseGroup(id: "need", title: "I need", phrases: [
            QuickPhrase(id: "water", english: "I need some water.", hindi: "मुझे पानी चाहिए।", symbol: "drop.fill"),
            QuickPhrase(id: "bathroom", english: "I need to use the bathroom.", hindi: "मुझे बाथरूम जाना है।", symbol: "toilet.fill"),
            QuickPhrase(id: "medicine", english: "It's time for my medicine.", hindi: "मेरी दवा का समय हो गया है।", symbol: "pills.fill"),
            QuickPhrase(id: "food", english: "I'm hungry.", hindi: "मुझे भूख लगी है।", symbol: "fork.knife"),
            QuickPhrase(id: "glasses", english: "Where are my glasses?", hindi: "मेरा चश्मा कहाँ है?", symbol: "eyeglasses"),
            QuickPhrase(id: "rest", english: "I'd like to lie down.", hindi: "मुझे लेटना है।", symbol: "bed.double.fill"),
            QuickPhrase(id: "family", english: "Please call my family.", hindi: "कृपया मेरे परिवार को फ़ोन करें।", symbol: "phone.fill"),
            QuickPhrase(id: "cold", english: "I'm feeling cold.", hindi: "मुझे ठंड लग रही है।", symbol: "thermometer.snowflake"),
        ]),
        PhraseGroup(id: "feel", title: "I feel", phrases: [
            QuickPhrase(id: "good", english: "I'm feeling good.", hindi: "मैं ठीक हूँ।", symbol: "sun.max.fill"),
            QuickPhrase(id: "tired", english: "I'm tired.", hindi: "मुझे थकान हो रही है।", symbol: "moon.zzz.fill"),
            QuickPhrase(id: "pain", english: "I'm in pain.", hindi: "मुझे दर्द हो रहा है।", symbol: "bandage.fill"),
            QuickPhrase(id: "dizzy", english: "I feel dizzy.", hindi: "मुझे चक्कर आ रहा है।", symbol: "tornado"),
        ]),
    ]

    static var lookToChoose: [QuickPhrase] { Array((groups[0].phrases + groups[1].phrases).prefix(16)) }
    static var all: [QuickPhrase] { groups.flatMap(\.phrases) }
}

struct QuickPhrasesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var model: TalkModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var words: WordStore
    let access: AccessController
    @State private var lookToChoose = false
    @State private var translatedPhrases: [String: String] = [:]
    @State private var phraseTranslationFailed = false

    init(model: TalkModel, access: AccessController) {
        self.model = model
        self.settings = model.settings
        self.words = model.words
        self.access = access
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                SayInPicker(selection: $settings.phraseLanguage, languages: settings.supportedLanguages)
                if settings.phraseLanguage != .english && settings.phraseLanguage != .hindi {
                    Text(phraseTranslationFailed
                         ? "Some phrases couldn't be translated into \(settings.phraseLanguage.englishName). Check language availability in Settings."
                         : (translatedPhrases.count < PhraseBook.all.count ? "Preparing phrases in \(settings.phraseLanguage.englishName)…" : "Phrases are ready in \(settings.phraseLanguage.englishName)."))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityIdentifier("phrases.translationStatus")
                }

                Button { lookToChoose = true } label: {
                    Label("Turn your head to choose", systemImage: "face.smiling")
                }
                .buttonStyle(.pillSecondary)
                .accessTarget("look", label: "Turn your head to choose", order: -1) { lookToChoose = true }

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        Text(group.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: Theme.Space.md) {
                                ForEach(group.phrases) { phrase in phraseTile(phrase) }
                            }
                        } else {
                            Grid(horizontalSpacing: Theme.Space.md, verticalSpacing: Theme.Space.md) {
                                ForEach(Array(stride(from: 0, to: group.phrases.count, by: 2)), id: \.self) { start in
                                    GridRow {
                                        ForEach(group.phrases[start..<min(start + 2, group.phrases.count)]) { phrase in
                                            phraseTile(phrase)
                                        }
                                        if start + 1 >= group.phrases.count { Color.clear }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.gutter)
            .padding(.bottom, 120)
        }
        .accessScrolling()
        .background(Theme.background)
        .navigationTitle("Quick phrases")
        .overlay(alignment: .bottom) { nowSaying }
        .task(id: settings.phraseLanguage.rawValue) { await preparePhrases() }
        #if os(iOS)
        .fullScreenCover(isPresented: $lookToChoose) {
            LookToChooseView(model: model, access: access)
                .accessHost("look", controller: access)
        }
        #endif
    }

    private var groups: [PhraseGroup] {
        let mine = words.entries(of: .phrase).map {
            QuickPhrase(id: $0.id.uuidString, english: $0.text, hindi: $0.text,
                        symbol: "star.fill", onlyIn: $0.language)
        }
        return (mine.isEmpty ? [] : [PhraseGroup(id: "mine", title: "My phrases", phrases: mine)]) + PhraseBook.groups
    }

    private func isSaying(_ phrase: QuickPhrase) -> Bool {
        model.phase == .speaking && model.current?.text == phrase.text(in: settings.phraseLanguage, translated: translatedPhrases[phrase.id])
    }

    private func phraseTile(_ phrase: QuickPhrase) -> some View {
        let translated = translatedPhrases[phrase.id]
        let supported = phrase.onlyIn != nil || settings.phraseLanguage == .english
            || settings.phraseLanguage == .hindi || translated != nil
        return PhraseTile(phrase: phrase, language: settings.phraseLanguage,
                   saysIn: phrase.spokenLanguage(for: settings.phraseLanguage),
                   isSaying: isSaying(phrase), translatedText: translated,
                   enabled: supported) { say(phrase) }
            .accessTarget(phrase.id, label: phrase.text(in: settings.phraseLanguage, translated: translated)) { say(phrase) }
    }

    private func say(_ phrase: QuickPhrase) {
        let language = phrase.spokenLanguage(for: settings.phraseLanguage)
        let translated = translatedPhrases[phrase.id]
        guard language == .english || language == .hindi || phrase.onlyIn != nil || translated != nil else { return }
        Task { await model.speakNow(phrase.text(in: language, translated: translated), in: language) }
    }

    private func preparePhrases() async {
        translatedPhrases = [:]
        phraseTranslationFailed = false
        let target = settings.phraseLanguage
        guard target != .english, target != .hindi else { return }
        for phrase in PhraseBook.all {
            do {
                let result = try await model.translator.translate(phrase.english, from: .english, to: target)
                translatedPhrases[phrase.id] = result
            } catch {
                phraseTranslationFailed = true
                return
            }
        }
    }

    @ViewBuilder private var nowSaying: some View {
        if model.phase == .speaking, let message = model.current {
            HStack(spacing: Theme.Space.md) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.variableColor.iterative)
                Text(message.text)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Stop") { model.stopSpeaking() }
                    .accessibilityIdentifier("phrases.stop")
                    .font(.headline)
                    .frame(minWidth: 64, minHeight: 44)
                    .accessTarget("stop", label: "Stop", order: -2) { model.stopSpeaking() }
            }
            .card(padding: Theme.Space.md, radius: Theme.Radius.lg)
            .padding(Theme.gutter)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

private struct PhraseTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let phrase: QuickPhrase
    let language: Language
    let saysIn: Language
    let isSaying: Bool
    var translatedText: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Image(systemName: isSaying ? "speaker.wave.3.fill" : phrase.symbol)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(height: 36)
                Spacer(minLength: 0)
                line(phrase.text(in: language, translated: translatedText), spoken: saysIn == language, primary: true)
                if phrase.onlyIn == nil {
                    line(language == .english ? phrase.hindi : phrase.english, spoken: saysIn != language, primary: false)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
            .card(padding: Theme.Space.md, radius: Theme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: isSaying ? 3 : 0)
            )
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .accessibilityLabel(phrase.text(in: language, translated: translatedText))
        .accessibilityHint(saysIn == language ? "Says this out loud." : "Says this out loud in \(saysIn.englishName).")
    }

    private var minimumHeight: CGFloat {
        switch dynamicTypeSize {
        case .accessibility5: 344
        case .accessibility4: 304
        case .accessibility3: 264
        case .accessibility2: 224
        case .accessibility1: 192
        case .xxxLarge: 164
        default: 132
        }
    }

    private func line(_ text: String, spoken: Bool, primary: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if spoken {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(primary ? .title3.weight(.semibold) : .subheadline.weight(spoken ? .semibold : .regular))
                .foregroundStyle(primary || spoken ? Theme.textPrimary : Theme.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SayInPicker: View {
    @Binding var selection: Language
    let languages: [Language]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Say phrases in")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Menu {
                ForEach(languages) { language in
                    Button("\(language.nativeName) · \(language.englishName)") { selection = language }
                        .accessibilityIdentifier("sayin.\(language.rawValue)")
                }
            } label: {
                HStack {
                    Text(selection.nativeName).font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.headline)
                }
                .padding(.horizontal, Theme.Space.md)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1))
            }
            .accessibilityIdentifier("phrases.languagePicker")
            .accessPicker("sayin", label: "Say phrases in", order: -3, selection: $selection,
                          options: languages) { "\($0.nativeName) · \($0.englishName)" }
        }
    }
}

struct LookToChooseView: View {
    @ObservedObject var model: TalkModel
    @ObservedObject var access: AccessController
    @Environment(\.dismiss) private var dismiss

    @State private var choices = PhraseBook.lookToChoose
    @State private var chosen: QuickPhrase?
    @State private var armed = true
    @State private var leaning: Side?
    @State private var translations: [String: String] = [:]
    @State private var translationFailed = false

    private var phraseLanguage: Language { model.settings.phraseLanguage }
    private var needsTranslation: Bool { phraseLanguage != .english && phraseLanguage != .hindi }
    private var left: [QuickPhrase] { Array(choices.prefix(choices.count / 2)) }
    private var right: [QuickPhrase] { Array(choices.suffix(choices.count - choices.count / 2)) }

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            header
            if let chosen {
                chosenCard(chosen)
            } else {
                HStack(spacing: Theme.Space.md) {
                    column(left, side: .me, title: "Look left", symbol: "arrow.left")
                    column(right, side: .partner, title: "Look right", symbol: "arrow.right")
                }
            }
            ButtonRow {
                Button("Start over") { reset() }
                    .buttonStyle(.pillSecondary)
                    .accessTarget("restart", label: "Start over", order: 1) { reset() }
                Button("Done") { dismiss() }
                    .buttonStyle(.pill)
                    .accessTarget("done", label: "Done", order: 2) { dismiss() }
            }
        }
        .padding(Theme.gutter)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { access.useHead("look", true) }
        .onDisappear { access.useHead("look", false) }
        .onChange(of: access.lastSample) { _, sample in
            if let sample { follow(sample) }
        }
        .task(id: phraseLanguage.rawValue) { await prepareLookPhrases() }
    }

    private var header: some View {
        VStack(spacing: Theme.Space.sm) {
            Text(chosen == nil ? "Turn your head toward your phrase" : "Saying it now")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
            Text(HeadTracker.isSupported
                 ? "Turn your head left or right, then back to the middle. Look up to start over."
                 : "Tap the side with your phrase.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            if needsTranslation {
                Text(translationFailed ? "Phrases aren't available in \(phraseLanguage.englishName) right now."
                     : (translations.count == PhraseBook.lookToChoose.count ? "Phrases are ready in \(phraseLanguage.englishName)."
                        : "Preparing phrases in \(phraseLanguage.englishName)…"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, Theme.Space.md)
    }

    private func column(_ phrases: [QuickPhrase], side: Side, title: String, symbol: String) -> some View {
        Button { pick(side) } label: {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .padding(.bottom, Theme.Space.xs)
                ForEach(phrases) { phrase in
                    Text(phrase.text(in: phraseLanguage, translated: translations[phrase.id]))
                        .font(phrases.count <= 2 ? .title2.weight(.bold) : .body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .card(padding: Theme.Space.md, radius: Theme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: leaning == side ? 4 : 0)
            )
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("\(title): " + phrases.map { $0.text(in: phraseLanguage, translated: translations[$0.id]) }.joined(separator: ", "))
        .accessibilityIdentifier(side == .me ? "look.left" : "look.right")
        .disabled(needsTranslation && translations.count < PhraseBook.lookToChoose.count)
        .accessTarget("side-\(side.rawValue)", label: title, order: 0) { pick(side) }
    }

    private func chosenCard(_ phrase: QuickPhrase) -> some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(phrase.text(in: phraseLanguage, translated: translations[phrase.id]))
                .font(Theme.message(for: phrase.text(in: phraseLanguage, translated: translations[phrase.id])))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
            if phraseLanguage != .english {
                Label(phrase.english, systemImage: "text.quote")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            Button("Say it again") { say(phrase) }
                .buttonStyle(.pill)
                .accessTarget("again", label: "Say it again", order: 0) { say(phrase) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card()
    }

    private func pick(_ side: Side) {
        guard chosen == nil else { return }
        let next = side == .me ? left : right
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if next.count == 1 {
                chosen = next[0]
            } else {
                choices = next
            }
            leaning = nil
        }
        Haptics.selection()
        if let chosen { say(chosen) }
    }

    private func reset() {
        withAnimation { choices = PhraseBook.lookToChoose; chosen = nil; leaning = nil }
    }

    private func say(_ phrase: QuickPhrase) {
        let spoken = phraseLanguage
        let translated = translations[phrase.id]
        guard spoken == .english || spoken == .hindi || translated != nil else { return }
        Task { await model.speakNow(phrase.text(in: spoken, translated: translated), in: spoken) }
    }

    private func prepareLookPhrases() async {
        translations = [:]
        translationFailed = false
        guard needsTranslation else { return }
        for phrase in PhraseBook.lookToChoose {
            do {
                translations[phrase.id] = try await model.translator.translate(phrase.english, from: .english, to: phraseLanguage)
            } catch {
                translationFailed = true
                return
            }
        }
    }

    private func follow(_ sample: HeadTracker.Sample) {
        let yaw = sample.yaw
        leaning = yaw < -0.15 ? .me : (yaw > 0.15 ? .partner : nil)
        if armed {
            if yaw < -0.3 { armed = false; pick(.me) }
            else if yaw > 0.3 { armed = false; pick(.partner) }
            else if sample.pitch > 0.3 { armed = false; reset() }
        } else if abs(yaw) < 0.1 && abs(sample.pitch) < 0.12 {
            armed = true
        }
    }
}
