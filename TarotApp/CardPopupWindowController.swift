import AppKit
import SwiftUI

class CardPopupManager {
    static let shared = CardPopupManager()
    private var popups: [CardPopupWindowController] = []

    func open(card: TarotCard) {
        let popup = CardPopupWindowController(card: card)
        popups.append(popup)
        popup.show()
    }

    func remove(_ controller: CardPopupWindowController) {
        popups.removeAll { $0 === controller }
    }
}

class CardPopupWindowController: NSWindowController, NSWindowDelegate {

    private var eventMonitor: Any?

    // Card image display size (2:3 tarot ratio)
    static let cardDisplayW: CGFloat = 220
    static let cardDisplayH: CGFloat = 330
    static let cardPadding:  CGFloat = 24

    static let rightPanelW:  CGFloat = cardDisplayW + cardPadding * 2   // 268
    static let windowHeight: CGFloat = cardDisplayH + cardPadding * 2   // 378
    static let leftPanelW:   CGFloat = 460
    static let windowWidth:  CGFloat = leftPanelW + rightPanelW         // 728

    init(card: TarotCard) {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0,
                                width:  Self.windowWidth,
                                height: Self.windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isMovableByWindowBackground = true
        win.collectionBehavior = [.canJoinAllSpaces]

        super.init(window: win)
        win.delegate = self

        let view = CardDetailPopupView(card: card) { [weak win] in win?.close() }
        let hosting = NSHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 18
        hosting.layer?.masksToBounds = true
        win.contentView = hosting

        position()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.window?.close()
                return nil
            }
            return event
        }
    }

    // Called when window closes (red button or SwiftUI close button)
    func windowWillClose(_ notification: Notification) {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        CardPopupManager.shared.remove(self)
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let x = sf.midX - Self.windowWidth  / 2
        let y = sf.midY - Self.windowHeight / 2
        window?.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
