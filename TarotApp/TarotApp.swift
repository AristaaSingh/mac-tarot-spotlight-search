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
                        OverlayWindowController.shared.showMode(.search)
                    }
                    .keyboardShortcut("1", modifiers: .command)

                    Button("Search Readings") {
                        OverlayWindowController.shared.showMode(.journal)
                    }
                    .keyboardShortcut("2", modifiers: .command)
                }
            }
    }
}
