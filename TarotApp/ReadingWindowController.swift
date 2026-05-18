import AppKit
import SwiftUI

// Borderless window that can still accept key events and become first responder.
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

    static let windowW: CGFloat = 620
    static let windowH: CGFloat = 580

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
