import SwiftUI

// Warm palette
private extension Color {
    static let warmBg       = Color(red: 0.99, green: 0.97, blue: 0.93)
    static let warmInk      = Color(red: 0.18, green: 0.13, blue: 0.08)
    static let warmMid      = Color(red: 0.45, green: 0.36, blue: 0.24)
    static let warmFaint    = Color(red: 0.72, green: 0.65, blue: 0.54)
    static let warmDivider  = Color(red: 0.86, green: 0.80, blue: 0.70)
    static let warmPill     = Color(red: 0.88, green: 0.78, blue: 0.62)
}

struct CardDetailPopupView: View {
    let card: TarotCard
    let onClose: () -> Void

    @State private var isReversed = false
    @State private var appeared   = false

    private var content: CardContent { ContentStore.shared.content(for: card.id) }

    var body: some View {
        HStack(spacing: 0) {
            contentPanel
            Divider().background(Color.warmDivider)
            imagePanel
        }
        .background(Color.warmBg)
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
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.warmInk)
                            Text(card.displayNumber)
                                .font(.system(size: 14))
                                .foregroundColor(.warmFaint)
                        }
                        HStack(spacing: 6) {
                            pill(card.arcana.rawValue)
                            if card.suit != .none { pill(card.suit.rawValue) }
                            pill(card.element)
                            if isReversed {
                                pill("Reversed")
                                    .foregroundColor(Color(red: 0.75, green: 0.3, blue: 0.2))
                            }
                        }
                    }

                    Divider().background(Color.warmDivider)

                    // Meaning
                    meaningSection(
                        title: isReversed ? "Reversed" : "Upright",
                        icon:  isReversed ? "arrow.counterclockwise" : "sun.max",
                        text:  isReversed ? content.reversed : content.upright
                    )

                    if !content.personalNote.isEmpty {
                        Divider().background(Color.warmDivider)
                        meaningSection(title: "My Notes", icon: "moon.stars",
                                       text: content.personalNote)
                    }

                    Divider().background(Color.warmDivider)

                    // Keywords
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Keywords", icon: "tag")
                        FlowLayout(spacing: 6) {
                            ForEach(card.keywords, id: \.self) { kw in
                                Text(kw)
                                    .font(.system(size: 12))
                                    .foregroundColor(.warmMid)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.warmPill.opacity(0.45))
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
                        .fill(Color.warmFaint.opacity(0.35))
                        .frame(width: 24, height: 24)
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.warmMid)
                }
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .frame(width: 500)
    }

    // MARK: - Right: card image

    private var imagePanel: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.warmPill.opacity(0.25))
                    .frame(width: 160, height: 240)

                if let img = card.image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Text(card.suitSymbol).font(.system(size: 40))
                        Text(card.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.warmMid)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                }
            }
            .rotationEffect(.degrees(isReversed ? 180 : 0))
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: isReversed)
            .onTapGesture { isReversed.toggle() }
            .help(isReversed ? "Tap to restore upright" : "Tap to reverse")

            Button {
                withAnimation(.spring(response: 0.4)) { isReversed.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isReversed ? "arrow.up" : "arrow.down")
                    Text(isReversed ? "Reversed" : "Upright")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.warmMid)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.warmPill.opacity(0.35))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(Color(red: 0.97, green: 0.94, blue: 0.89))
    }

    // MARK: - Helpers

    private func meaningSection(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title, icon: icon)
            if text.isEmpty {
                Text("No interpretation written yet.\nOpen cards.json in the project folder to add one.")
                    .font(.system(size: 13))
                    .foregroundColor(.warmFaint)
                    .italic()
                    .lineSpacing(4)
            } else {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.warmInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.warmFaint)
            .textCase(.uppercase)
            .kerning(0.8)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.warmMid)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.warmPill.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
