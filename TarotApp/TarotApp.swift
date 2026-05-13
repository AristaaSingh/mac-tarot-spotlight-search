import SwiftUI

@main
struct TarotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — the app lives in the menubar.
        // The overlay panel is managed by OverlayWindowController.
        Settings { EmptyView() }
    }
}
