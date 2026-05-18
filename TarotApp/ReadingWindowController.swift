import AppKit
import SwiftUI

// MARK: - Card Picker Thumbnail Manager
// Mirrors ThumbnailWindowManager but calls onSelect instead of opening a card popup.

class CardPickerThumbnailManager {
    static let shared = CardPickerThumbnailManager()
    private var panels: [NSPanel] = []
    private var onSelectCallback: ((TarotCard) -> Void)?

    private static let thumbW:   CGFloat = 90
    private static let thumbH:   CGFloat = 135
    private static let colGap:   CGFloat = 10
    private static let rowGap:   CGFloat = 14
    private static let maxCards: Int     = 7   // one row max

    private init() {}

    func show(cards: [TarotCard], relativeTo editorFrame: NSRect,
              onSelect: @escaping (TarotCard) -> Void) {
        clear()
        guard !cards.isEmpty, let screen = NSScreen.main else { return }
        onSelectCallback = onSelect

        let displayed = Array(cards.prefix(Self.maxCards))
        let w = Self.thumbW, h = Self.thumbH, cg = Self.colGap

        let rowWidth = CGFloat(displayed.count) * w + CGFloat(displayed.count - 1) * cg
        let startX   = screen.frame.midX - rowWidth / 2

        // The search pill floats at the vertical center of the editor window (~48 pt tall).
        // Position thumbnails just below it; since panels are .floating+1 they render
        // above the editor window even though they overlap with it.
        let pillBottom = editorFrame.minY + editorFrame.height / 2 - 24
        let rowY       = pillBottom - Self.rowGap - h

        for (i, card) in displayed.enumerated() {
            let x     = startX + CGFloat(i) * (w + cg)
            let frame = NSRect(x: x, y: rowY, width: w, height: h)
            let delay = Double(i) * 0.025
            let panel = makePanel(card: card, frame: frame, delay: delay)
            panels.append(panel)
            panel.orderFront(nil)
        }
    }

    func clear() {
        panels.forEach { $0.close() }
        panels.removeAll()
        onSelectCallback = nil
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
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false

        let view = PickerThumbnailView(card: card, delay: delay) { [weak self] in
            self?.onSelectCallback?(card)
        }
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }
}

private struct PickerThumbnailView: View {
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

// MARK: - Borderless window that can still accept key events and become first responder.
private class KeyableWindow: NSWindow {
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Manager

class ReadingWindowManager {
    static let shared = ReadingWindowManager()
    private var controllers: [ReadingWindowController] = []

    /// Open an existing entry. Brings existing window to front if already open.
    func open(entry: ReadingEntry) {
        if let existing = controllers.first(where: { $0.entryID == entry.id }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let ctrl = ReadingWindowController(entry: entry, isNew: false)
        controllers.append(ctrl)
        ctrl.show()
    }

    /// Open a blank entry for writing.
    func openNew() {
        let ctrl = ReadingWindowController(entry: ReadingEntry(), isNew: true)
        controllers.append(ctrl)
        ctrl.show()
    }

    func remove(_ controller: ReadingWindowController) {
        controllers.removeAll { $0 === controller }
    }
}

// MARK: - Window Controller

class ReadingWindowController: NSWindowController, NSWindowDelegate {

    let entryID: String
    private var eventMonitor: Any?

    static let windowW: CGFloat = 1024
    static let windowH: CGFloat = 600

    init(entry: ReadingEntry, isNew: Bool) {
        self.entryID = entry.id

        let win = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0,
                                width:  ReadingWindowController.windowW,
                                height: ReadingWindowController.windowH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isMovableByWindowBackground = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: win)
        win.delegate = self

        let view = ReadingEditorView(
            entry: entry,
            isNew: isNew,
            onSave: { [weak win] saved in
                ReadingStore.shared.save(saved)
                win?.close()
            },
            onDelete: { [weak win] in
                ReadingStore.shared.delete(entry)
                win?.close()
            },
            onClose: { [weak win] in
                win?.close()
            }
        )

        let hosting = NSHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 20
        hosting.layer?.masksToBounds = true
        win.contentView = hosting

        position()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }   // Escape
            self?.window?.close()
            return nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        ReadingWindowManager.shared.remove(self)
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        // Offset slightly so it doesn't sit exactly behind the journal window
        let x = sf.midX - ReadingWindowController.windowW / 2 + 40
        let y = sf.midY - ReadingWindowController.windowH / 2 + 20
        window?.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
