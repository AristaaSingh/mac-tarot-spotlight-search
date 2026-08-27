import AppKit
import SwiftUI

extension Notification.Name {
    static let fullscreenWillShow = Notification.Name("fullscreenWillShow")
}

enum FullscreenScreen {
    case search
    case journal
    case card(TarotCard)
}

final class FullscreenState: ObservableObject {
    static let shared = FullscreenState()
    @Published var screen: FullscreenScreen = .search
    private init() {}
}

final class FullscreenWindowController: NSWindowController, NSWindowDelegate {
    static let shared = FullscreenWindowController()
    private var keyMonitor: Any?

    private init() {
        let win = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = .black
        // .fullScreenPrimary lets macOS manage this as a proper fullscreen space —
        // Stage Manager, Mission Control, and swipe gestures all work correctly.
        win.collectionBehavior = [.fullScreenPrimary, .managed]

        super.init(window: win)
        win.delegate = self
        win.contentView = NSHostingView(rootView: FullscreenRootView())
    }

    required init?(coder: NSCoder) { fatalError() }

    func toggle() {
        guard let win = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !win.isVisible { win.makeKeyAndOrderFront(nil) }
        win.toggleFullScreen(nil)
    }

    func navigate(to newScreen: FullscreenScreen) {
        FullscreenState.shared.screen = newScreen
    }

    func hide() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().alphaValue = 0
        }, completionHandler: {
            if win.styleMask.contains(.fullScreen) {
                win.toggleFullScreen(nil)
            } else {
                win.orderOut(nil)
            }
            // Restore alpha after the native exit animation finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                win.alphaValue = 1
            }
        })
    }

    private func handleEscape() {
        switch FullscreenState.shared.screen {
        case .search:          hide()
        case .journal, .card:  navigate(to: .search)
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidEnterFullScreen(_ notification: Notification) {
        NotificationCenter.default.post(name: .fullscreenWillShow, object: nil)
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.window?.isKeyWindow == true else { return event }
            if event.keyCode == 53, !(self?.window?.firstResponder is NSTextView) {
                self?.handleEscape()
                return nil
            }
            return event
        }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
