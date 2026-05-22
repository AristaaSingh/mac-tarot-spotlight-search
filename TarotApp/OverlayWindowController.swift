import AppKit
import SwiftUI
import Combine

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class OverlayWindowController: NSWindowController {

    static let shared = OverlayWindowController()

    static let panelWidth:  CGFloat = 540
    static let panelHeight: CGFloat = 64
    static let searchW:     CGFloat = 540
    static let searchH:     CGFloat = 64
    static let journalW:    CGFloat = 540
    static let journalH:    CGFloat = 520

    private var hostingView: NSHostingView<OverlayRootView>?
    private var modeCancellable: AnyCancellable?
    private var escapeMonitor: Any?

    private init() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0,
                                width:  OverlayWindowController.searchW,
                                height: OverlayWindowController.searchH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        super.init(window: panel)

        let hv = NSHostingView(rootView: OverlayRootView())
        hv.wantsLayer = true
        hv.layer?.backgroundColor = CGColor(gray: 0, alpha: 0)
        hv.layer?.isOpaque = false
        panel.contentView = hv
        hostingView = hv

        modeCancellable = OverlayMode.shared.$current
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in self?.animateToMode(mode) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func toggle() {
        guard let panel = window else { return }
        if panel.isVisible { hide() } else { show() }
    }

    /// Opens the overlay in a specific mode.
    /// - If the panel is already visible, delegates to animateToMode (same as Tab).
    /// - If hidden, sets both `current` and `displayed` before showing so the right
    ///   content is rendered at the correct frame size from the first frame.
    func showMode(_ mode: OverlayMode.Mode) {
        guard let panel = window else { return }
        if panel.isVisible {
            guard OverlayMode.shared.current != mode else {
                // Already in this mode — just bring it to front.
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
                return
            }
            OverlayMode.shared.current = mode   // triggers animateToMode via Combine
        } else {
            OverlayMode.shared.current   = mode
            OverlayMode.shared.displayed = mode // skip animation, show correct content immediately
            show()
        }
    }

    func show() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let frame = frameForMode(OverlayMode.shared.current, screen: screen)
        panel.setFrame(frame, display: false)
        panel.alphaValue = 1
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if escapeMonitor == nil {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53, self?.window?.isVisible == true else { return event }
                self?.hide()
                return nil
            }
        }
    }

    func hide() {
        if let m = escapeMonitor { NSEvent.removeMonitor(m); escapeMonitor = nil }
        ThumbnailWindowManager.shared.clear()
        guard let panel = window else { return }
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.2
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeIn)
        panel.animator().alphaValue = 0
        NSAnimationContext.endGrouping()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            panel.orderOut(nil)
            panel.alphaValue = 1
            OverlayMode.shared.displayed = .search
            OverlayMode.shared.current   = .search
        }
    }

    private func animateToMode(_ mode: OverlayMode.Mode) {
        ThumbnailWindowManager.shared.clear()
        guard let panel = window, panel.isVisible, let screen = NSScreen.main else { return }
        let newFrame = frameForMode(mode, screen: screen)

        // Step 1 — fade out current content
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.12
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeIn)
        panel.animator().alphaValue = 0
        NSAnimationContext.endGrouping()

        // Step 2 — after fade: snap to new size, swap content
        // Step 3 — fade new content back in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            panel.setFrame(newFrame, display: true)
            OverlayMode.shared.displayed = mode

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.18
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            NSAnimationContext.endGrouping()
        }
    }

    private func frameForMode(_ mode: OverlayMode.Mode, screen: NSScreen) -> NSRect {
        let sf = screen.visibleFrame
        switch mode {
        case .search:
            let x = sf.midX - Self.searchW / 2
            let y = sf.maxY - 180 - Self.searchH
            return NSRect(x: x, y: y, width: Self.searchW, height: Self.searchH)
        case .journal:
            let x = sf.midX - Self.journalW / 2
            let y = sf.midY - Self.journalH / 2
            return NSRect(x: x, y: y, width: Self.journalW, height: Self.journalH)
        }
    }
}

struct OverlayRootView: View {
    @ObservedObject var mode = OverlayMode.shared
    var body: some View {
        switch mode.displayed {
        case .search:  SearchOverlayView()
        case .journal: JournalView()
        }
    }
}
