import AppKit
import SwiftUI

class CardTransitionAnimator {

    static func run(from sourceFrame: NSRect, card: TarotCard) {
        guard let screen = NSScreen.main else {
            CardPopupManager.shared.open(card: card)
            return
        }

        // Target frame matches where CardPopupWindowController will place its window
        let sf = screen.visibleFrame
        let targetFrame = NSRect(
            x: sf.midX - CardPopupWindowController.windowWidth  / 2,
            y: sf.midY - CardPopupWindowController.windowHeight / 2,
            width:  CardPopupWindowController.windowWidth,
            height: CardPopupWindowController.windowHeight
        )

        // Overlay panel: black card-shaped, starts at thumbnail position
        let overlay = NSPanel(
            contentRect: sourceFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = true
        overlay.level = .floating
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView:
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)
        )
        overlay.contentView = hostingView
        overlay.orderFront(nil)

        // Expand from thumbnail to window frame
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.38
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            overlay.animator().setFrame(targetFrame, display: true)
        }) {
            // Show real window underneath
            CardPopupManager.shared.open(card: card)

            // Fade the black overlay out
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                overlay.animator().alphaValue = 0
            }) {
                overlay.close()
            }
        }
    }
}
