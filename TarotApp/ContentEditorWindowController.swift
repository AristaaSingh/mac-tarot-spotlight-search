import AppKit
import SwiftUI

class EditorState: ObservableObject {
    @Published var text: String
    @Published var isClosing = false
    init(_ text: String) { self.text = text }
}

// Borderless window that can become key so the text view accepts input
private class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - NSViewRepresentable wrapping AppTextView

struct StyledTextEditor: NSViewRepresentable {
    @Binding var text: String
    var nsFont: NSFont
    var textColor: NSColor
    var cursorColor: NSColor
    var lineHeightMultiple: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // Explicit TextKit 1 stack so drawInsertionPoint override is actually called
        let textStorage   = NSTextStorage()
        let layoutMgr     = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutMgr.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutMgr)
        let textView = AppTextView(frame: NSRect.zero, textContainer: textContainer)
        textView.isEditable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.delegate = context.coordinator

        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineHeightMultiple
        textView.insertionPointColor = cursorColor
        textView.typingAttributes = [
            .font: nsFont,
            .foregroundColor: textColor,
            .paragraphStyle: style
        ]
        textView.string = text

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = textView
        textView.autoresizingMask = [.width]
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? AppTextView else { return }
        if textView.string != text {
            let full = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.textStorage?.replaceCharacters(in: full, with: text)
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: StyledTextEditor
        init(_ parent: StyledTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

// MARK: - Window controller

class ContentEditorWindowController: NSWindowController {

    static let windowW: CGFloat = 1024
    static let windowH: CGFloat = 600

    private let state: EditorState
    private let onSave: (String) -> Void
    private var eventMonitor: Any?

    init(cardName: String, section: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.state  = EditorState(initialText)
        self.onSave = onSave

        let win = KeyableWindow(
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

        let view = ContentEditorView(
            cardName: cardName,
            section: section,
            onSave: { [weak self] in self?.saveAndClose() },
            onCancel: { [weak self] in self?.animateClose() },
            state: state
        )
        let hosting = NSHostingView(rootView: view)
        win.contentView = hosting

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            win.setFrameOrigin(NSPoint(x: sf.midX - Self.windowW / 2,
                                       y: sf.midY - Self.windowH / 2))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func saveAndClose() {
        onSave(state.text)
        animateClose()
    }

    private func animateClose() {
        removeMonitor()
        state.isClosing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
            self?.window?.close()
        }
    }

    func show() {
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        window?.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 1 && event.modifierFlags.contains(.command) {
                self?.saveAndClose()
                return nil
            }
            return event
        }
    }

    private func removeMonitor() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }
}

// MARK: - Save button style

private struct SaveButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(13, weight: .bold))
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(
                configuration.isPressed ? Theme.ink.opacity(0.24) :
                isHovered               ? Theme.ink.opacity(0.14) :
                                          Theme.ink.opacity(0.08)
            )
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

// MARK: - SwiftUI view

private struct ContentEditorView: View {
    let cardName: String
    let section: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @ObservedObject var state: EditorState
    @State private var appeared = false


    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.bg

            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.faint)
                            .frame(width: 20, height: 20)
                            .background(Theme.ink.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cardName)
                            .font(.app(22, weight: .bold))
                            .foregroundColor(Theme.ink)
                        Text(section)
                            .font(.app(13))
                            .foregroundColor(Theme.mid)
                            .textCase(.uppercase)
                            .kerning(0.8)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                }

                // Editor
                StyledTextEditor(
                    text: $state.text,
                    nsFont: .didot(15),
                    textColor: Theme.nsInk,
                    cursorColor: Theme.nsInk,
                    lineHeightMultiple: 1.4
                )
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Footer
                HStack {
                    Spacer()
                    Button("Save", action: onSave)
                        .buttonStyle(SaveButtonStyle())
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
        .frame(width: ContentEditorWindowController.windowW,
               height: ContentEditorWindowController.windowH)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
        .onChange(of: state.isClosing) {
            if state.isClosing {
                withAnimation(.easeIn(duration: 0.18)) { appeared = false }
            }
        }
    }
}
