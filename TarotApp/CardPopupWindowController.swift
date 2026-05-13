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

    func close(_ controller: CardPopupWindowController) {
        controller.window?.close()
        popups.removeAll { $0 === controller }
    }
}

class CardPopupWindowController: NSWindowController {

    // Card image display size (2:3 tarot ratio)
    static let cardDisplayW: CGFloat = 220
    static let cardDisplayH: CGFloat = 330
    static let cardPadding:  CGFloat = 24

    // Right panel is exactly the card + padding on all sides
    static let rightPanelW:  CGFloat = cardDisplayW + cardPadding * 2   // 268
    // Window height equals card height + padding top/bottom
    static let windowHeight: CGFloat = cardDisplayH + cardPadding * 2   // 378
    // Left scrollable content panel
    static let leftPanelW:   CGFloat = 460
    static let windowWidth:  CGFloat = leftPanelW + rightPanelW         // 728

    init(card: TarotCard) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0,
                                width:  Self.windowWidth,
                                height: Self.windowHeight),
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

        let view = CardDetailPopupView(card: card) { [weak self] in
            guard let self else { return }
            CardPopupManager.shared.close(self)
        }
        let hosting = NSHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 18
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting

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
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let x = sf.midX - Self.windowWidth  / 2
        let y = sf.midY - Self.windowHeight / 2
        window?.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
