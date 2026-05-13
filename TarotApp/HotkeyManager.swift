import AppKit
import Carbon.HIToolbox

// Registers a global hotkey (default: ⌥Space) that toggles the overlay from anywhere.
// Requires Accessibility permission on macOS — the app will prompt on first launch.
class HotkeyManager {

    static let shared = HotkeyManager()
    private var monitor: Any?

    private init() {}

    func register() {
        // Check silently first — only show the system prompt if not yet granted
        if !AXIsProcessTrusted() {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
            AXIsProcessTrustedWithOptions(options)
        }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // ⌥Space  (Option + Space)
            if event.modifierFlags.contains(.option) && event.keyCode == kVK_Space {
                DispatchQueue.main.async {
                    OverlayWindowController.shared.toggle()
                }
            }
        }
    }

    func unregister() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
