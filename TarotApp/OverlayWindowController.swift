import AppKit
import SwiftUI

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class OverlayWindowController: NSWindowController {

    static let shared = OverlayWindowController()
    static let panelWidth:  CGFloat = 580
    static let panelHeight: CGFloat = 540

    private init() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0,
                                width:  OverlayWindowController.panelWidth,
                                height: OverlayWindowController.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: SearchOverlayView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = CGColor(gray: 0, alpha: 0)
        hostingView.layer?.isOpaque = false
        panel.contentView = hostingView

        super.init(window: panel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func toggle() {
        guard let panel = window else { return }
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let topEdge = sf.maxY - 160
        let x = (sf.width - Self.panelWidth) / 2 + sf.minX
        let y = topEdge - Self.panelHeight
        panel.setFrame(NSRect(x: x, y: y, width: Self.panelWidth, height: Self.panelHeight),
                       display: false)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}
