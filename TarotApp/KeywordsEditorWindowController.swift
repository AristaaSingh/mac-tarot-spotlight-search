import AppKit
import SwiftUI

class KeywordsState: ObservableObject {
    @Published var keywords: [String]
    @Published var isClosing = false
    init(_ keywords: [String]) { self.keywords = keywords }
}

class KeywordsEditorWindowController: NSWindowController {

    static let windowW: CGFloat = 480
    static let windowH: CGFloat = 420

    private let state: KeywordsState

    init(cardName: String, initialKeywords: [String], onChanged: @escaping ([String]) -> Void) {
        self.state = KeywordsState(initialKeywords)

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

        let view = KeywordsEditorView(
            cardName: cardName,
            onChanged: onChanged,
            onClose: { [weak self] in self?.animateClose() },
            state: state
        )
        win.contentView = NSHostingView(rootView: view)

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            win.setFrameOrigin(NSPoint(x: sf.midX - Self.windowW / 2,
                                       y: sf.midY - Self.windowH / 2))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func animateClose() {
        state.isClosing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
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
    }
}

// Needed for borderless window to accept key input
private class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - Individual keyword pill

private struct KeywordPill: View {
    let text: String
    let onDelete: () -> Void

    @State private var isHovered = false

    private let ink      = Color(red: 0.278, green: 0, blue: 0.102)
    private let base     = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.08)
    private let hovered  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.18)

    var body: some View {
        ZStack {
            Text(text)
                .font(.app(12))
                .foregroundColor(ink)
                .opacity(isHovered ? 0 : 1)
            Image(systemName: "trash")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(ink.opacity(0.7))
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHovered ? hovered : base)
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture { onDelete() }
    }
}

// MARK: - Editor view

private struct KeywordsEditorView: View {
    let cardName: String
    let onChanged: ([String]) -> Void
    let onClose: () -> Void

    @ObservedObject var state: KeywordsState
    @State private var newKeyword = ""
    @State private var appeared   = false
    @FocusState private var fieldFocused: Bool

    private let ink      = Color(red: 0.278, green: 0, blue: 0.102)
    private let mid      = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.50)
    private let faint    = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.30)
    private let bg       = Color(red: 0.98, green: 0.96, blue: 0.94)
    private let accentBg = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.08)
    private let fieldBg  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.05)

    var body: some View {
        ZStack(alignment: .topLeading) {
            bg

            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(faint)
                            .frame(width: 20, height: 20)
                            .background(accentBg)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cardName)
                            .font(.app(22, weight: .bold))
                            .foregroundColor(ink)
                        Text("Keywords")
                            .font(.app(13))
                            .foregroundColor(mid)
                            .textCase(.uppercase)
                            .kerning(0.8)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                }

                // Add keyword field
                HStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        if newKeyword.isEmpty {
                            Text("Add a keyword…")
                                .font(.app(14))
                                .foregroundColor(ink.opacity(0.45))
                        }
                        TextField("", text: $newKeyword)
                            .textFieldStyle(.plain)
                            .font(.app(14))
                            .foregroundColor(ink)
                            .focused($fieldFocused)
                            .onSubmit { addKeyword() }
                    }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(fieldBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button(action: addKeyword) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ink)
                            .frame(width: 32, height: 32)
                            .background(accentBg)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)

                // Keywords pills
                ScrollView(.vertical, showsIndicators: false) {
                    FlowLayout(spacing: 8) {
                        ForEach(state.keywords, id: \.self) { kw in
                            KeywordPill(text: kw) {
                                state.keywords.removeAll { $0 == kw }
                                onChanged(state.keywords)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
        .frame(width: KeywordsEditorWindowController.windowW,
               height: KeywordsEditorWindowController.windowH)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fieldFocused = true }
        }
        .onChange(of: state.isClosing) {
            if state.isClosing { withAnimation(.easeIn(duration: 0.18)) { appeared = false } }
        }
    }

    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !state.keywords.contains(trimmed) else { return }
        state.keywords.append(trimmed)
        onChanged(state.keywords)
        newKeyword = ""
    }
}
