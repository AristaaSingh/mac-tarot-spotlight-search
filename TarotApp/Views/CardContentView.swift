import SwiftUI

struct CardContentView: View {
    let card: TarotCard
    let isReversed: Bool

    private var content: CardContent { ContentStore.shared.content(for: card.id) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider().background(Color.white.opacity(0.12))
                meaningSection(
                    title: isReversed ? "Reversed" : "Upright",
                    icon:  isReversed ? "arrow.counterclockwise" : "sun.max.fill",
                    text:  isReversed ? content.reversed : content.upright
                )
                if !content.personalNote.isEmpty {
                    Divider().background(Color.white.opacity(0.12))
                    meaningSection(title: "My Notes", icon: "moon.stars.fill",
                                   text: content.personalNote)
                }
                Divider().background(Color.white.opacity(0.12))
                keywordsSection
                metaSection
                Spacer(minLength: 16)
            }
            .padding(24)
        }
        .background(Color(red: 0.07, green: 0.05, blue: 0.13))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(card.displayNumber)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
            }
            HStack(spacing: 8) {
                badge(card.arcana.rawValue)
                if card.suit != .none { badge(card.suit.rawValue) }
                badge(card.element)
                if isReversed {
                    badge("Reversed")
                        .foregroundColor(Color(red: 1, green: 0.6, blue: 0.5))
                }
            }
        }
    }

    // MARK: - Meaning

    private func meaningSection(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .textCase(.uppercase)
                .kerning(0.8)
            if text.isEmpty {
                Text("No interpretation written yet.\nOpen ~/Documents/TarotApp/cards.json to add one.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.25))
                    .italic()
                    .lineSpacing(4)
            } else {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.88))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Keywords

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keywords")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .textCase(.uppercase)
                .kerning(0.8)
            FlowLayout(spacing: 6) {
                ForEach(card.keywords, id: \.self) { kw in
                    Text(kw)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 1))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.3))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Meta

    private var metaSection: some View {
        HStack(spacing: 10) {
            badge("Element: \(card.element)")
            if card.suit != .none { badge(card.suitSymbol + " " + card.suit.rawValue) }
        }
        .padding(.top, 2)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
