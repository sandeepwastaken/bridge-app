import Foundation

struct Language: RawRepresentable, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    let rawValue: String

    static let english = Language(uncheckedRawValue: "en-US")
    static let hindi = Language(uncheckedRawValue: "hi-IN")

    private static let codes = [
        "en-US", "af", "ar", "be", "bg", "bn", "ca", "cs", "cy", "da", "de", "el", "eo", "es", "et",
        "fa", "fi", "fr", "ga", "gl", "gu", "he", "hi-IN", "hr", "ht", "hu", "id", "is", "it", "ja",
        "ka", "kk", "km", "kn", "ko", "lt", "lv", "mk", "mr", "ms", "mt", "nl", "no", "pl", "pt",
        "ro", "ru", "sk", "sl", "sq", "sv", "sw", "ta", "te", "th", "tl", "tr", "uk", "ur", "vi", "zh-Hans",
    ]

    private init(uncheckedRawValue: String) { rawValue = uncheckedRawValue }

    init?(rawValue: String) {
        let normalized = rawValue == "en" ? "en-US" : (rawValue == "hi" ? "hi-IN" : rawValue)
        guard Self.codes.contains(normalized) else { return nil }
        self.rawValue = normalized
    }

    static var allCases: [Language] { codes.map { Language(uncheckedRawValue: $0) } }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let language = Language(rawValue: value) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported language code: \(value)"))
        }
        self = language
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var localeLanguage: Locale.Language { Locale.Language(identifier: baseCode) }
    var baseCode: String { Locale(identifier: rawValue).language.languageCode?.identifier ?? rawValue }

    var nativeName: String { locale.localizedString(forLanguageCode: baseCode) ?? englishName }

    var englishName: String {
        Locale(identifier: "en").localizedString(forLanguageCode: baseCode)?.localizedCapitalized ?? rawValue
    }

    var other: Language {
        if self == .english { return .hindi }
        return .english
    }
}

enum TalkMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case speak, translate, conversation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speak: "Speak"
        case .translate: "Translate"
        case .conversation: "Talk"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .speak: "Make my words clearer and say them aloud."
        case .translate: "Say my words in the other language."
        case .conversation: "Take turns with another person, each in your own language."
        }
    }
}

enum Side: String, Codable, Sendable {
    case me, partner
    var other: Side { self == .me ? .partner : .me }
}

struct Replacement: Codable, Hashable, Sendable {
    let heard: String
    let saved: String
}

struct Message: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var date = Date()
    var mode: TalkMode
    var side: Side = .me
    var sourceLanguage: Language
    var text: String
    var uncertainWords: [String] = []
    var replacements: [Replacement] = []
    var targetLanguage: Language?
    var translation: String?
    var translationFailed = false
    var wasSpoken = false
    var wasTyped = false

    var spokenText: String { translation ?? text }
    var spokenLanguage: Language { translation != nil ? (targetLanguage ?? sourceLanguage) : sourceLanguage }
}

enum WordKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case person, place, phrase, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .person: "Person"
        case .place: "Place"
        case .phrase: "Phrase"
        case .other: "Word"
        }
    }

    var sectionTitle: String {
        switch self {
        case .person: "People"
        case .place: "Places"
        case .phrase: "Phrases"
        case .other: "Other words"
        }
    }

    var symbol: String {
        switch self {
        case .person: "person.fill"
        case .place: "mappin"
        case .phrase: "text.quote"
        case .other: "character.book.closed"
        }
    }
}

struct WordEntry: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var text: String
    var kind: WordKind
    var note: String = ""
    var language: Language
    var misheard: [String] = []
    var uses = 0
    var fixesBeforeSaving = 0
    var fixesSinceSaving = 0
    var created = Date()
}

struct SessionNumbers: Codable, Equatable, Sendable {
    var utterances: [String: Int] = [:]
    var fixedBeforeSpeaking = 0
    var wordsChanged = 0
    var recognitionMs: [Int] = []
    var translationMs: [Int] = []
    var speechStartMs: [Int] = []

    static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
