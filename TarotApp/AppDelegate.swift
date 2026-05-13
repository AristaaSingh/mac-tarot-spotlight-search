import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        OverlayWindowController.shared.show()
    }

    // Re-show search when user clicks the dock icon
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        OverlayWindowController.shared.show()
        return true
    }
}
