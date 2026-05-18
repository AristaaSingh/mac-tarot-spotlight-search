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
    static let journalW:    CGFloat = 1024
    static let journalH:    CGFloat = 500

    private var hostingView: NSHostingView<OverlayRootView>?
    private var modeCancellable: AnyCancellable?

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

    func show() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let frame = frameForMode(OverlayMode.shared.current, screen: screen)
        panel.setFrame(frame, display: false)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        ThumbnailWindowManager.shared.clear()
        window?.orderOut(nil)
        OverlayMode.shared.current = .search
    }

    private func animateToMode(_ mode: OverlayMode.Mode) {
        ThumbnailWindowManager.shared.clear()
        guard let panel = window, let screen = NSScreen.main else { return }
        let newFrame = frameForMode(mode, screen: screen)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
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
        switch mode.current {
        case .search:  SearchOverlayView()
        case .journal: JournalView()
        }
    }
}
