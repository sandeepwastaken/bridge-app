import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum ExplainerError: Error {
    case unavailable
}

@MainActor
enum Explainer {
    static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "Explanations need an iPhone that supports Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in Settings to get explanations."
            case .unavailable(.modelNotReady):
                return "Apple Intelligence is still getting ready. Try again later."
            case .unavailable:
                return "Explanations are not available on this iPhone."
            }
        }
        #endif
        return "Explanations need iOS 26 with Apple Intelligence."
    }

    static func instructions(for language: Language) -> String {
        """
        You help someone who finds reading hard understand a piece of text. \
        Explain it in \(language.englishName) using short, plain sentences, no more than five. \
        Keep every name, number, date, time and amount exactly as written. \
        If the text asks the reader to do something, say clearly what it asks and by when. \
        Do not add advice, opinions or facts that are not in the text. \
        If something in the text is unclear, say that it is unclear instead of guessing.
        """
    }

    static func explain(_ text: String, in language: Language) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), unavailableReason == nil {
            let session = LanguageModelSession(instructions: instructions(for: language))
            let response = try await session.respond(to: text)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw ExplainerError.unavailable
    }
}
