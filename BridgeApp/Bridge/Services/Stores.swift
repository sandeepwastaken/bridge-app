import Foundation
import SwiftUI
import Translation

enum LocalFile {
    static func url(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bridge", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(name)
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        var target = url(name)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: target, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }
}

enum ControlMethod: String, CaseIterable, Identifiable, Codable {
    case touch
    case scanning
    case head

    var id: String { rawValue }

    var title: String {
        switch self {
        case .touch: "Touch"
        case .scanning: "Tap anywhere (switch scanning)"
        case .head: "Head pointer"
        }
    }

    var summary: String {
        switch self {
        case .touch: "Tap buttons with your finger."
        case .scanning: "Bridge lights up each button in turn. Tap anywhere on the screen, or press a switch, to choose the lit one."
        case .head: "Turn your head to move a pointer. Hold still on a button, or use a face gesture, to choose it."
        }
    }

    var symbol: String {
        switch self {
        case .touch: "hand.tap.fill"
        case .scanning: "square.grid.3x3.topleft.filled"
        case .head: "face.smiling"
        }
    }
}

enum HeadSelect: String, CaseIterable, Identifiable, Codable {
    case dwell, openMouth, raiseEyebrows, smile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dwell: "Hold still"
        case .openMouth: "Open mouth"
        case .raiseEyebrows: "Raise eyebrows"
        case .smile: "Smile"
        }
    }
}

enum TextSizeBoost: String, CaseIterable, Identifiable, Codable {
    case system, large, extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Same as device"
        case .large: "Large"
        case .extraLarge: "Extra large"
        }
    }

    var range: ClosedRange<DynamicTypeSize> {
        switch self {
        case .system: .xSmall ... .accessibility5
        case .large: .xxxLarge ... .accessibility5
        case .extraLarge: .accessibility2 ... .accessibility5
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published private(set) var supportedLanguages: [Language] = [.english, .hindi]

    func refreshSupportedLanguages() async {
        let available = await LanguageAvailability().supportedLanguages
        let codes = Set(available.compactMap { $0.languageCode?.identifier })
        let matches = Language.allCases.filter { codes.contains($0.baseCode) }
        if !matches.isEmpty { supportedLanguages = matches }
    }

    @Published var myLanguage: Language {
        didSet {
            defaults.set(myLanguage.rawValue, forKey: "myLanguage")
            if partnerLanguage == myLanguage { partnerLanguage = myLanguage.other }
        }
    }
    @Published var partnerLanguage: Language {
        didSet {
            defaults.set(partnerLanguage.rawValue, forKey: "partnerLanguage")
            if myLanguage == partnerLanguage { myLanguage = partnerLanguage.other }
        }
    }
    @Published var phraseLanguage: Language { didSet { defaults.set(phraseLanguage.rawValue, forKey: "phraseLanguage") } }
    @Published var partnerName: String { didSet { defaults.set(partnerName, forKey: "partnerName") } }
    @Published var speechRate: Float { didSet { defaults.set(speechRate, forKey: "speechRate") } }
    @Published var autoSpeakTurns: Bool { didSet { defaults.set(autoSpeakTurns, forKey: "autoSpeakTurns") } }
    @Published var keepHistory: Bool { didSet { defaults.set(keepHistory, forKey: "keepHistory") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    @Published var usePersonalVoice: Bool { didSet { defaults.set(usePersonalVoice, forKey: "usePersonalVoice") } }
    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }
    @Published var textSize: TextSizeBoost { didSet { defaults.set(textSize.rawValue, forKey: "textSize") } }

    @Published var control: ControlMethod { didSet { defaults.set(control.rawValue, forKey: "control") } }
    @Published var scanInterval: Double { didSet { defaults.set(scanInterval, forKey: "scanInterval") } }
    @Published var dwellTime: Double { didSet { defaults.set(dwellTime, forKey: "dwellTime") } }
    @Published var headSelect: HeadSelect { didSet { defaults.set(headSelect.rawValue, forKey: "headSelect") } }
    @Published var pointerSpeed: Double { didSet { defaults.set(pointerSpeed, forKey: "pointerSpeed") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let mine = Language(rawValue: defaults.string(forKey: "myLanguage") ?? "") ?? .english
        let partner = Language(rawValue: defaults.string(forKey: "partnerLanguage") ?? "") ?? .hindi
        myLanguage = mine
        partnerLanguage = partner == mine ? mine.other : partner
        phraseLanguage = Language(rawValue: defaults.string(forKey: "phraseLanguage") ?? "") ?? mine
        partnerName = defaults.string(forKey: "partnerName") ?? ""
        func has(_ key: String) -> Bool { defaults.object(forKey: key) != nil }
        speechRate = has("speechRate") ? defaults.float(forKey: "speechRate") : Speaker.defaultRate
        autoSpeakTurns = has("autoSpeakTurns") ? defaults.bool(forKey: "autoSpeakTurns") : false
        keepHistory = has("keepHistory") ? defaults.bool(forKey: "keepHistory") : false
        haptics = has("haptics") ? defaults.bool(forKey: "haptics") : true
        usePersonalVoice = defaults.bool(forKey: "usePersonalVoice")
        onboarded = defaults.bool(forKey: "onboarded")
        textSize = TextSizeBoost(rawValue: defaults.string(forKey: "textSize") ?? "") ?? .system
        control = ControlMethod(rawValue: defaults.string(forKey: "control") ?? "") ?? .touch
        scanInterval = has("scanInterval") ? defaults.double(forKey: "scanInterval") : 1.6
        dwellTime = has("dwellTime") ? defaults.double(forKey: "dwellTime") : 1.2
        headSelect = HeadSelect(rawValue: defaults.string(forKey: "headSelect") ?? "") ?? .dwell
        pointerSpeed = has("pointerSpeed") ? defaults.double(forKey: "pointerSpeed") : 1.0
    }

    var partnerDisplayName: String {
        let trimmed = partnerName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Them" : trimmed
    }
}

@MainActor
final class WordStore: ObservableObject {
    @Published private(set) var entries: [WordEntry]
    private let fileName: String?

    init(fileName: String? = "words.json", entries: [WordEntry]? = nil) {
        self.fileName = fileName
        if let entries {
            self.entries = entries
        } else if let fileName {
            self.entries = LocalFile.load([WordEntry].self, from: fileName) ?? []
        } else {
            self.entries = []
        }
    }

    func entries(of kind: WordKind) -> [WordEntry] {
        entries.filter { $0.kind == kind }.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
    }

    func contains(_ text: String) -> Bool {
        entries.contains { $0.text.compare(text, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    func contextualStrings(for language: Language) -> [String] {
        entries.filter { $0.language == language && $0.kind != .phrase }
            .sorted { $0.uses > $1.uses }
            .map(\.text)
    }

    func upsert(_ entry: WordEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        persist()
    }

    func delete(_ ids: Set<WordEntry.ID>) {
        entries.removeAll { ids.contains($0.id) }
        persist()
    }

    func deleteAll() {
        entries = []
        if let fileName { LocalFile.delete(fileName) }
    }

    func remember(saved: String, heard: String, language: Language) {
        let cleanHeard = heard.trimmingCharacters(in: .punctuationCharacters)
        if let index = entries.firstIndex(where: { $0.text.caseInsensitiveCompare(saved) == .orderedSame }) {
            if !cleanHeard.isEmpty, !entries[index].misheard.contains(where: { $0.caseInsensitiveCompare(cleanHeard) == .orderedSame }) {
                entries[index].misheard.append(cleanHeard)
            }
            entries[index].fixesSinceSaving += 1
        } else {
            let looksLikeName = saved.first?.isUppercase ?? false
            entries.append(WordEntry(
                text: saved,
                kind: looksLikeName ? .person : .other,
                language: language,
                misheard: cleanHeard.isEmpty ? [] : [cleanHeard],
                fixesBeforeSaving: 1
            ))
        }
        persist()
    }

    func applySavedSpellings(to text: String, language: Language) -> (String, [Replacement]) {
        var result = text
        var replacements: [Replacement] = []
        for entry in entries where entry.language == language {
            for heard in entry.misheard where !heard.isEmpty {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: heard) + "\\b"
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
                let range = NSRange(result.startIndex..., in: result)
                if regex.firstMatch(in: result, range: range) != nil {
                    result = regex.stringByReplacingMatches(in: result, range: range,
                                                            withTemplate: NSRegularExpression.escapedTemplate(for: entry.text))
                    replacements.append(Replacement(heard: heard, saved: entry.text))
                }
            }
        }
        return (result, replacements)
    }

    func recordUses(in text: String) {
        var changed = false
        for index in entries.indices where text.range(of: entries[index].text, options: [.caseInsensitive]) != nil {
            entries[index].uses += 1
            changed = true
        }
        if changed { persist() }
    }

    private func persist() {
        if let fileName { LocalFile.save(entries, to: fileName) }
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var messages: [Message]
    private let fileName: String?
    static let limit = 200

    init(fileName: String? = "history.json", messages: [Message]? = nil) {
        self.fileName = fileName
        if let messages {
            self.messages = messages
        } else if let fileName {
            self.messages = LocalFile.load([Message].self, from: fileName) ?? []
        } else {
            self.messages = []
        }
    }

    func append(_ message: Message) {
        messages.append(message)
        if messages.count > Self.limit { messages.removeFirst(messages.count - Self.limit) }
        if let fileName { LocalFile.save(messages, to: fileName) }
    }

    func deleteAll() {
        messages = []
        if let fileName { LocalFile.delete(fileName) }
    }
}

@MainActor
final class Metrics: ObservableObject {
    @Published private(set) var numbers: SessionNumbers
    private let key = "sessionNumbers"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(SessionNumbers.self, from: data) {
            numbers = saved
        } else {
            numbers = SessionNumbers()
        }
    }

    func recordUtterance(_ language: Language, recognitionMs: Int?) {
        numbers.utterances[language.rawValue, default: 0] += 1
        if let recognitionMs { numbers.recognitionMs.append(recognitionMs) }
        save()
    }

    func recordFix(wordsChanged: Int) {
        numbers.fixedBeforeSpeaking += 1
        numbers.wordsChanged += wordsChanged
        save()
    }

    func recordTranslation(ms: Int) { numbers.translationMs.append(ms); save() }
    func recordSpeechStart(ms: Int) { numbers.speechStartMs.append(ms); save() }

    func reset() {
        numbers = SessionNumbers()
        save()
    }

    private func save() {
        numbers.recognitionMs = Array(numbers.recognitionMs.suffix(500))
        numbers.translationMs = Array(numbers.translationMs.suffix(500))
        numbers.speechStartMs = Array(numbers.speechStartMs.suffix(500))
        if let data = try? JSONEncoder().encode(numbers) { defaults.set(data, forKey: key) }
    }
}
