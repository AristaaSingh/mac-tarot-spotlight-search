import AppKit

// MARK: - Shared KeyableWindow

/// Borderless NSWindow subclass that overrides canBecomeKey and canBecomeMain so:
/// • clicks on the window bring it to front and make it key
/// • text views and text fields inside it receive keyboard input
class KeyableWindow: NSWindow {
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Common window style

extension NSWindow {
    /// Applies the standard app window appearance: transparent background, shadow,
    /// movable by background, floating level, and the given collection behavior.
    func applyAppStyle(
        collectionBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces]
    ) {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        level = .floating
        self.collectionBehavior = collectionBehavior
    }
}

// MARK: - Fade animations

extension NSWindowController {
    /// Activates the app, makes the window key, and fades it in.
    func showAnimated(duration: TimeInterval = 0.25) {
        window?.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
    }

    /// Fades the window out and closes it.
    func closeAnimated(duration: TimeInterval = 0.18, completion: (() -> Void)? = nil) {
        guard let win = window else { completion?(); return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().alphaValue = 0
        } completionHandler: {
            win.close()
            completion?()
        }
    }
}

// MARK: - Key event monitor

extension NSWindowController {
    /// Registers a local keyDown monitor that only fires when this controller's window is
    /// currently key. Call `NSEvent.removeMonitor(_:)` on the returned token to unregister.
    @discardableResult
    func addKeyMonitor(handler: @escaping (NSEvent) -> NSEvent?) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.window?.isKeyWindow == true else { return event }
            return handler(event)
        }
    }
}
