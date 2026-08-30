import AppKit
import SwiftUI

extension Notification.Name {
    static let fullscreenWillShow = Notification.Name("fullscreenWillShow")
}

// MARK: - Canvas card model

struct PlacedCard: Identifiable {
    var id        = UUID().uuidString
    let card:       TarotCard
    var position:   CGPoint
    var rotation:   Double
}

// MARK: - State

final class FullscreenState: ObservableObject {
    static let shared = FullscreenState()

    @Published var canvasCards:        [PlacedCard] = []
    @Published var showingSearch:       Bool         = false
    @Published var selectedCard:        TarotCard?   = nil
    @Published var showingFolderPicker: Bool         = false
    @Published var toastMessage:        String?      = nil

    private init() {}

    func addCard(_ card: TarotCard, canvasSize: CGSize) {
        guard canvasCards.count < 12 else { return }
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height / 2
        let placed = PlacedCard(
            card:     card,
            position: CGPoint(x: cx + CGFloat.random(in: -240...240),
                              y: cy + CGFloat.random(in: -140...140)),
            rotation: Double.random(in: -10...10)
        )
        canvasCards.append(placed)
    }

    func updatePosition(id: String, to point: CGPoint) {
        guard let idx = canvasCards.firstIndex(where: { $0.id == id }) else { return }
        canvasCards[idx].position = point
    }

    func requestJournalFolder() {
        guard !canvasCards.isEmpty else { return }
        showingFolderPicker = true
    }

    func saveSpread(toFolder folder: Folder) {
        let entries = canvasCards.map { CardEntry(cardID: $0.card.id) }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        let reading = ReadingEntry(
            folderID:    folder.id,
            title:       "Spread – \(fmt.string(from: Date()))",
            cardEntries: entries
        )
        ReadingStore.shared.save(reading)
        showingFolderPicker = false
        showToast("Spread added to \(folder.name)")
    }

    func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.toastMessage = nil
        }
    }
}

// MARK: - Window controller

final class FullscreenWindowController: NSWindowController, NSWindowDelegate {
    static let shared = FullscreenWindowController()
    private var keyMonitor: Any?
    private var hideAfterExitingFullScreen = false

    private init() {
        let win = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = .black
        win.collectionBehavior = [.fullScreenPrimary, .managed]

        super.init(window: win)
        win.delegate = self
        win.contentView = NSHostingView(rootView: FullscreenRootView())
    }

    required init?(coder: NSCoder) { fatalError() }

    func toggle() {
        guard let win = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !win.isVisible { win.makeKeyAndOrderFront(nil) }
        win.toggleFullScreen(nil)
    }

    func hide() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().alphaValue = 0
        }, completionHandler: {
            if win.styleMask.contains(.fullScreen) {
                self.hideAfterExitingFullScreen = true
                win.toggleFullScreen(nil)
            } else {
                win.orderOut(nil)
                win.alphaValue = 1
            }
        })
    }

    func handleEscape() {
        let s = FullscreenState.shared
        if s.selectedCard != nil       { s.selectedCard        = nil;   return }
        if s.showingFolderPicker       { s.showingFolderPicker = false; return }
        if s.showingSearch             { s.showingSearch        = false; return }
        hide()
    }

    // MARK: NSWindowDelegate

    func windowDidEnterFullScreen(_ notification: Notification) {
        let s = FullscreenState.shared
        s.canvasCards.removeAll()
        s.selectedCard        = nil
        s.showingSearch       = false
        s.showingFolderPicker = false
        s.toastMessage        = nil
        NotificationCenter.default.post(name: .fullscreenWillShow, object: nil)
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.window?.isKeyWindow == true else { return event }
            switch event.keyCode {
            case 49 where !(self?.window?.firstResponder is NSTextView): // Space — toggle card search
                FullscreenState.shared.showingSearch.toggle()
                return nil
            case 53: // Escape — always handled by us, never propagated to macOS fullscreen exit
                self?.handleEscape()
                return nil
            default:
                return event
            }
        }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        if hideAfterExitingFullScreen {
            hideAfterExitingFullScreen = false
            window?.orderOut(nil)
            window?.alphaValue = 1
        }
    }
}
