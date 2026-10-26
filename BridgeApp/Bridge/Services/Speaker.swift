import AVFoundation
import Foundation

@MainActor
final class Speaker: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published private(set) var spokenRange: NSRange?

    static let defaultRate: Float = 0.45
    static let rateRange: ClosedRange<Float> = 0.3...0.6
    static var prefersPersonalVoice = false

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Bool, Never>?
    private var currentUtterance: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    @discardableResult
    func speak(_ text: String, in language: Language, rate: Float, onStart: (@MainActor () -> Void)? = nil) async -> Bool {
        stop()
        AudioSession.activateForSpeaking()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: language)
        utterance.rate = min(max(rate, Self.rateRange.lowerBound), Self.rateRange.upperBound)
        utterance.preUtteranceDelay = 0.05
        isSpeaking = true
        startHandler = onStart
        currentUtterance = ObjectIdentifier(utterance)
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        finishUtterance()
    }

    static func bestVoice(for language: Language) -> AVSpeechSynthesisVoice? {
        if prefersPersonalVoice, let personal = personalVoice(for: language) { return personal }
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == language.rawValue && !$0.voiceTraits.contains(.isPersonalVoice)
        }
        return voices.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language.rawValue)
    }

    static func personalVoice(for language: Language) -> AVSpeechSynthesisVoice? {
        guard AVSpeechSynthesizer.personalVoiceAuthorizationStatus == .authorized else { return nil }
        return AVSpeechSynthesisVoice.speechVoices().first {
            $0.voiceTraits.contains(.isPersonalVoice) && $0.language.hasPrefix(language.baseCode)
        }
    }

    static func requestPersonalVoice() async -> AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { continuation.resume(returning: $0) }
        }
    }

    static func hasVoice(for language: Language) -> Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { $0.language.hasPrefix(language.rawValue.prefix(2)) }
    }

    private var startHandler: (@MainActor () -> Void)?

    private func finishUtterance(_ utterance: ObjectIdentifier? = nil, completed: Bool = false) {
        if let utterance, utterance != currentUtterance { return }
        currentUtterance = nil
        isSpeaking = false
        spokenRange = nil
        startHandler = nil
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: completed)
        }
    }
}

extension Speaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard id == self.currentUtterance else { return }
            self.startHandler?()
            self.startHandler = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            if id == self.currentUtterance { self.spokenRange = characterRange }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finishUtterance(id, completed: true) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finishUtterance(id) }
    }
}
