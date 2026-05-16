import AppKit
import SwiftUI

class EditorState: ObservableObject {
    @Published var text: String
    init(_ text: String) { self.text = text }
}

class ContentEditorWindowController: NSWindowController {

    static let windowW: CGFloat = 1024
    static let windowH: CGFloat = 500

    private let state: EditorState
    private let onSave: (String) -> Void

    init(cardName: String, section: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.state  = EditorState(initialText)
        self.onSave = onSave

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowW, height: Self.windowH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isMovableByWindowBackground = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces]

        super.init(window: win)

        let view = ContentEditorView(cardName: cardName, section: section,
                                     onCancel: { [weak win] in win?.close() }, state: state)
        let hosting = NSHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 16
        hosting.layer?.masksToBounds = true
        win.contentView = hosting

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            win.setFrameOrigin(NSPoint(x: sf.midX - Self.windowW / 2,
                                       y: sf.midY - Self.windowH / 2))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Save current text and close. Called by the card window on escape or when it closes.
    func saveAndClose() {
        onSave(state.text)
        window?.close()
    }

    func show() {
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
    }
}

private struct ContentEditorView: View {
    let cardName: String
    let section: String
    let onCancel: () -> Void

    @ObservedObject var state: EditorState
    @FocusState private var editorFocused: Bool

    private let ink   = Color(red: 0.278, green: 0, blue: 0.102)
    private let mid   = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.50)
    private let faint = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.30)
    private let bg    = Color(red: 0.98, green: 0.96, blue: 0.94)

    var body: some View {
        ZStack(alignment: .topLeading) {
            bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(faint)
                            .frame(width: 20, height: 20)
                            .background(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cardName)
                            .font(.app(22, weight: .bold))
                            .foregroundColor(ink)
                        Text(section)
                            .font(.app(13))
                            .foregroundColor(mid)
                            .textCase(.uppercase)
                            .kerning(0.8)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                }

                // Editor — Save button lives in card window controller (escape / X close)
                TextEditor(text: $state.text)
                    .font(.app(15))
                    .foregroundColor(ink)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($editorFocused)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: ContentEditorWindowController.windowW,
               height: ContentEditorWindowController.windowH)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { editorFocused = true }
        }
    }
}
