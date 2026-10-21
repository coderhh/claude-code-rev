# TV Browser (tvOS)

A SwiftUI app for Apple TV that browses the web and plays video.

## How it works

tvOS ships no public web view (`WKWebView`/`UIWebView` are unavailable), so this app does not render pages with a web engine. Instead it:

1. Fetches a page with `URLSession` (URL bar, or a DuckDuckGo search for non-URL input).
2. Parses it (`PageParser`) into a title, text excerpt, link list, and video sources (`<video>`, `<source>`, `og:video`, and `.m3u8/.mp4/.m4v/.mov` URLs embedded in scripts/JSON).
3. Shows these as focusable lists navigated with the Siri Remote.
4. Plays media with `AVPlayer` (native tvOS player: HLS, MP4, AirPlay, PiP-less transport controls).

Direct media URLs, or responses with a `video/*`, `audio/*` or HLS content type, play immediately. Back navigation and bookmarks (persisted in `UserDefaults`) are included.

## Limitations

- No JavaScript, CSS or layout: sites whose videos are assembled by JS (YouTube, Netflix, most DRM/MSE players) will not expose a playable URL. FairPlay/DRM content is not supported.
- Only sources AVFoundation supports play (HLS, MP4/MOV, MP3/AAC); WebM/DASH do not.
- `NSAllowsArbitraryLoads` is on so plain-http pages work; tighten it for App Store submission.
- Embedding a real engine would require private API (App Store rejection) or server-side rendering streamed to the TV; neither is implemented.

## Build

Needs macOS with Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
cd tvos-browser
xcodegen generate
open TVBrowser.xcodeproj   # run on an Apple TV simulator or device
```

This was written on Linux and has not been compiled or run; expect to fix minor compiler issues on first build.
