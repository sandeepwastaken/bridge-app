import Foundation
import NaturalLanguage

enum KeySentences {
    private static let commonWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "your", "with", "this", "that", "from", "they", "have",
        "has", "had", "was", "were", "will", "would", "can", "could", "should", "there", "their", "them", "then",
        "than", "what", "when", "where", "which", "who", "how", "all", "any", "our", "its", "his", "her", "she",
        "him", "been", "into", "about", "also", "just", "more", "some", "such", "only", "over", "very", "may",
    ]

    static func extract(from text: String, limit: Int = 3) -> [String] {
        let sentences = split(text, unit: .sentence)
        guard sentences.count > limit else { return sentences }
        let wordsPerSentence = sentences.map { sentence in
            split(sentence, unit: .word).map { $0.lowercased() }.filter { $0.count > 2 && !commonWords.contains($0) }
        }
        var frequency: [String: Int] = [:]
        for words in wordsPerSentence { for word in Set(words) { frequency[word, default: 0] += 1 } }
        let scores = wordsPerSentence.enumerated().map { index, words -> Double in
            guard !words.isEmpty else { return 0 }
            let total = words.reduce(0) { $0 + Double(frequency[$1, default: 0]) }
            let lead = index == 0 ? 0.5 : 0
            return total / Double(words.count).squareRoot() + lead
        }
        let chosen = scores.indices.sorted { scores[$0] > scores[$1] || (scores[$0] == scores[$1] && $0 < $1) }.prefix(limit)
        return chosen.sorted().map { sentences[$0] }
    }

    private static func split(_ text: String, unit: NLTokenUnit) -> [String] {
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
