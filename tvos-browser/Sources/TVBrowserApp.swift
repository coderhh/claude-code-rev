import SwiftUI

@main
struct TVBrowserApp: App {
    @StateObject private var browser = BrowserModel()

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(browser)
        }
    }
}
