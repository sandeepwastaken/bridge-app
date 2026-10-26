import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let router: Router
    let talk: TalkModel

    @AppStorage("bridge.profileName") private var profileName = ""
    @State private var confirmHistory = false
    @State private var confirmWords = false
    @State private var translationStatus: Translator.Status?
    @State private var recognitionReady: [Language: Bool] = [:]
    @FocusState private var focusedField: Field?
    @State private var personalVoiceNote: String?

    private enum Field { case name, partnerName }

    var body: some View {
        List {
            Section("Your name") {
                TextField("What should I call you?", text: $profileName,
                          prompt: Text("What should I call you?").foregroundStyle(Theme.textSecondary))
                    .textContentType(.givenName)
                    .focused($focusedField, equals: .name)
                    .frame(minHeight: 44)
                    .accessTarget("name", label: "Your name") { focusedField = .name }
            }
            Section {
                link(.controlSettings, id: "control", label: "How you control Bridge") {
                    row("How you control Bridge", settings.control.title, symbol: settings.control.symbol, color: Theme.badge)
                }
                Picker(selection: $settings.textSize) {
                    ForEach(TextSizeBoost.allCases) { Text($0.title).tag($0) }
                } label: {
                    row("Text size", nil, symbol: "textformat.size", color: Theme.badge)
                }
                .accessPicker("text-size", label: "Text size", selection: $settings.textSize,
                              options: TextSizeBoost.allCases, title: \.title)
                link(.builtInAccess, id: "built-in", label: "iPhone's own accessibility") {
                    row("iPhone's own accessibility", "Eye Tracking, Voice Control and more", symbol: "accessibility", color: Theme.badge)
                }
            } header: {
                Text("Using Bridge")
            }

            Section {
                Picker(selection: $settings.myLanguage) {
                    ForEach(settings.supportedLanguages) { Text($0.nativeName).tag($0) }
                } label: { row("I speak", nil, symbol: "person.fill", color: Theme.badge) }
                    .accessPicker("my-language", label: "I speak", selection: $settings.myLanguage,
                                  options: settings.supportedLanguages, title: \.nativeName)
                Picker(selection: $settings.partnerLanguage) {
                    ForEach(settings.supportedLanguages) { Text($0.nativeName).tag($0) }
                } label: { row("They speak", nil, symbol: "person.2.fill", color: Theme.badge) }
                    .accessPicker("partner-language", label: "They speak", selection: $settings.partnerLanguage,
                                  options: settings.supportedLanguages, title: \.nativeName)
                HStack(spacing: Theme.Space.md) {
                    IconBadge(symbol: "textformat", color: Theme.badge, size: 30)
                    TextField("Their name (optional)", text: $settings.partnerName,
                              prompt: Text("Their name (optional)").foregroundStyle(Theme.textSecondary))
                        .focused($focusedField, equals: .partnerName)
                }
                .frame(minHeight: 44)
                .accessTarget("partner-name", label: "Their name") { focusedField = .partnerName }
            } header: {
                Text("Languages")
            }

            Section {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("Speaking speed")
                    AccessSlider(id: "speech-rate", label: "Speaking speed", value: $settings.speechRate,
                                 range: Speaker.rateRange,
                                 step: (Speaker.rateRange.upperBound - Speaker.rateRange.lowerBound) / 10,
                                 continuous: true, lowSymbol: "tortoise.fill", highSymbol: "hare.fill",
                                 lowName: "Slower", highName: "Faster")
                }
                .padding(.vertical, 6)
                Button {
                    hearSample()
                } label: {
                    Label("Hear a sample", systemImage: "speaker.wave.2.fill")
                }
                .frame(minHeight: 44)
                .accessTarget("sample", label: "Hear a sample") { hearSample() }
                Toggle("Say translations right away in Talk together", isOn: $settings.autoSpeakTurns)
                    .frame(minHeight: 44)
                    .accessToggle("auto-speak", label: "Say translations right away", isOn: $settings.autoSpeakTurns)
                Toggle("Speak with my Personal Voice", isOn: personalVoice)
                    .frame(minHeight: 44)
                    .accessToggle("personal-voice", label: "Speak with my Personal Voice", isOn: personalVoice)
                if let personalVoiceNote {
                    Text(personalVoiceNote).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                Toggle("Haptics", isOn: $settings.haptics)
                    .frame(minHeight: 44)
                    .accessToggle("haptics", label: "Haptics", isOn: $settings.haptics)
            } header: {
                Text("Voice and feedback")
            }

            Section {
                statusRow("Recognition: \(settings.myLanguage.englishName)", recognitionReady[settings.myLanguage])
                statusRow("Recognition: \(settings.partnerLanguage.englishName)", recognitionReady[settings.partnerLanguage])
                HStack {
                    Text("Translation")
                    Spacer()
                    Text(translationLabel).foregroundStyle(Theme.textSecondary)
                }
                .frame(minHeight: 44)
                if translationStatus == .needsDownload {
                    Button("Download \(settings.myLanguage.englishName) ↔ \(settings.partnerLanguage.englishName)") {
                        downloadTranslation()
                    }
                    .frame(minHeight: 44)
                    .accessTarget("download", label: "Download translation") { downloadTranslation() }
                }
            } header: {
                Text("On this iPhone")
            } footer: {
                Text("To add a language, go to Settings ▸ General ▸ Keyboard ▸ Dictation Languages. For better voices, go to Settings ▸ Accessibility ▸ Spoken Content ▸ Voices.")
            }

            Section {
                Toggle("Keep earlier words on this device", isOn: $settings.keepHistory)
                    .frame(minHeight: 44)
                    .accessToggle("keep-history", label: "Keep earlier words", isOn: $settings.keepHistory)
                Button("Delete earlier words", role: .destructive) { confirmHistory = true }
                    .frame(minHeight: 44)
                    .accessChoices("delete-history", label: "Delete all earlier words?") {
                        [AccessChoice(id: "delete", title: "Delete earlier words", role: .destructive) { talk.history.deleteAll() }]
                    }
                Button("Delete My Words", role: .destructive) { confirmWords = true }
                    .frame(minHeight: 44)
                    .accessChoices("delete-words", label: "Delete everything in My Words?") {
                        [AccessChoice(id: "delete", title: "Delete My Words", role: .destructive) { talk.words.deleteAll() }]
                    }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Bridge uses on-device recognition. History is off for new installations. Turning it off stops future saving; delete earlier words to remove existing history. Apple may receive technical service metrics.")
            }

            Section {
                link(.importantInformation, id: "important-information", label: "Privacy & important information") {
                    Text("Privacy & important information")
                }
                link(.mission, id: "mission", label: "Why we built Bridge") {
                    Text("Why we built Bridge")
                }
                #if DEBUG
                link(.sessionNumbers, id: "session-numbers", label: "Session numbers") {
                    Text("Session numbers")
                }
                #endif
                Button("Show the welcome again") { settings.onboarded = false }
                    .frame(minHeight: 44)
                    .accessTarget("welcome-again", label: "Show the welcome again") { settings.onboarded = false }
            } header: {
                Text("About")
            }
        }
        .accessScrolling()
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
        .confirmationDialog("Delete all earlier words?", isPresented: $confirmHistory, titleVisibility: .visible) {
            Button("Delete earlier words", role: .destructive) { talk.history.deleteAll() }
        } message: { Text("This can't be undone.") }
        .confirmationDialog("Delete everything in My Words?", isPresented: $confirmWords, titleVisibility: .visible) {
            Button("Delete My Words", role: .destructive) { talk.words.deleteAll() }
        } message: { Text("Names, places, phrases and saved spellings will be removed. This can't be undone.") }
        .task(id: "\(settings.myLanguage.rawValue)-\(settings.partnerLanguage.rawValue)") { await refreshStatus() }
        .onChange(of: settings.haptics) { _, on in Haptics.enabled = on }
    }

    private func link<Label: View>(_ route: Route, id: String, label: String,
                                   @ViewBuilder content: () -> Label) -> some View {
        NavigationLink(value: route) { content() }
            .frame(minHeight: 44)
            .accessTarget(id, label: label) { router.path.append(route) }
    }

    private func row(_ title: String, _ detail: String?, symbol: String, color: Color) -> some View {
        HStack(spacing: Theme.Space.md) {
            IconBadge(symbol: symbol, color: color, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(minHeight: 44)
    }

    private var translationLabel: String {
        switch translationStatus {
        case .installed: "Ready"
        case .needsDownload: "Needs download"
        case .unsupported: "Not available"
        case nil: "Checking…"
        }
    }

    private func statusRow(_ title: String, _ ready: Bool?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(ready.map { $0 ? "Ready" : "Not on this iPhone" } ?? "Checking…")
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(minHeight: 44)
    }

    private var personalVoice: Binding<Bool> {
        Binding(get: { settings.usePersonalVoice }, set: { on in
            guard on else {
                settings.usePersonalVoice = false
                Speaker.prefersPersonalVoice = false
                personalVoiceNote = nil
                return
            }
            Task {
                let status = await Speaker.requestPersonalVoice()
                let ready = status == .authorized && Speaker.personalVoice(for: settings.myLanguage) != nil
                settings.usePersonalVoice = ready
                Speaker.prefersPersonalVoice = ready
                personalVoiceNote = ready ? nil : (status == .authorized
                    ? "No Personal Voice for \(settings.myLanguage.englishName) yet. Make one in Settings ▸ Accessibility ▸ Personal Voice."
                    : "Bridge needs permission to use your Personal Voice. You can allow it in Settings ▸ Accessibility ▸ Personal Voice.")
            }
        })
    }

    private func hearSample() {
        Task { await talk.speaker.speak(settings.myLanguage.nativeName, in: settings.myLanguage, rate: settings.speechRate) }
    }

    private func downloadTranslation() {
        talk.translator.prepare(from: settings.myLanguage, to: settings.partnerLanguage)
    }

    private func refreshStatus() async {
        for language in [settings.myLanguage, settings.partnerLanguage] {
            recognitionReady[language] = SpeechRecognizer.supportsOnDevice(language)
        }
        translationStatus = await Translator.status(from: settings.myLanguage, to: settings.partnerLanguage)
    }
}

struct ControlSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var access: AccessController

    var body: some View {
        List {
            Section {
                ForEach(ControlMethod.allCases) { method in
                    let available = method != .head || HeadTracker.isSupported
                    Button {
                        choose(method)
                    } label: {
                        HStack(alignment: .top, spacing: Theme.Space.md) {
                            IconBadge(symbol: method.symbol, color: Theme.badge, size: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(method.title).font(.headline).foregroundStyle(Theme.textPrimary)
                                Text(available ? method.summary : "Needs an iPhone with Face ID.")
                                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if settings.control == method {
                                Image(systemName: "checkmark").font(.headline).foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessTarget("method-\(method.rawValue)", label: method.title) { choose(method) }
                    .disabled(!available)
                    .opacity(available ? 1 : 0.5)
                    .accessibilityAddTraits(settings.control == method ? .isSelected : [])
                }
            } header: {
                Text("Choose with")
            }

            if settings.control == .scanning {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text("Light each button for \(settings.scanInterval, specifier: "%.1f") seconds")
                        AccessSlider(id: "scan-interval", label: "Highlight time", value: $settings.scanInterval,
                                     range: 0.8...4, step: 0.2)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Scanning")
                } footer: {
                    Text("Tap anywhere to choose the lit button. A Bluetooth switch works too: Space or Return chooses, Tab moves on. To use touch again, hold anywhere for 3 seconds.")
                }
            }

            if settings.control == .head {
                Section {
                    Picker("Choose by", selection: $settings.headSelect) {
                        ForEach(HeadSelect.allCases) { Text($0.title).tag($0) }
                    }
                    .frame(minHeight: 44)
                    .accessPicker("head-select", label: "Choose by", selection: $settings.headSelect,
                                  options: HeadSelect.allCases, title: \.title)
                    if settings.headSelect == .dwell {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("Hold still for \(settings.dwellTime, specifier: "%.1f") seconds")
                            AccessSlider(id: "dwell-time", label: "Hold time", value: $settings.dwellTime,
                                         range: 0.6...3, step: 0.1)
                        }
                        .padding(.vertical, 6)
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text("Pointer speed")
                        AccessSlider(id: "pointer-speed", label: "Pointer speed", value: $settings.pointerSpeed,
                                     range: 0.5...2, step: 0.1)
                    }
                    .padding(.vertical, 6)
                    Button("Re-center the pointer") { access.recenter() }
                        .frame(minHeight: 44)
                        .accessTarget("recenter", label: "Re-center the pointer") { access.recenter() }
                } header: {
                    Text("Head pointer")
                } footer: {
                    Text("Hold the phone at arm's length, level with your face. If the pointer drifts, look straight at the screen and choose Re-center. Push the pointer against the top or bottom edge to scroll.")
                }
            }
        }
        .accessScrolling()
        .navigationTitle("Control")
    }

    private func choose(_ method: ControlMethod) {
        settings.control = method
        access.restart()
    }
}

struct BuiltInAccessView: View {
    private let items: [(String, String, String)] = [
        ("eye", "Eye Tracking", "Control iPhone with just your eyes, using the front camera. Look at a button and hold your gaze to tap it. Settings ▸ Accessibility ▸ Eye Tracking."),
        ("mic.badge.plus", "Voice Control", "Say \"Tap Talk\" or \"Tap Speak my words\". Every Bridge button has a spoken name. Settings ▸ Accessibility ▸ Voice Control."),
        ("square.grid.3x3.topleft.filled", "Switch Control", "Use adaptive switches, or head movements via the camera, across all of iPhone. Settings ▸ Accessibility ▸ Switch Control."),
        ("circle.circle", "AssistiveTouch", "An on-screen menu for people who find buttons or gestures hard. Settings ▸ Accessibility ▸ Touch ▸ AssistiveTouch."),
        ("hand.point.up.left", "Touch Accommodations", "Ignore accidental or repeated touches, or make iPhone wait until you're holding steady. Settings ▸ Accessibility ▸ Touch."),
        ("waveform.badge.mic", "Vocal Shortcuts", "Teach iPhone a sound or phrase of your own, even if speech is hard, to open Bridge's Speak for me. Settings ▸ Accessibility ▸ Vocal Shortcuts."),
        ("person.wave.2", "Personal Voice", "If you're at risk of losing your voice, iPhone can create a voice that sounds like you. Settings ▸ Accessibility ▸ Personal Voice."),
        ("captions.bubble", "Live Captions", "Captions for any audio on iPhone, including calls. Settings ▸ Accessibility ▸ Live Captions."),
    ]

    var body: some View {
        List {
            Section {
                ForEach(items, id: \.1) { symbol, title, detail in
                    HStack(alignment: .top, spacing: Theme.Space.md) {
                        IconBadge(symbol: symbol, color: Theme.badge, size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(.headline)
                            Text(detail).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
            } footer: {
                Text("You can also say \"Hey Siri, speak with Bridge\".")
            }
        }
        .navigationTitle("iPhone accessibility")
    }
}

struct MissionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("A disability, an unfamiliar accent, a language barrier, or difficulty navigating technology should never prevent someone from expressing themselves, understanding another person, or participating independently in everyday life.")
                    .font(.title3)
                Text("We started Bridge because of our grandparents. We don't want to build an app that speaks for people. We want to build an app that helps people speak for themselves.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(Theme.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .navigationTitle("Why we built Bridge")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct MetricsView: View {
    @ObservedObject var metrics: Metrics
    @State private var confirmReset = false

    var body: some View {
        let n = metrics.numbers
        List {
            Section {
                ForEach(Language.allCases) { language in
                    row("Said in \(language.englishName)", "\(n.utterances[language.rawValue, default: 0])")
                }
                row("Fixed before saying", "\(n.fixedBeforeSpeaking)")
                row("Words changed", "\(n.wordsChanged)")
            } header: { Text("Counts") }
            Section {
                row("Words ready after speaking", ms(SessionNumbers.median(n.recognitionMs)))
                row("Translation", ms(SessionNumbers.median(n.translationMs)))
                row("Tap to first sound", ms(SessionNumbers.median(n.speechStartMs)))
            } header: { Text("Typical wait (median)") } footer: {
                Text("Only counts and times are kept, never your words. They stay on this iPhone.")
            }
            Section { Button("Reset numbers", role: .destructive) { confirmReset = true } }
        }
        .navigationTitle("Session numbers")
        .confirmationDialog("Reset session numbers?", isPresented: $confirmReset) {
            Button("Reset numbers", role: .destructive) { metrics.reset() }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(Theme.textSecondary)
        }
        .frame(minHeight: 44)
    }

    private func ms(_ value: Int?) -> String {
        guard let value else { return "None yet" }
        return value >= 1000 ? String(format: "%.1f s", Double(value) / 1000) : "\(value) ms"
    }
}
