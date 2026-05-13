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
        controller.contentWindow?.orderOut(nil)
        controller.window?.orderOut(nil)
        popups.removeAll { $0 === controller }
    }
}

class CardPopupWindowController: NSWindowController {

    static let cardWidth:    CGFloat = 280
    static let cardHeight:   CGFloat = 490
    static let contentWidth: CGFloat = 320

    // The companion content window (meanings, keywords, notes)
    var contentWindow: NSWindow?

    // Shared reversed state so content window stays in sync
    private var isReversed = false

    init(card: TarotCard) {
        // — Card image panel —
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0,
                                width:  Self.cardWidth,
                                height: Self.cardHeight),
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

        let cardView = CardPopupView(card: card) { [weak self] in
            guard let self else { return }
            CardPopupManager.shared.close(self)
        } onReversedChange: { [weak self] reversed in
            self?.updateContentWindow(card: card, isReversed: reversed)
        }
        panel.contentView = NSHostingView(rootView: cardView)

        // — Content window —
        let cw = NSPanel(
            contentRect: NSRect(x: 0, y: 0,
                                width:  Self.contentWidth,
                                height: Self.cardHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        cw.isOpaque = true
        cw.backgroundColor = NSColor(red: 0.07, green: 0.05, blue: 0.13, alpha: 1)
        cw.hasShadow = true
        cw.level = .floating
        cw.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        cw.isMovableByWindowBackground = true
        cw.contentView = NSHostingView(rootView: CardContentView(card: card, isReversed: false))
        cw.contentView?.layer?.cornerRadius = 16
        cw.contentView?.layer?.masksToBounds = true
        self.contentWindow = cw

        positionWindows()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.orderFrontRegardless()
        contentWindow?.orderFrontRegardless()
    }

    // MARK: - Sync content window when card is flipped

    private func updateContentWindow(card: TarotCard, isReversed: Bool) {
        let view = CardContentView(card: card, isReversed: isReversed)
        contentWindow?.contentView = NSHostingView(rootView: view)
    }

    // MARK: - Layout

    private func positionWindows() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let totalW = Self.cardWidth + 12 + Self.contentWidth
        let startX = (sf.width - totalW) / 2 + sf.minX
        let y = (sf.height - Self.cardHeight) / 2 + sf.minY

        window?.setFrameOrigin(NSPoint(x: startX, y: y))
        contentWindow?.setFrameOrigin(NSPoint(x: startX + Self.cardWidth + 12, y: y))
    }
}
