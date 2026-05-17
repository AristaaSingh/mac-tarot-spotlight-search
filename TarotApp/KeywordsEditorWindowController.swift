import AppKit
import SwiftUI

class KeywordsState: ObservableObject {
    @Published var keywords: [String]
    @Published var isClosing = false
    init(_ keywords: [String]) { self.keywords = keywords }
}

class KeywordsEditorWindowController: NSWindowController, NSWindowDelegate {

    private var fieldEditor: AppTextView?
    private weak var hosting: NSView?
    private static let cursorColor = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)

    static let windowW: CGFloat = 360
    static let minH:    CGFloat = 200
    static let maxH:    CGFloat = 520

    private let state: KeywordsState

    init(cardName: String, subtitle: String, initialKeywords: [String], onChanged: @escaping ([String]) -> Void) {
        self.state = KeywordsState(initialKeywords)

        let win = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowW, height: Self.minH),
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
        win.delegate = self

        let view = KeywordsEditorView(
            cardName: cardName,
            subtitle: subtitle,
            onChanged: { [weak self] kws in
                onChanged(kws)
                DispatchQueue.main.async { self?.resize(animated: true) }
            },
            onClose: { [weak self] in self?.animateClose() },
            state: state
        )
        let h = NSHostingView(rootView: view)
        h.wantsLayer = true
        h.layer?.cornerRadius = 24
        h.layer?.masksToBounds = true
        hosting = h
        win.contentView = h
    }

    required init?(coder: NSCoder) { fatalError() }

    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        if fieldEditor == nil {
            let tv = AppTextView()
            tv.isFieldEditor = true
            tv.insertionPointColor = Self.cursorColor
            fieldEditor = tv
        }
        return fieldEditor
    }

    private func resize(animated: Bool) {
        guard let win = window, let h = hosting else { return }
        h.layout()
        let newH = max(Self.minH, min(Self.maxH, h.fittingSize.height))
        var frame = win.frame
        frame.origin.y = frame.maxY - newH
        frame.size.height = newH
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                win.animator().setFrame(frame, display: true)
            }
        } else {
            win.setFrame(frame, display: false)
        }
    }

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
        // Size to content first (invisible), then center, then fade in
        resize(animated: false)
        if let screen = NSScreen.main, let win = window {
            let sf = screen.visibleFrame
            win.setFrameOrigin(NSPoint(x: sf.midX - Self.windowW / 2,
                                       y: sf.midY - win.frame.height / 2))
        }
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
    let subtitle: String
    let onChanged: ([String]) -> Void
    let onClose: () -> Void

    @ObservedObject var state: KeywordsState
    @State private var newKeyword   = ""
    @State private var appeared     = false
    @State private var fieldFocused = false

    private let nsInk = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)

    private let ink      = Color(red: 0.278, green: 0, blue: 0.102)
    private let mid      = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.50)
    private let faint    = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.30)
    private let bg       = Color(red: 0.98, green: 0.96, blue: 0.94)
    private let accentBg = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.08)
    private let fieldBg  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.05)

    var body: some View {
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
                        Text(subtitle)
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
                    ThemedTextField(
                        text: $newKeyword,
                        placeholder: "Add a keyword…",
                        nsFont: NSFont(name: "Didot", size: 14) ?? .systemFont(ofSize: 14),
                        textColor: nsInk,
                        cursorColor: nsInk,
                        isFocused: fieldFocused,
                        onSubmit: { addKeyword() }
                    )
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
                if !state.keywords.isEmpty {
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
        }
        .background(
            AnimatedGIFView(filename: "keyword-window-bg")
                .blur(radius: 4, opaque: true)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .opacity(appeared ? 1 : 0)
        .frame(width: KeywordsEditorWindowController.windowW)
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
