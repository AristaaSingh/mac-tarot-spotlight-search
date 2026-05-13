import SwiftUI

private struct Palette {
    // Upright: burgundy on light
    static let uprightInk      = Color(red: 0.278, green: 0, blue: 0.102)
    static let uprightMid      = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.65)
    static let uprightFaint    = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.38)
    static let uprightDivider  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.18)
    static let uprightAccentBg = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.10)
    static let uprightOverlay  = Color.white.opacity(0.40)

    // Reversed: white on dark
    static let reversedInk      = Color.white
    static let reversedMid      = Color.white.opacity(0.75)
    static let reversedFaint    = Color.white.opacity(0.45)
    static let reversedDivider  = Color.white.opacity(0.18)
    static let reversedAccentBg = Color.white.opacity(0.12)
    static let reversedOverlay  = Color.black.opacity(0.25)
}

struct CardDetailPopupView: View {
    let card: TarotCard
    let onClose: () -> Void

    @State private var isReversed = false
    @State private var appeared   = false

    private var content: CardContent { ContentStore.shared.content(for: card) }

    // Convenience: pick value based on reversed state
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
        }
        .animation(.easeInOut(duration: 0.35), value: isReversed)
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

                    Divider().background(p(Palette.uprightDivider, Palette.reversedDivider))

                    // Meaning
                    meaningSection(
                        title: isReversed ? "Reversed" : "Upright",
                        icon:  isReversed ? "arrow.counterclockwise" : "sun.max",
                        text:  isReversed ? content.reversed : content.upright
                    )

                    if !content.personalNote.isEmpty {
                        Divider().background(p(Palette.uprightDivider, Palette.reversedDivider))
                        meaningSection(title: "My Notes", icon: "moon.stars",
                                       text: content.personalNote)
                    }

                    Divider().background(p(Palette.uprightDivider, Palette.reversedDivider))

                    // Keywords
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Keywords", icon: "tag")
                        FlowLayout(spacing: 6) {
                            ForEach(card.keywords, id: \.self) { kw in
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

                    Spacer(minLength: 16)
                }
                .padding(28)
                .padding(.top, 12)
            }

            // Close button
            Button(action: onClose) {
                ZStack {
                    Circle()
                        .fill(p(Palette.uprightFaint, Palette.reversedFaint).opacity(0.4))
                        .frame(width: 24, height: 24)
                    Image(systemName: "xmark")
                        .font(.app(10, weight: .bold))
                        .foregroundColor(p(Palette.uprightMid, Palette.reversedMid))
                }
            }
            .buttonStyle(.plain)
            .padding(14)
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

    private func meaningSection(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title, icon: icon)
            if text.isEmpty {
                Text("Nothing written yet — open the card's .md file to add your interpretation.")
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
