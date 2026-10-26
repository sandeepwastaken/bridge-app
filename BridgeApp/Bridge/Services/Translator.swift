import Foundation
import SwiftUI
import Translation

enum TranslationFailure: Error, Equatable {
    case notDownloaded(Language)
    case unsupported
    case failed
    case timedOut
}

@MainActor
final class Translator: ObservableObject {
    @Published private(set) var configuration: TranslationSession.Configuration?

    private final class Request {
        let id = UUID()
        let text: String
        let source: Language
        let target: Language
        private var continuation: CheckedContinuation<String, Error>?

        init(text: String, source: Language, target: Language, continuation: CheckedContinuation<String, Error>) {
            self.text = text
            self.source = source
            self.target = target
            self.continuation = continuation
        }

        func finish(_ result: Result<String, Error>) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(with: result)
        }
    }

    var timeout: Duration
    private let stub: (@MainActor (String, Language, Language) async throws -> String)?

    private var pending: [Request] = []
    private var prepareOnly: (source: Language, target: Language)?

    init(timeout: Duration = .seconds(20),
         stub: (@MainActor (String, Language, Language) async throws -> String)? = nil) {
        self.timeout = timeout
        self.stub = stub
    }

    enum Status { case installed, needsDownload, unsupported }

    static func status(from source: Language, to target: Language) async -> Status {
        let availability = LanguageAvailability()
        let status = await availability.status(from: source.localeLanguage, to: target.localeLanguage)
        switch status {
        case .installed: return .installed
        case .supported: return .needsDownload
        default: return .unsupported
        }
    }

    func translate(_ text: String, from source: Language, to target: Language) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let stub { return try await stub(trimmed, source, target) }
        return try await withCheckedThrowingContinuation { continuation in
            let item = Request(text: trimmed, source: source, target: target, continuation: continuation)
            pending.append(item)
            request(source: source, target: target)
            Task { [weak self, timeout] in
                try? await Task.sleep(for: timeout)
                self?.pending.removeAll { $0.id == item.id }
                item.finish(.failure(TranslationFailure.timedOut))
            }
        }
    }

    func prepare(from source: Language, to target: Language) {
        prepareOnly = (source, target)
        request(source: source, target: target)
    }

    func drain(_ session: TranslationSession) async {
        if let pair = prepareOnly, pending.isEmpty {
            prepareOnly = nil
            _ = pair
            try? await session.prepareTranslation()
            return
        }
        prepareOnly = nil
        let source = configuration?.source
        let target = configuration?.target
        let batch = pending.filter { $0.source.localeLanguage == source && $0.target.localeLanguage == target }
        pending.removeAll { $0.source.localeLanguage == source && $0.target.localeLanguage == target }
        for item in batch {
            do {
                let response = try await session.translate(item.text)
                item.finish(.success(response.targetText))
            } catch {
                item.finish(.failure(Self.map(error, target: item.target)))
            }
        }
        if let next = pending.first {
            request(source: next.source, target: next.target)
        }
    }

    private func request(source: Language, target: Language) {
        let wanted = TranslationSession.Configuration(source: source.localeLanguage, target: target.localeLanguage)
        if configuration?.source == wanted.source, configuration?.target == wanted.target {
            configuration?.invalidate()
        } else {
            configuration = wanted
        }
    }

    private static func map(_ error: Error, target: Language) -> TranslationFailure {
        if TranslationError.unsupportedLanguagePairing ~= error || TranslationError.unsupportedSourceLanguage ~= error
            || TranslationError.unsupportedTargetLanguage ~= error {
            return .unsupported
        }
        if error is CancellationError { return .notDownloaded(target) }
        return .failed
    }
}
