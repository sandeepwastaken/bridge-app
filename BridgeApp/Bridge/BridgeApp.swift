import AppIntents
import SwiftUI

@main
struct BridgeApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView(env: env)
        }
    }
}

struct OpenSpeakIntent: AppIntent {
    static let title: LocalizedStringResource = "Speak for me"
    static let description = IntentDescription("Opens Bridge ready to make your words clear.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.open(.speak)
        return .result()
    }
}

struct OpenTranslateIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate"
    static let description = IntentDescription("Opens Bridge ready to translate between your selected languages.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.open(.translate)
        return .result()
    }
}

struct OpenPhrasesIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick phrases"
    static let description = IntentDescription("Opens Bridge's quick phrases.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.open(.phrases)
        return .result()
    }
}

struct BridgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenSpeakIntent(),
                    phrases: ["Speak with \(.applicationName)", "\(.applicationName) speak for me"],
                    shortTitle: "Speak for me", systemImageName: "waveform")
        AppShortcut(intent: OpenTranslateIntent(),
                    phrases: ["Translate with \(.applicationName)"],
                    shortTitle: "Translate", systemImageName: "character.bubble")
        AppShortcut(intent: OpenPhrasesIntent(),
                    phrases: ["Open \(.applicationName) phrases"],
                    shortTitle: "Quick phrases", systemImageName: "text.bubble")
    }
}
