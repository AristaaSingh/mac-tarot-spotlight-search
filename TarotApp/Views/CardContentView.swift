import SwiftUI

private struct Palette {
    // Upright: burgundy on light
    static let uprightInk      = Color(red: 0.278, green: 0, blue: 0.102)
    static let uprightMid      = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.65)
    static let uprightFaint    = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.38)
    static let uprightDivider  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.18)
    static let uprightAccentBg = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.10)
    static let uprightBtnHover   = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.18)
    static let uprightBtnPress   = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.28)
    static let uprightOverlay    = Color.white.opacity(0.40)

    // Reversed: white on dark
    static let reversedBtnHover  = Color.white.opacity(0.22)
    static let reversedBtnPress  = Color.white.opacity(0.32)
    static let reversedInk       = Color.white
    static let reversedMid      = Color.white.opacity(0.75)
    static let reversedFaint    = Color.white.opacity(0.45)
    static let reversedDivider  = Color.white.opacity(0.18)
    static let reversedAccentBg = Color.white.opacity(0.12)
    static let reversedOverlay  = Color.black.opacity(0.25)
}

private struct PencilButtonStyle: ButtonStyle {
    let base:    Color
    let hovered: Color
    let pressed: Color
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? pressed : (isHovered ? hovered : base))
            .clipShape(Circle())
            .animation(.easeOut(duration: 0.1), value: isHovered)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct CardDetailPopupView: View {
    let card: TarotCard
    let onClose: () -> Void
    let onEditorOpened: (ContentEditorWindowController) -> Void
    let onKeywordsEditorOpened: (KeywordsEditorWindowController) -> Void

    @State private var isReversed = false
    @State private var appeared   = false
    @State private var content    = CardContent(upright: "", reversed: "", personalNote: "", uprightKeywords: nil, reversedKeywords: nil)
    @State private var editorWindow: ContentEditorWindowController?

    private func p<T>(_ upright: T, _ reversed: T) -> T { isReversed ? reversed : upright }

    var body: some View {
        ZStack {
            Image(isReversed ? "content-window-bg-dark" : "content-window-bg")
                .resizable()
                .scaledToFill()
                .frame(width: CardPopupWindowController.windowWidth,
                       height: CardPopupWindowController.windowHeight)
                .clipped()
            p(Palette.uprightOverlay, Palette.reversedOverlay)

            HStack(spacing: 0) {
                contentPanel
                Divider().background(p(Palette.uprightDivider, Palette.reversedDivider))
                imagePanel
            }

            // Close button
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(p(Palette.uprightFaint, Palette.reversedFaint))
                            .frame(width: 22, height: 22)
                            .background(p(Palette.uprightAccentBg, Palette.reversedAccentBg))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                    Spacer()
                }
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isReversed)
        .onAppear { content = ContentStore.shared.content(for: card) }
        .onExitCommand { onClose() }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                appeared = true
            }
        }
    }

    // MARK: - Left: content

    private var contentPanel: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(card.name)
                                .font(.app(24, weight: .bold))
                                .foregroundColor(p(Palette.uprightInk, Palette.reversedInk))
                            Text(card.displayNumber)
                                .font(.app(14))
                                .foregroundColor(p(Palette.uprightInk, Palette.reversedInk))
                        }
                        HStack(spacing: 6) {
                            pill(card.arcana.rawValue)
                            if card.suit != .none { pill(card.suit.rawValue) }
                            pill(card.element)
                            if isReversed { pill("Reversed", highlighted: true) }
                        }
                    }

                    // Keywords
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            sectionLabel("Keywords", icon: "tag")
                            Button(action: openKeywordsEditor) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(p(Palette.uprightFaint, Palette.reversedFaint))
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(PencilButtonStyle(
                                base:    p(Palette.uprightAccentBg,  Palette.reversedAccentBg),
                                hovered: p(Palette.uprightBtnHover,  Palette.reversedBtnHover),
                                pressed: p(Palette.uprightBtnPress,  Palette.reversedBtnPress)
                            ))
                        }
                        let effectiveKeywords = isReversed
                            ? (content.reversedKeywords ?? card.keywords)
                            : (content.uprightKeywords  ?? card.keywords)
                        FlowLayout(spacing: 6) {
                            ForEach(effectiveKeywords, id: \.self) { kw in
                                Text(kw)
                                    .font(.app(12))
                                    .foregroundColor(p(Palette.uprightInk, Palette.reversedInk))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(p(Palette.uprightAccentBg, Palette.reversedAccentBg))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Divider().background(p(Palette.uprightDivider, Palette.reversedDivider))

                    // Meaning
                    meaningSection(
                        title: isReversed ? "Reversed" : "Upright",
                        icon:  isReversed ? "arrow.counterclockwise" : "sun.max",
                        text:  isReversed ? content.reversed : content.upright,
                        onEdit: { openEditor(section: isReversed ? "Reversed" : "Upright") }
                    )

                    if !content.personalNote.isEmpty {
                        Divider().background(p(Palette.uprightDivider, Palette.reversedDivider))
                        meaningSection(title: "My Notes", icon: "moon.stars",
                                       text: content.personalNote)
                    }

                    Spacer(minLength: 16)
                }
                .padding(28)
                .padding(.top, 12)
            }

        }
        .frame(width: CardPopupWindowController.leftPanelW)
    }

    // MARK: - Right: card image

    private var imagePanel: some View {
        let cw = CardPopupWindowController.cardDisplayW
        let ch = CardPopupWindowController.cardDisplayH

        return ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(p(Palette.uprightAccentBg, Palette.reversedAccentBg))

                if let img = card.image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Text(card.suitSymbol).font(.app(44))
                        Text(card.name)
                            .font(.app(11, weight: .bold))
                            .foregroundColor(p(Palette.uprightMid, Palette.reversedMid))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                }
            }
            .frame(width: cw, height: ch)
            .rotationEffect(.degrees(isReversed ? 180 : 0))
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: isReversed)
            .onTapGesture { isReversed.toggle() }
            .help(isReversed ? "Tap to restore upright" : "Tap to reverse")
        }
        .frame(width: CardPopupWindowController.rightPanelW,
               height: CardPopupWindowController.windowHeight)
    }

    // MARK: - Helpers

    private func openKeywordsEditor() {
        let initial = isReversed
            ? (content.reversedKeywords ?? card.keywords)
            : (content.uprightKeywords  ?? card.keywords)
        let subtitle = isReversed ? "Keywords · Reversed" : "Keywords · Upright"
        let editor = KeywordsEditorWindowController(cardName: card.name, subtitle: subtitle, initialKeywords: initial) { updated in
            var c = content
            if isReversed { c.reversedKeywords = updated }
            else          { c.uprightKeywords  = updated }
            ContentStore.shared.save(c, for: card)
            content = c
        }
        onKeywordsEditorOpened(editor)
        editor.show()
    }

    private func openEditor(section: String) {
        let initial = section == "Upright" ? content.upright : content.reversed
        let editor = ContentEditorWindowController(cardName: card.name, section: section, initialText: initial) { saved in
            var updated = content
            if section == "Upright" { updated.upright = saved }
            else                    { updated.reversed = saved }
            ContentStore.shared.save(updated, for: card)
            content = updated
        }
        editorWindow = editor
        onEditorOpened(editor)
        editor.show()
    }

    private func meaningSection(title: String, icon: String, text: String, onEdit: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                sectionLabel(title, icon: icon)
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(p(Palette.uprightFaint, Palette.reversedFaint))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(PencilButtonStyle(
                        base:    p(Palette.uprightAccentBg, Palette.reversedAccentBg),
                        hovered: p(Palette.uprightBtnHover, Palette.reversedBtnHover),
                        pressed: p(Palette.uprightBtnPress, Palette.reversedBtnPress)
                    ))
                }
            }
            if text.isEmpty && onEdit != nil {
                Text("Nothing written yet — click the pencil to add your interpretation.")
                    .font(.appItalic(13))
                    .foregroundColor(p(Palette.uprightFaint, Palette.reversedFaint))
                    .lineSpacing(4)
            } else {
                Text(text)
                    .font(.app(14))
                    .foregroundColor(p(Palette.uprightInk, Palette.reversedInk))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.app(11, weight: .semibold))
            .foregroundColor(p(Palette.uprightInk, Palette.reversedInk))
            .textCase(.uppercase)
            .kerning(0.8)
    }

    private func pill(_ text: String, highlighted: Bool = false) -> some View {
        Text(text)
            .font(.app(10, weight: .bold))
            .foregroundColor(highlighted ? p(Palette.uprightInk, Palette.reversedInk) : p(Palette.uprightMid, Palette.reversedMid))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(p(Palette.uprightAccentBg, Palette.reversedAccentBg))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
