import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

@MainActor
final class TalkModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case listening
        case translating
        case review
        case speaking
        case failed(Failure)
    }

    enum Failure: Equatable {
        case noSpeech
        case permissionDenied
        case onDeviceUnavailable(Language)
        case recognizerUnavailable(Language)
        case audio

        var message: String {
            switch self {
            case .noSpeech:
                "I didn't catch that. Try again, or type it?"
            case .permissionDenied:
                "Bridge can't use the microphone. Turn it on in Settings, or type instead."
            case .onDeviceUnavailable(let language):
                "This iPhone can't recognize \(language.englishName) yet. You can type instead."
            case .recognizerUnavailable(let language):
                "\(language.englishName) recognition isn't ready. Try again, or type it."
            case .audio:
                "The microphone isn't available right now. Try again, or type it."
            }
        }
    }

    @Published var mode: TalkMode = .speak {
        didSet { if oldValue != mode { modeChanged() } }
    }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var current: Message?
    @Published var activeSide: Side = .me
    @Published var needsPermissionPrimer: Bool

    let recognizer: SpeechRecognizer
    let speaker: Speaker
    let translator: Translator
    let words: WordStore
    let history: HistoryStore
    let settings: AppSettings
    let metrics: Metrics

    private var listenTask: Task<Void, Never>?

    init(recognizer: SpeechRecognizer, speaker: Speaker, translator: Translator,
         words: WordStore, history: HistoryStore, settings: AppSettings, metrics: Metrics) {
        self.recognizer = recognizer
        self.speaker = speaker
        self.translator = translator
        self.words = words
        self.history = history
        self.settings = settings
        self.metrics = metrics
        self.needsPermissionPrimer = SpeechRecognizer.permission == .undetermined
    }

    var sourceLanguage: Language {
        if mode == .conversation, activeSide == .partner { return settings.partnerLanguage }
        return settings.myLanguage
    }

    var targetLanguage: Language? {
        switch mode {
        case .speak: nil
        case .translate: settings.partnerLanguage
        case .conversation: activeSide == .me ? settings.partnerLanguage : settings.myLanguage
        }
    }

    func name(for side: Side) -> String {
        side == .me ? "Me" : settings.partnerDisplayName
    }

    var isLive: Bool { phase == .listening || phase == .speaking }

    func talkTapped() {
        switch phase {
        case .listening: recognizer.finish()
        case .speaking: speaker.stop()
        default: startListening()
        }
    }

    func startListening() {
        guard phase != .listening else { return }
        listenTask?.cancel()
        listenTask = Task { await listen() }
    }

    func cancelListening() {
        recognizer.cancel()
        listenTask?.cancel()
        phase = .idle
    }

    func allowMicrophone() async {
        let granted = await SpeechRecognizer.requestPermission()
        needsPermissionPrimer = false
        if granted {
            startListening()
        } else {
            phase = .failed(.permissionDenied)
        }
    }

    func sayItAloud() async {
        guard var message = current, !message.spokenText.isEmpty else { return }
        phase = .speaking
        let started = Date()
        let finished = await speaker.speak(message.spokenText, in: message.spokenLanguage, rate: settings.speechRate) { [weak self] in
            self?.metrics.recordSpeechStart(ms: Int(Date().timeIntervalSince(started) * 1000))
        }
        guard current?.id == message.id else { return }
        guard finished else { phase = .review; return }
        message.wasSpoken = true
        current = message
        phase = .idle
        if mode == .conversation { activeSide = message.side.other }
    }

    var willSpeakIn: Language? { current?.spokenLanguage }

    func retryTranslation() async {
        guard let message = current, message.translationFailed else { return }
        await translateCurrent()
        guard current?.id == message.id else { return }
        phase = .review
    }

    func stopSpeaking() { speaker.stop() }

    func applyFix(text: String, remember: [Replacement], wordsChanged: Int) async {
        guard var message = current else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != message.text else { return }
        for pair in remember {
            words.remember(saved: pair.saved, heard: pair.heard, language: message.sourceLanguage)
        }
        metrics.recordFix(wordsChanged: max(wordsChanged, 1))
        message.text = trimmed
        message.uncertainWords = []
        message.wasSpoken = false
        current = message
        await translateCurrent()
        guard current?.id == message.id else { return }
        phase = .review
    }

    func useTyped(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tearOff()
        let message = Message(mode: mode, side: activeSide, sourceLanguage: sourceLanguage, text: trimmed,
                              targetLanguage: targetLanguage, wasTyped: true)
        current = message
        await translateCurrent()
        guard current?.id == message.id else { return }
        phase = .review
        await autoSpeakTurnIfReady()
    }

    func speakNow(_ text: String, in language: Language) async {
        tearOff()
        mode = .speak
        current = Message(mode: .speak, sourceLanguage: language, text: text, wasTyped: true)
        await sayItAloud()
    }

    func talk(as side: Side) {
        if phase == .listening || phase == .speaking {
            talkTapped()
            return
        }
        activeSide = side
        startListening()
    }

    func newLeaf() {
        tearOff()
        phase = .idle
    }

    private func listen() async {
        if SpeechRecognizer.permission == .undetermined {
            let granted = await SpeechRecognizer.requestPermission()
            needsPermissionPrimer = false
            guard granted else { phase = .failed(.permissionDenied); return }
        }
        tearOff()
        phase = .listening
        Haptics.listeningChanged()
        let language = sourceLanguage
        let target = targetLanguage
        let side = activeSide
        let started = Date()
        do {
            let transcript = try await recognizer.listen(
                in: language,
                contextualStrings: words.contextualStrings(for: language)
            )
            Haptics.listeningChanged()
            let elapsed = Int(Date().timeIntervalSince(started) * 1000)
            metrics.recordUtterance(language, recognitionMs: elapsed)
            let (text, replacements) = words.applySavedSpellings(to: transcript.text, language: language)
            words.recordUses(in: text)
            let message = Message(mode: mode, side: side, sourceLanguage: language, text: text,
                                  uncertainWords: transcript.uncertainWords, replacements: replacements,
                                  targetLanguage: target)
            current = message
            await translateCurrent()
            guard current?.id == message.id else { return }
            phase = .review
            await autoSpeakTurnIfReady()
        } catch is CancellationError {
            if phase == .listening { phase = .idle }
        } catch let failure as RecognitionFailure {
            Haptics.listeningChanged()
            phase = .failed(Self.map(failure))
        } catch {
            phase = .failed(.audio)
        }
    }

    private func translateCurrent() async {
        guard var message = current, let target = message.targetLanguage, target != message.sourceLanguage else { return }
        phase = .translating
        message.translation = nil
        message.translationFailed = false
        current = message
        let started = Date()
        do {
            let translated = try await translator.translate(message.text, from: message.sourceLanguage, to: target)
            metrics.recordTranslation(ms: Int(Date().timeIntervalSince(started) * 1000))
            message.translation = translated
        } catch {
            message.translationFailed = true
        }
        if current?.id == message.id { current = message }
    }

    private func autoSpeakTurnIfReady() async {
        guard mode == .conversation, settings.autoSpeakTurns, current?.translation != nil else { return }
        await sayItAloud()
    }

    private func tearOff() {
        guard let message = current else { return }
        if settings.keepHistory { history.append(message) }
        current = nil
    }

    private func modeChanged() {
        if phase == .listening { cancelListening() }
        if phase == .speaking { speaker.stop() }
        tearOff()
        activeSide = .me
        phase = .idle
    }

    private static func map(_ failure: RecognitionFailure) -> Failure {
        switch failure {
        case .notAuthorized: .permissionDenied
        case .onDeviceUnavailable(let language): .onDeviceUnavailable(language)
        case .recognizerUnavailable(let language): .recognizerUnavailable(language)
        case .noSpeech: .noSpeech
        case .audio: .audio
        }
    }

    #if DEBUG
    func stage(phase: Phase, current: Message?, mode: TalkMode = .speak, side: Side = .me) {
        self.mode = mode
        self.phase = phase
        self.current = current
        self.activeSide = side
        self.needsPermissionPrimer = false
    }
    #endif
}
