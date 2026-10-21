import Foundation
import AVKit

@MainActor
final class BrowserModel: ObservableObject {
    @Published var addressText = "https://"
    @Published var page: ParsedPage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var player: AVPlayer?
    @Published var bookmarks: [URL] = []
    @Published private(set) var history: [URL] = []

    private let bookmarksKey = "bookmarks"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: bookmarksKey) ?? []
        bookmarks = saved.compactMap(URL.init(string:))
    }

    var canGoBack: Bool { history.count > 1 }

    // MARK: - Navigation

    func go() {
        guard let url = Self.normalize(addressText) else {
            errorMessage = "Invalid address"
            return
        }
        load(url)
    }

    func load(_ url: URL, pushHistory: Bool = true) {
        if PageParser.isMedia(url) {
            play(url)
            return
        }
        addressText = url.absoluteString
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (AppleTV; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                                 forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                let finalURL = response.url ?? url
                let mime = response.mimeType?.lowercased() ?? ""
                if mime.hasPrefix("video/") || mime.hasPrefix("audio/") || mime.contains("mpegurl") {
                    play(finalURL)
                    return
                }
                let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) ?? ""
                page = PageParser.parse(html: html, baseURL: finalURL)
                if pushHistory { history.append(finalURL) }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func goBack() {
        guard canGoBack else { return }
        history.removeLast()
        if let previous = history.last {
            load(previous, pushHistory: false)
        }
    }

    // MARK: - Playback

    func play(_ url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
    }

    func stopPlayback() {
        player?.pause()
        player = nil
    }

    // MARK: - Bookmarks

    func toggleBookmark() {
        guard let url = page?.url else { return }
        if let i = bookmarks.firstIndex(of: url) { bookmarks.remove(at: i) } else { bookmarks.append(url) }
        UserDefaults.standard.set(bookmarks.map(\.absoluteString), forKey: bookmarksKey)
    }

    var isBookmarked: Bool {
        guard let url = page?.url else { return false }
        return bookmarks.contains(url)
    }

    // MARK: - Helpers

    static func normalize(_ text: String) -> URL? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t != "https://" else { return nil }
        if t.contains("://") { return URL(string: t) }
        if t.contains(".") && !t.contains(" ") { return URL(string: "https://" + t) }
        let q = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t
        return URL(string: "https://duckduckgo.com/html/?q=" + q)
    }
}
