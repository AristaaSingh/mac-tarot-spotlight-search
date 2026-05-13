import AppKit
import SwiftUI

class ThumbnailWindowManager {
    static let shared = ThumbnailWindowManager()
    private var panels: [NSPanel] = []

    private static let thumbW:    CGFloat = 110
    private static let thumbH:    CGFloat = 165
    private static let colGap:    CGFloat = 12
    private static let rowGap:    CGFloat = 14
    private static let maxPerRow: Int     = 7
    private static let maxCards:  Int     = 21

    private init() {}

    func show(cards: [TarotCard]) {
        clear()
        guard !cards.isEmpty,
              let screen = NSScreen.main,
              let searchFrame = OverlayWindowController.shared.window?.frame else { return }

        let displayed = Array(cards.prefix(Self.maxCards))
        let perRow    = min(displayed.count, Self.maxPerRow)
        let w = Self.thumbW, h = Self.thumbH
        let cg = Self.colGap, rg = Self.rowGap

        for (i, card) in displayed.enumerated() {
            let row = i / perRow
            let col = i % perRow

            // Each row is individually centered on screen
            let rowStart = row * perRow
            let rowCount = min(perRow, displayed.count - rowStart)
            let rowWidth = CGFloat(rowCount) * w + CGFloat(rowCount - 1) * cg
            let x = screen.frame.midX - rowWidth / 2 + CGFloat(col) * (w + cg)

            // Rows stack downward below the search bar
            let topOfRow = searchFrame.minY - rg - CGFloat(row) * (h + rg)
            let y = topOfRow - h

            let panel = makePanel(card: card,
                                  frame: NSRect(x: x, y: y, width: w, height: h),
                                  delay: Double(i) * 0.025)
            panels.append(panel)
            panel.orderFront(nil)
        }
    }

    func clear() {
        panels.forEach { $0.close() }
        panels.removeAll()
    }

    private func makePanel(card: TarotCard, frame: NSRect, delay: Double) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false

        let content = ThumbnailCardView(card: card, delay: delay) {
            OverlayWindowController.shared.hide()
            CardPopupManager.shared.open(card: card)
        }
        panel.contentView = NSHostingView(rootView: content)
        return panel
    }
}

private struct ThumbnailCardView: View {
    let card: TarotCard
    let delay: Double
    let onTap: () -> Void
    @State private var appeared = false

    var body: some View {
        CardThumbnailView(card: card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(appeared ? 1 : 0.75)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.38, dampingFraction: 0.70).delay(delay), value: appeared)
            .onAppear { appeared = true }
            .onTapGesture { onTap() }
    }
}
