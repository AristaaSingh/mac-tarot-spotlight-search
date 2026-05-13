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

    static let windowWidth:  CGFloat = 760
    static let windowHeight: CGFloat = 480

    init(card: TarotCard) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0,
                                width:  Self.windowWidth,
                                height: Self.windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = true
        panel.backgroundColor = NSColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1)
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
        window?.orderFrontRegardless()
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let x = sf.midX - Self.windowWidth  / 2
        let y = sf.midY - Self.windowHeight / 2
        window?.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
