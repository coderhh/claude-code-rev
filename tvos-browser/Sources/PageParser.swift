import Foundation

struct PageLink: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let url: URL
}

struct VideoItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var title: String { url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent }
}

struct ParsedPage {
    var url: URL
    var title: String
    var links: [PageLink]
    var videos: [VideoItem]
    var text: String
}

enum PageParser {
    static let mediaExtensions: Set<String> = ["m3u8", "mp4", "m4v", "mov", "m4a", "mp3"]

    static func isMedia(_ url: URL) -> Bool {
        mediaExtensions.contains(url.pathExtension.lowercased())
    }

    static func parse(html rawHTML: String, baseURL: URL) -> ParsedPage {
        // JSON-embedded URLs are often escaped as https:\/\/host\/a.m3u8
        let html = rawHTML.replacingOccurrences(of: "\\/", with: "/")

        let title = firstMatch(#"<title[^>]*>(.*?)</title>"#, in: html)
            .map { decodeEntities(stripTags($0)).trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? baseURL.host ?? baseURL.absoluteString

        return ParsedPage(
            url: baseURL,
            title: title,
            links: extractLinks(html, base: baseURL),
            videos: extractVideos(html, base: baseURL),
            text: extractText(html)
        )
    }

    // MARK: - Extraction

    private static func extractVideos(_ html: String, base: URL) -> [VideoItem] {
        var seen = Set<URL>()
        var result: [VideoItem] = []

        func add(_ raw: String) {
            guard let url = resolve(raw, base: base), isMedia(url), seen.insert(url).inserted else { return }
            result.append(VideoItem(url: url))
        }

        // <video src>, <source src>, og:video, plus any absolute media URL in scripts/JSON.
        for raw in allMatches(#"<(?:video|source|audio)[^>]+src\s*=\s*["']([^"']+)["']"#, in: html) { add(raw) }
        for raw in allMatches(#"<meta[^>]+(?:og:video(?::url|:secure_url)?|twitter:player:stream)["'][^>]+content\s*=\s*["']([^"']+)["']"#, in: html) { add(raw) }
        for raw in allMatches(#"https?://[^\s"'<>\\]+?\.(?:m3u8|mp4|m4v|mov)(?:\?[^\s"'<>\\]*)?"#, in: html, group: 0) { add(raw) }
        return result
    }

    private static func extractLinks(_ html: String, base: URL) -> [PageLink] {
        var seen = Set<URL>()
        var result: [PageLink] = []
        let pattern = #"<a\s[^>]*href\s*=\s*["']([^"'#][^"']*)["'][^>]*>(.*?)</a>"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = html as NSString
        for m in re.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let href = ns.substring(with: m.range(at: 1))
            guard let url = resolve(href, base: base),
                  let scheme = url.scheme, scheme.hasPrefix("http"),
                  seen.insert(url).inserted else { continue }
            var label = decodeEntities(stripTags(ns.substring(with: m.range(at: 2))))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            label = label.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            result.append(PageLink(title: label.isEmpty ? url.absoluteString : label, url: url))
            if result.count >= 300 { break }
        }
        return result
    }

    private static func extractText(_ html: String) -> String {
        var s = html
        for tag in ["script", "style", "noscript", "svg"] {
            s = s.replacingOccurrences(of: "<\(tag)[^>]*>.*?</\(tag)>", with: " ",
                                       options: [.regularExpression, .caseInsensitive])
        }
        s = decodeEntities(stripTags(s))
        s = s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return String(s.prefix(3000))
    }

    // MARK: - Helpers

    private static func resolve(_ raw: String, base: URL) -> URL? {
        let trimmed = decodeEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("javascript:") else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }

    private static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }

    private static func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private static func firstMatch(_ pattern: String, in s: String) -> String? {
        allMatches(pattern, in: s).first
    }

    private static func allMatches(_ pattern: String, in s: String, group: Int = 1) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap {
            $0.range(at: group).location == NSNotFound ? nil : ns.substring(with: $0.range(at: group))
        }
    }
}
