import SwiftUI
import Translation

@MainActor
final class AppEnvironment: ObservableObject {
    let settings: AppSettings
    let words: WordStore
    let history: HistoryStore
    let metrics: Metrics
    let translator: Translator
    let talk: TalkModel
    let access: AccessController

    init(settings: AppSettings? = nil, words: WordStore? = nil,
         history: HistoryStore? = nil, metrics: Metrics? = nil) {
        #if DEBUG
        let uiTesting = ProcessInfo.processInfo.arguments.contains("-uitesting")
        if uiTesting, let bundle = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundle)
        }
        #else
        let uiTesting = false
        #endif
        let settings = settings ?? AppSettings()
        let words = words ?? (uiTesting ? WordStore(fileName: nil) : WordStore())
        let history = history ?? (uiTesting ? HistoryStore(fileName: nil) : HistoryStore())
        let metrics = metrics ?? Metrics()
        self.settings = settings
        self.words = words
        self.history = history
        self.metrics = metrics
        #if DEBUG
        self.translator = uiTesting ? Self.uiTestTranslator() : Translator()
        #else
        self.translator = Translator()
        #endif
        self.talk = TalkModel(recognizer: SpeechRecognizer(), speaker: Speaker(), translator: translator,
                              words: words, history: history, settings: settings, metrics: metrics)
        self.access = AccessController(settings: settings)
        Haptics.enabled = settings.haptics
        Speaker.prefersPersonalVoice = settings.usePersonalVoice
    }

    #if DEBUG
    private static func uiTestTranslator() -> Translator {
        switch UserDefaults.standard.string(forKey: "stubTranslation") {
        case "ok": Translator(stub: { text, _, target in "[\(target.englishName)] \(text)" })
        case "fail": Translator(stub: { _, _, _ in throw TranslationFailure.failed })
        case "hang": Translator(timeout: .seconds(3))
        default: Translator()
        }
    }
    #endif
}

struct RootView: View {
    @ObservedObject var env: AppEnvironment
    @ObservedObject var settings: AppSettings
    @ObservedObject var translator: Translator
    @ObservedObject var router = Router.shared
    @State private var keyboardVisible = false

    init(env: AppEnvironment) {
        self.env = env
        self.settings = env.settings
        self.translator = env.translator
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $router.path) {
                HomeView(router: router, settings: settings, access: env.access)
                    .navigationDestination(for: Route.self) { route in
                        destination(route)
                    }
            }
            if !keyboardVisible {
                BridgeBottomBar(router: router)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.accent)
        .toggleStyle(BridgeToggleStyle())
        .overlay(alignment: .top) { handsFreeBack }
        .dynamicTypeSize(settings.textSize.range)
        .accessHost("root", controller: env.access)
        .task { await settings.refreshSupportedLanguages() }
        .translationTask(translator.configuration) { session in
            await translator.drain(session)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: Binding(get: { !settings.onboarded }, set: { _ in })) {
            WelcomeView(settings: settings, access: env.access) { settings.onboarded = true }
                .dynamicTypeSize(settings.textSize.range)
                .accessHost("welcome", controller: env.access)
        }
        #endif
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        #endif
        .onAppear { env.access.restart() }
        .onChange(of: settings.control) { _, _ in env.access.restart() }
        .onChange(of: router.path) { _, _ in env.access.restart() }
    }

    @ViewBuilder private var handsFreeBack: some View {
        if settings.control != .touch, !router.path.isEmpty {
            Button {
                router.path.removeLast()
            } label: {
                Label("Go back", systemImage: "chevron.backward")
                    .font(.headline)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.sm)
                    .frame(minHeight: 48)
                    .glassSurface(Capsule(), fallback: Theme.card)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.top, 2)
            .accessTarget("go-back", label: "Go back", order: 100) {
                if !router.path.isEmpty { router.path.removeLast() }
            }
        }
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .speak: SpeakView(mode: .speak, model: env.talk, access: env.access)
        case .translate: SpeakView(mode: .translate, model: env.talk, access: env.access)
        case .talk: ConversationView(model: env.talk, access: env.access)
        case .phrases: QuickPhrasesView(model: env.talk, access: env.access)
        case .read: ReadView(settings: settings, speaker: env.talk.speaker)
        case .words: MyWordsView(words: env.words, talk: env.talk, access: env.access)
        case .assist: AssistView(router: router, settings: settings, model: env.talk)
        case .voice: AssistView(router: router, settings: settings, model: env.talk, startWithVoice: true)
        case .guide: GuidanceView(settings: settings, speaker: env.talk.speaker)
        case .captions: MicrophoneCaptionsView(settings: settings, translator: translator)
        case .understand: ReadView(settings: settings, speaker: env.talk.speaker)
        case .overlay: PhoneHelpView()
        case .call(let number): CallSheet(number: number)
        case .settings: SettingsView(settings: settings, router: router, talk: env.talk)
        case .controlSettings: ControlSettingsView(settings: settings, access: env.access)
        case .builtInAccess: BuiltInAccessView()
        case .importantInformation: ImportantInformationView()
        case .mission: MissionView()
        case .sessionNumbers: MetricsView(metrics: env.metrics)
        }
    }
}
