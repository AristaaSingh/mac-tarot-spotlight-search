import SwiftUI

@main
struct TarotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — the app lives in the overlay panel.
        Settings { EmptyView() }
            .commands {
                CommandMenu("Modes") {
                    Button("Search Cards") {
                        OverlayMode.shared.current = .search
                        OverlayWindowController.shared.show()
                    }
                    .keyboardShortcut("1", modifiers: .command)

                    Button("Search Readings") {
                        OverlayMode.shared.current = .journal
                        OverlayWindowController.shared.show()
                    }
                    .keyboardShortcut("2", modifiers: .command)
                }
            }
    }
}
