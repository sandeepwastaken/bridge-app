import SwiftUI

struct AssistView: View {
    @ObservedObject var router: Router
    @ObservedObject var settings: AppSettings
    @ObservedObject var model: TalkModel
    var startWithVoice = false
    @State private var request = ""
    @State private var voiceNote = ""
    @State private var listening: Task<Void, Never>?
    @StateObject private var recognizer = SpeechRecognizer()
    @FocusState private var requestFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image("BridgeBuddy").resizable().scaledToFit().frame(height: 200)
                Text("Hello. What do you need?").font(.title2.weight(.semibold))
                HStack {
                    TextField("Ask for help", text: $request, prompt: Text("Ask for help").foregroundStyle(Theme.textSecondary))
                        .foregroundStyle(Theme.textPrimary).submitLabel(.go).onSubmit(openRequest)
                        .focused($requestFocused)
                        .accessTarget("request", label: "Ask for help", order: 2) { requestFocused = true }
                    Button(action: openRequest) { Image(systemName: "arrow.up").frame(width: 44,height: 44) }
                        .accessibilityLabel("Use request")
                        .accessTarget("use-request", label: "Use request", order: 2, action: openRequest)
                }.card(padding: 12)
                Button(action: toggleVoice) {
                    Label(recognizer.isListening ? "Listening… tap to stop" : "Use my voice",
                          systemImage: recognizer.isListening ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(.pill)
                .accessibilityIdentifier("assist.voice")
                .accessTarget("use-voice", label: "Use my voice", order: 3, action: toggleVoice)
                if recognizer.isListening, !recognizer.partial.isEmpty {
                    Text(recognizer.partial).font(.title3).foregroundStyle(Theme.textPrimary)
                }
                if !voiceNote.isEmpty {
                    Text(voiceNote).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                Text("Try saying Open translate, Read something, Prepare a message followed by your words, or Call someone. You review messages and calls before sending or dialing.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
                choice("Read something", "book", .read)
                choice("Help with a task", "checklist", .guide)
                choice("Speak for me", "mic", .speak)
                choice("Translate", "character.bubble", .translate)
                choice("My Words", "bookmark", .words)
                choice("Microphone captions", "captions.bubble", .captions)
                choice("Floating assistant", "iphone", .overlay)
            }.padding(Theme.gutter).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.accessScrolling().background(Theme.background)
            .navigationTitle(startWithVoice ? "Use my voice" : "Assist")
            .task { if startWithVoice { toggleVoice() } }
            .onDisappear { listening?.cancel(); recognizer.cancel() }
    }

    private func toggleVoice() {
        if recognizer.isListening {
            recognizer.finish()
            return
        }
        voiceNote = ""
        listening = Task { @MainActor in
            guard await SpeechRecognizer.requestPermission() else {
                voiceNote = "Microphone access is off. You can type your request instead."
                return
            }
            guard !Task.isCancelled else { return }
            do {
                let heard = try await recognizer.listen(in: settings.myLanguage, contextualStrings: Self.commands)
                guard !Task.isCancelled else { return }
                request = heard.text
                if Self.route(for: heard.text) == nil && !["home", "go home", "open home", "go back"].contains(heard.text.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
                    voiceNote = "I heard \"\(heard.text)\". Try Open translate or Read something."
                }
                openRequest()
            } catch {
                if !Task.isCancelled { voiceNote = "I didn't catch that. Try again or type your request." }
            }
        }
    }

    static let commands = ["Open translate", "Read something", "Speak for me", "Talk together", "Quick phrases",
                           "My Words", "Help with a form", "Captions", "Settings", "Floating assistant", "Call someone", "Go home"]

    static func route(for text: String) -> Route? {
        if message(in: text) != nil { return .speak }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("call ") || text.hasPrefix("please call ") {
            return .call(text.filter { $0.isASCII && ($0.isNumber || $0 == "+") })
        }
        if text.contains("talk together") || text.contains("conversation") { return .talk }
        if text.contains("translat") { return .translate }
        if text.contains("caption") { return .captions }
        if text.contains("overlay") || text.contains("floating assistant") || text.contains("phone control") { return .overlay }
        if text.contains("read") || text.contains("understand") || text.contains("explain") { return .read }
        if text.contains("phrase") { return .phrases }
        if text.contains("word") { return .words }
        if text.contains("setting") { return .settings }
        if text.contains("form") || text.contains("task") || text.contains("help") { return .guide }
        if text.contains("speak") || text.contains("say") { return .speak }
        return nil
    }

    static func message(in request: String) -> String? {
        let request = request.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["prepare a message ", "send a message ", "text ", "say "] {
            if request.lowercased().hasPrefix(prefix) {
                let message = String(request.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return message.isEmpty ? nil : message
            }
        }
        return nil
    }

    private func choice(_ title: String, _ symbol: String, _ route: Route) -> some View {
        Button { router.open(route) } label: {
            Label(title, systemImage: symbol).font(.body).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).card(padding: 14, radius: 22)
        }.buttonStyle(PressScaleStyle()).foregroundStyle(Theme.textPrimary)
            .accessTarget("choice-\(String(describing: route))", label: title, order: 1) { router.open(route) }
    }

    private func openRequest() {
        if let message = Self.message(in: request) {
            Task { @MainActor in
                model.mode = .speak
                await model.useTyped(message)
                router.open(.speak)
            }
            return
        }
        let command = request.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if ["home", "go home", "open home"].contains(command) { router.path = []; return }
        if command == "go back" { if !router.path.isEmpty { router.path.removeLast() }; return }
        if let route = Self.route(for: request) { router.open(route) }
        else { voiceNote = "Try Open translate, Read something, Prepare a message, or Call someone." }
    }
}

struct GuidanceView: View {
    let settings: AppSettings
    let speaker: Speaker
    @State private var step = 0
    private let steps = [
        ("Read the instructions", "Check who the form is for and what information it asks you to provide. Keep the original page open."),
        ("Take one field at a time", "Use your own details. If a question is unclear, ask the organization before guessing."),
        ("Check before submitting", "Review names, dates and contact details. You choose whether to submit.")
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image("BridgeBuddy").resizable().scaledToFit().frame(height: 130).frame(maxWidth: .infinity)
                ProgressView(value: Double(step + 1), total: Double(steps.count))
                Text("Fill in a form · Step \(step + 1) of \(steps.count)").font(.subheadline).foregroundStyle(Theme.textSecondary)
                VStack(alignment: .leading, spacing: 16) {
                    Text(steps[step].0).font(.title2.weight(.semibold))
                    Text(steps[step].1).font(.body)
                    Button(step == 2 ? "Start again" : "Next step", action: nextStep).buttonStyle(.pill)
                        .accessTarget("next-step", label: step == 2 ? "Start again" : "Next step", order: 1, action: nextStep)
                    Button("Read aloud", action: readAloud).buttonStyle(.pillSecondary)
                        .accessTarget("read-aloud", label: "Read aloud", order: 2, action: readAloud)
                }.card()
                Button("Previous step", action: previousStep).disabled(step == 0)
                    .frame(minHeight: 44)
                    .accessTarget("previous-step", label: "Previous step", order: 3, action: previousStep)
                Text("You stay in control. Bridge does not submit a form for you.").font(.footnote).foregroundStyle(Theme.textSecondary)
            }.padding(Theme.gutter).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.accessScrolling().background(Theme.background).navigationTitle("A little guidance").onDisappear { speaker.stop() }
    }

    private func nextStep() { speaker.stop(); step = (step + 1) % steps.count }
    private func previousStep() { speaker.stop(); step = max(0, step - 1) }
    private func readAloud() {
        let text = steps[step].0 + ". " + steps[step].1
        Task { await speaker.speak(text, in: .english, rate: settings.speechRate) }
    }
}

struct MicrophoneCaptionsView: View {
    @StateObject private var recognizer = SpeechRecognizer()
    let settings: AppSettings
    @ObservedObject var translator: Translator
    @Environment(\.scenePhase) private var scenePhase
    @State private var transcript = ""
    @State private var feedback = ""
    @State private var capture: Task<Void, Never>?
    @State private var running = false
    @State private var translateCaptions = false
    @State private var translated = ""
    @State private var translation: Task<Void, Never>?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Follow a conversation").font(.title2.weight(.semibold))
                Text("This listens to your microphone. It cannot capture protected audio inside FaceTime or WhatsApp.").foregroundStyle(Theme.textSecondary)
                Text(running ? "Microphone on" : "Microphone off").font(.headline)
                Text(recognizer.partial.isEmpty ? transcript : recognizer.partial).font(.title2).textSelection(.enabled).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading).card()
                Toggle("Translate into \(settings.partnerLanguage.englishName)", isOn: $translateCaptions)
                    .accessToggle("caption-translation", label: "Translate captions", isOn: $translateCaptions)
                if translateCaptions, !translated.isEmpty {
                    Text(translated).font(.title2).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).card()
                }
                Button(running ? "Stop captions" : "Start captions", action: toggleCaptions).buttonStyle(.pill)
                    .accessTarget("captions", label: running ? "Stop captions" : "Start captions", action: toggleCaptions)
                Text(feedback).foregroundStyle(Theme.textSecondary)
            }.padding(Theme.gutter)
        }.background(Theme.background).navigationTitle("Live captions")
            .onDisappear(perform: stop)
            .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
            .onChange(of: translateCaptions) { _, enabled in
                translation?.cancel(); translated = ""
                if enabled { translateLatest() }
            }
    }
    private func toggleCaptions() { if running { stop() } else { start() } }
    private func stop() { running = false; capture?.cancel(); capture = nil; translation?.cancel(); recognizer.cancel() }
    private func start() {
        running = true
        feedback = ""
        capture = Task { @MainActor in
            guard await SpeechRecognizer.requestPermission() else { feedback = "Microphone access is off. Use Talk together with typed messages instead."; running = false; return }
            guard !Task.isCancelled else { return }
            while !Task.isCancelled {
                do {
                    let result = try await recognizer.listen(in: settings.myLanguage, contextualStrings: [])
                    if !Task.isCancelled { transcript = result.text; translateLatest() }
                } catch {
                    if !Task.isCancelled { feedback = "Captions stopped. Try again or use typed messages." }
                    break
                }
            }
            if !Task.isCancelled { running = false }
        }
    }

    private func translateLatest() {
        translation?.cancel()
        translated = ""
        guard translateCaptions, !transcript.isEmpty else { return }
        let original = transcript
        let source = settings.myLanguage
        let target = settings.partnerLanguage
        translation = Task { @MainActor in
            do {
                let result = try await translator.translate(original, from: source, to: target)
                guard !Task.isCancelled, transcript == original else { return }
                translated = result
            } catch {
                if !Task.isCancelled { feedback = "Caption translation did not finish. The original words are still here." }
            }
        }
    }
}

struct PhoneHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A little help beside your task").font(.title2.weight(.semibold))
                Text("The black circle opens Bridge tools while you use Bridge.")
                Text("iPhone does not let an ordinary app float over every other app. Share or copy text into Read with me, and use the iPhone accessibility controls for phone navigation.")
                Text("For system voice control, open Settings, Accessibility, Voice Control. You choose when to enable it.")
                Text("Bridge does not capture protected audio from other calling apps.")
            }.card().padding(Theme.gutter)
        }.background(Theme.background).navigationTitle("Floating assistant")
    }
}

struct BridgeBottomBar: View {
    @ObservedObject var router: Router
    @Environment(\.dynamicTypeSize) private var typeSize
    private var selected: Route? { router.path.last }
    var body: some View {
        HStack(spacing: 10) {
            if typeSize >= .xLarge {
                navigationMenu
            } else {
                HStack(spacing: 2) {
                    tab("Home", "house", nil)
                    tab("Speak", "mic", .speak)
                    tab("Translate", "character.bubble", .translate)
                    tab("Assist", "person", .assist)
                }
                .padding(6)
                .glassSurface(Capsule(), fallback: Theme.card)
            }
            FloatingAssistantButton(router: router)
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var navigationMenu: some View {
        Menu {
            Button("Home", systemImage: "house") { router.path = [] }
            Button("Speak", systemImage: "mic") { router.open(.speak) }
            Button("Translate", systemImage: "character.bubble") { router.open(.translate) }
            Button("Assist", systemImage: "person") { router.open(.assist) }
        } label: {
            Label("Navigate", systemImage: "square.grid.2x2")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.Space.md)
                .frame(maxWidth: .infinity, minHeight: 58)
                .glassSurface(Capsule(), fallback: Theme.card)
        }
        .accessibilityLabel("Navigate")
        .accessChoices("tab-navigation", label: "Navigate", order: 90) {
            [
                AccessChoice(id: "Home", title: "Home", isSelected: selected == nil) { router.path = [] },
                AccessChoice(id: "Speak", title: "Speak", isSelected: selected == .speak) { router.open(.speak) },
                AccessChoice(id: "Translate", title: "Translate", isSelected: selected == .translate) { router.open(.translate) },
                AccessChoice(id: "Assist", title: "Assist", isSelected: selected == .assist) { router.open(.assist) }
            ]
        }
    }

    private func tab(_ title: String, _ symbol: String, _ route: Route?) -> some View {
        Button { if let route { router.open(route) } else { router.path = [] } } label: {
            VStack(spacing: 4) { Image(systemName: symbol).font(.title3); Text(title).font(.caption2.weight(.medium)) }
                .padding(.horizontal, 10)
                .frame(minHeight: 58)
                .foregroundStyle(selected == route ? Theme.onAccent : Theme.textPrimary)
                .background(selected == route ? Theme.accent : .clear, in: Capsule())
                .frame(maxWidth: .infinity)
        }.buttonStyle(.plain).accessibilityAddTraits(selected == route ? .isSelected : [])
            .accessibilityShowsLargeContentViewer { Label(title, systemImage: symbol) }
            .accessTarget("tab-\(title)", label: title, order: 90) { if let route { router.open(route) } else { router.path = [] } }
    }
}

struct FloatingAssistantButton: View {
    @ObservedObject var router: Router
    var body: some View {
        Menu {
            Button("Use my voice", systemImage: "mic.fill") { router.open(.voice) }
            Button("Speak for me", systemImage: "mic") { router.open(.speak) }
            Button("Translate", systemImage: "character.bubble") { router.open(.translate) }
            Button("Talk together", systemImage: "person.2") { router.open(.talk) }
            Button("Read with me", systemImage: "doc.text") { router.open(.read) }
            Button("Quick phrases", systemImage: "text.bubble") { router.open(.phrases) }
            Button("A little guidance", systemImage: "checklist") { router.open(.guide) }
        } label: {
            Image(systemName: "waveform").font(.title2).foregroundStyle(Theme.onAccent)
                .frame(width: 70, height: 70).glassSurface(Circle(), tint: Theme.accent, fallback: Theme.accent)
        }.accessibilityLabel("Open assistant")
            .accessChoices("assistant", label: "Open assistant", order: 95) {
                [("Use my voice", Route.voice), ("Speak for me", .speak), ("Translate", .translate), ("Talk together", .talk),
                 ("Read with me", .read), ("Quick phrases", .phrases), ("A little guidance", .guide)]
                    .map { title, route in AccessChoice(id: title, title: title) { router.open(route) } }
            }
    }
}
