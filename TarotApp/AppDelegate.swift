import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenubar()
        HotkeyManager.shared.register()
        _ = ContentStore.shared  // ensures cards.json is written to ~/Documents/TarotApp/

        // Hide dock icon — this app lives in the menubar
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }

    // MARK: - Menubar

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Tarot")
            button.image?.isTemplate = true
            button.action = #selector(menubarTapped)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Search  ⌥Space", action: #selector(showOverlay), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Tarot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func menubarTapped() {
        statusItem?.menu?.popUp(positioning: nil, at: .zero, in: statusItem?.button)
    }

    @objc private func showOverlay() {
        OverlayWindowController.shared.show()
    }
}
