import AVFoundation
import Foundation
import Speech

struct Transcript: Sendable {
    var text: String
    var uncertainWords: [String]
}

enum RecognitionFailure: Error, Equatable {
    case notAuthorized
    case onDeviceUnavailable(Language)
    case recognizerUnavailable(Language)
    case noSpeech
    case audio
}

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var partial = ""
    @Published private(set) var level: Float = 0
    @Published private(set) var isListening = false

    nonisolated static let uncertaintyThreshold: Float = 0.5
    static let silenceTimeout: Duration = .seconds(2)
    static let noSpeechTimeout: Duration = .seconds(8)
    static let maxDuration: Duration = .seconds(60)

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<Transcript, Error>?
    private var silenceTimer: Task<Void, Never>?
    private var limitTimer: Task<Void, Never>?
    private var finalizeTimer: Task<Void, Never>?

    enum Permission { case undetermined, granted, denied }

    static var permission: Permission {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission
        if speech == .denied || speech == .restricted || mic == .denied { return .denied }
        if speech == .authorized && mic == .granted { return .granted }
        return .undetermined
    }

    static func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    static func supportsOnDevice(_ language: Language) -> Bool {
        SFSpeechRecognizer(locale: language.locale)?.supportsOnDeviceRecognition ?? false
    }

    func listen(in language: Language, contextualStrings: [String]) async throws -> Transcript {
        guard Self.permission == .granted else { throw RecognitionFailure.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(locale: language.locale), recognizer.isAvailable else {
            throw RecognitionFailure.recognizerUnavailable(language)
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw RecognitionFailure.onDeviceUnavailable(language)
        }

        cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        request.contextualStrings = Array(contextualStrings.prefix(100))
        self.request = request

        do {
            try AudioSession.activateForListening()
            let input = engine.inputNode
            var format = input.outputFormat(forBus: 0)
            for _ in 0..<5 where format.sampleRate == 0 || format.channelCount == 0 {
                try? await Task.sleep(for: .milliseconds(120))
                format = input.outputFormat(forBus: 0)
            }
            guard format.sampleRate > 0, format.channelCount > 0 else { throw RecognitionFailure.audio }
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                let level = Self.rms(buffer)
                Task { @MainActor [weak self] in self?.level = level }
            }
            engine.prepare()
            try engine.start()
        } catch {
            teardownAudio()
            throw RecognitionFailure.audio
        }

        partial = ""
        isListening = true
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.noSpeechTimeout)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
        limitTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.maxDuration)
            guard !Task.isCancelled else { return }
            self?.finish()
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result.map(Self.transcript(from:))
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor [weak self] in
                    self?.handle(transcript: transcript, isFinal: isFinal, failed: failed)
                }
            }
        }
    }

    func finish() {
        guard isListening else { return }
        teardownAudio()
        request?.endAudio()
        finalizeTimer = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled, let self else { return }
            self.resolve(with: self.partial.isEmpty ? nil : Transcript(text: self.partial, uncertainWords: []))
        }
    }

    func cancel() {
        task?.cancel()
        teardownAudio()
        if let continuation {
            self.continuation = nil
            continuation.resume(throwing: CancellationError())
        }
        clearTimers()
        task = nil
        request = nil
        partial = ""
    }

    #if DEBUG
    func stage(partial: String, level: Float) {
        self.partial = partial
        self.level = level
        self.isListening = true
    }
    #endif

    private func handle(transcript: Transcript?, isFinal: Bool, failed: Bool) {
        guard continuation != nil else { return }
        if let transcript, !transcript.text.isEmpty {
            partial = transcript.text
            restartSilenceTimer()
            if isFinal {
                resolve(with: transcript)
                return
            }
        }
        if failed || isFinal {
            resolve(with: partial.isEmpty ? nil : Transcript(text: partial, uncertainWords: transcript?.uncertainWords ?? []))
        }
    }

    private func resolve(with transcript: Transcript?) {
        guard let continuation else { return }
        self.continuation = nil
        teardownAudio()
        clearTimers()
        task?.finish()
        task = nil
        request = nil
        if let transcript {
            continuation.resume(returning: transcript)
        } else {
            continuation.resume(throwing: RecognitionFailure.noSpeech)
        }
    }

    private func restartSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.silenceTimeout)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func clearTimers() {
        silenceTimer?.cancel(); silenceTimer = nil
        limitTimer?.cancel(); limitTimer = nil
        finalizeTimer?.cancel(); finalizeTimer = nil
    }

    private func teardownAudio() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        isListening = false
        level = 0
    }

    nonisolated private static func transcript(from result: SFSpeechRecognitionResult) -> Transcript {
        let best = result.bestTranscription
        let uncertain = best.segments
            .filter { $0.confidence > 0 && $0.confidence < uncertaintyThreshold }
            .map { $0.substring.lowercased() }
        return Transcript(text: best.formattedString, uncertainWords: uncertain)
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(count))
        let db = 20 * log10(max(rms, 0.000_01))
        return max(0, min(1, (db + 50) / 50))
    }
}

enum AudioSession {
    static func activateForListening() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }

    static func activateForSpeaking() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }
}
