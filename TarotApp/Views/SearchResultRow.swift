import SwiftUI

struct SearchResultRow: View {
    let card: TarotCard
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Card thumbnail or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 54)
                if let img = card.image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text(card.suitSymbol)
                        .font(.app(18))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(card.name)
                    .font(.app(14, weight: .medium))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text(card.arcana.rawValue)
                        .font(.app(11))
                        .foregroundColor(.white.opacity(0.5))
                    if card.suit != .none {
                        Text("·")
                            .foregroundColor(.white.opacity(0.3))
                        Text(card.suit.rawValue)
                            .font(.app(11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                // First two keywords as pills
                HStack(spacing: 4) {
                    ForEach(card.keywords.prefix(2), id: \.self) { kw in
                        Text(kw)
                            .font(.app(10))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.app(11, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
        )
        .padding(.horizontal, 8)
    }
}
