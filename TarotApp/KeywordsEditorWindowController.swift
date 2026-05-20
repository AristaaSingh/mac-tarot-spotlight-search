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
    private var eventMonitor: Any?
    private static let cursorColor = Theme.nsInk

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
        win.applyAppStyle()

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
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
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
        eventMonitor = addKeyMonitor { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.animateClose()
            return nil
        }
    }
}

// MARK: - Individual keyword pill

private struct KeywordPill: View {
    let text: String
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack {
            Text(text)
                .font(.app(12))
                .foregroundColor(Theme.ink)
                .opacity(isHovered ? 0 : 1)
            Image(systemName: "trash")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.ink.opacity(0.7))
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHovered ? Theme.ink.opacity(0.18) : Theme.ink.opacity(0.08))
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


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onClose) {
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
                        Text(subtitle)
                            .font(.app(13))
                            .foregroundColor(Theme.mid)
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
                        nsFont: .didot(14),
                        textColor: Theme.nsInk,
                        cursorColor: Theme.nsInk,
                        isFocused: fieldFocused,
                        onSubmit: { addKeyword() }
                    )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.ink.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button(action: addKeyword) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.ink)
                            .frame(width: 32, height: 32)
                            .background(Theme.ink.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, state.keywords.isEmpty ? 24 : 0)

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
