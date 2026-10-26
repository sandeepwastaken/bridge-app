import Foundation

enum ReadingText {
    static func paragraphs(in source: String) -> [String] {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n")
            .reduce(into: [String]()) { result, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    if result.last != "" { result.append("") }
                } else if result.isEmpty || result.last == "" {
                    if result.last == "" { result.removeLast() }
                    result.append(line)
                } else {
                    result[result.count - 1] += "\n" + line
                }
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
