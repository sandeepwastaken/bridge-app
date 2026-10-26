import Foundation
@testable import Bridge

func isolatedDefaults() -> UserDefaults {
    let name = "bridge-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@MainActor
func makeTalkModel(keepHistory: Bool = true, translator: Translator? = nil) -> TalkModel {
    let defaults = isolatedDefaults()
    let settings = AppSettings(defaults: defaults)
    settings.keepHistory = keepHistory
    return TalkModel(
        recognizer: SpeechRecognizer(),
        speaker: Speaker(),
        translator: translator ?? Translator(),
        words: WordStore(fileName: nil),
        history: HistoryStore(fileName: nil),
        settings: settings,
        metrics: Metrics(defaults: defaults)
    )
}
