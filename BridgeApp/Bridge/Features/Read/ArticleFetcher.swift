import Foundation

enum ArticleFetcher {
    enum Failure: Error { case unreadable, empty }

    static func link(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace),
              let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", url.host != nil else { return nil }
        return url
    }

    static func fetch(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS like Mac OS X) Bridge", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) { throw Failure.unreadable }
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let text = readableText(fromHTML: html)
        guard !text.isEmpty else { throw Failure.empty }
        return text
    }

    static func readableText(fromHTML html: String) -> String {
        var body = html
        for tag in ["script", "style", "noscript", "nav", "header", "footer", "aside", "form", "svg"] {
            body = body.replacingOccurrences(of: "<\(tag)\\b[\\s\\S]*?</\(tag)>", with: " ",
                                             options: [.regularExpression, .caseInsensitive])
        }
        if let article = firstMatch("<article\\b[\\s\\S]*?</article>", in: body) { body = article }
        let blocks = matches("<(h1|h2|h3|p|li)\\b[^>]*>([\\s\\S]*?)</\\1>", in: body)
        let paragraphs = blocks.compactMap { block -> String? in
            let text = clean(block.text)
            let isHeading = block.tag.hasPrefix("h")
            return text.count >= (isHeading ? 3 : 40) ? text : nil
        }
        var seen = Set<String>()
        return paragraphs.filter { seen.insert($0).inserted }.joined(separator: "\n\n")
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return String(text[range])
    }

    private static func matches(_ pattern: String, in text: String) -> [(tag: String, text: String)] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map {
            (nsText.substring(with: $0.range(at: 1)).lowercased(), nsText.substring(with: $0.range(at: 2)))
        }
    }

    private static func clean(_ fragment: String) -> String {
        var text = fragment.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let namedEntities = [
        "&amp;": "&", "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ",
        "&rsquo;": "\u{2019}", "&lsquo;": "\u{2018}", "&rdquo;": "\u{201D}", "&ldquo;": "\u{201C}",
        "&ndash;": "\u{2013}", "&mdash;": "\u{2014}", "&hellip;": "\u{2026}",
    ]

    private static func decodeEntities(_ text: String) -> String {
        var result = text
        for (entity, value) in namedEntities { result = result.replacingOccurrences(of: entity, with: value) }
        guard let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") else { return result }
        let nsText = result as NSString
        var output = ""
        var last = 0
        for match in regex.matches(in: result, range: NSRange(location: 0, length: nsText.length)) {
            output += nsText.substring(with: NSRange(location: last, length: match.range.location - last))
            let hex = nsText.substring(with: match.range(at: 1)) == "x"
            let digits = nsText.substring(with: match.range(at: 2))
            if let code = UInt32(digits, radix: hex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                output.unicodeScalars.append(scalar)
            } else {
                output += nsText.substring(with: match.range)
            }
            last = match.range.location + match.range.length
        }
        output += nsText.substring(from: last)
        return output
    }
}
