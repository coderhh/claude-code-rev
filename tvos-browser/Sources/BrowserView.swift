import SwiftUI
import AVKit

struct BrowserView: View {
    @EnvironmentObject var browser: BrowserModel

    private var isPlaying: Binding<Bool> {
        Binding(get: { browser.player != nil },
                set: { if !$0 { browser.stopPlayback() } })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    toolbar

                    if browser.isLoading { ProgressView("Loading…") }
                    if let error = browser.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }

                    if let page = browser.page {
                        pageContent(page)
                    } else {
                        home
                    }
                }
                .padding(60)
            }
        }
        .fullScreenCover(isPresented: isPlaying) {
            if let player = browser.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 20) {
            Button("Back") { browser.goBack() }
                .disabled(!browser.canGoBack)
            TextField("Enter URL or search", text: $browser.addressText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { browser.go() }
            Button("Go") { browser.go() }
            if browser.page != nil {
                Button(browser.isBookmarked ? "Unbookmark" : "Bookmark") { browser.toggleBookmark() }
            }
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bookmarks").font(.title2)
            if browser.bookmarks.isEmpty {
                Text("Enter a URL above. Pages are shown as video and link lists; direct .m3u8 / .mp4 links play immediately.")
                    .foregroundStyle(.secondary)
            }
            ForEach(browser.bookmarks, id: \.self) { url in
                Button(url.absoluteString) { browser.load(url) }
            }
        }
    }

    @ViewBuilder
    private func pageContent(_ page: ParsedPage) -> some View {
        Text(page.title).font(.title)

        if !page.videos.isEmpty {
            Text("Videos").font(.title2)
            ForEach(page.videos) { video in
                Button("▶ " + video.title) { browser.play(video.url) }
            }
        }

        if !page.text.isEmpty {
            Text(page.text).font(.callout).foregroundStyle(.secondary).lineLimit(8)
        }

        if !page.links.isEmpty {
            Text("Links").font(.title2)
            ForEach(page.links) { link in
                Button(link.title) { browser.load(link.url) }
            }
        }
    }
}
