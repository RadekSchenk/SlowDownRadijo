import Foundation

/// One piece of a parsed `NewsPost.contentRendered` body, in original
/// document order.
enum NewsContentBlock: Identifiable {
    case paragraph(String)
    case image(URL)
    case videoEmbed(URL)

    var id: String {
        switch self {
        case .paragraph(let text): return "p-\(text.hashValue)"
        case .image(let url): return "i-\(url.absoluteString)"
        case .videoEmbed(let url): return "v-\(url.absoluteString)"
        }
    }
}

/// Breaks a WordPress post's raw HTML into an ordered sequence of plain
/// paragraphs, images, and video embeds — deliberately not a full HTML
/// renderer (no WebView, no site styling). `<img>`/`<iframe>` tags are
/// pulled out as their own blocks in place; everything else is flattened
/// to plain text, splitting on paragraph/line-break boundaries.
enum NewsContentParser {
    private static let mediaPattern = try! NSRegularExpression(
        pattern: #"<img[^>]+src="([^"]+)"[^>]*>|<iframe[^>]+src="([^"]+)"[^>]*>.*?</iframe>"#,
        options: [.dotMatchesLineSeparators, .caseInsensitive]
    )

    static func parse(_ html: String) -> [NewsContentBlock] {
        let nsHTML = html as NSString
        let matches = mediaPattern.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        var blocks: [NewsContentBlock] = []
        var cursor = 0

        for match in matches {
            let precedingRange = NSRange(location: cursor, length: match.range.location - cursor)
            appendParagraphs(from: nsHTML.substring(with: precedingRange), into: &blocks)

            if let imgRange = Range(match.range(at: 1), in: html), !imgRange.isEmpty,
               let url = URL(string: String(html[imgRange])) {
                blocks.append(.image(url))
            } else if match.range(at: 2).location != NSNotFound,
                      let iframeRange = Range(match.range(at: 2), in: html),
                      let url = URL(string: String(html[iframeRange])) {
                blocks.append(.videoEmbed(url))
            }
            cursor = match.range.location + match.range.length
        }
        appendParagraphs(from: nsHTML.substring(from: cursor), into: &blocks)
        return blocks
    }

    private static func appendParagraphs(from raw: String, into blocks: inout [NewsContentBlock]) {
        let normalized = raw
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)

        for chunk in normalized.components(separatedBy: "\n\n") {
            let text = chunk.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            blocks.append(.paragraph(text))
        }
    }
}

extension String {
    /// Strips tags and decodes entities (e.g. `&#038;` → `&`) — WordPress
    /// titles and content are always UTF-8 HTML fragments, so this is safe
    /// to run synchronously for the small strings involved here.
    var htmlStripped: String {
        guard let data = data(using: .utf8) else { return self }
        let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ],
            documentAttributes: nil
        )
        return attributed?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? self
    }
}
