import SwiftUI

struct CardDetailView: View {
    let card: TarotCard
    @State private var appeared = false
    @State private var isReversed = false

    var body: some View {
        ZStack {
            SparkleView()
                .opacity(0.7)

            HStack(alignment: .top, spacing: 28) {
                cardImagePanel
                    .offset(y: appeared ? 0 : 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05), value: appeared)

                contentPanel
                    .offset(x: appeared ? 0 : 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.15), value: appeared)
            }
            .padding(24)
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }

    // MARK: - Card image

    private var cardImagePanel: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 160, height: 280)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

                if let img = card.image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .rotationEffect(.degrees(isReversed ? 180 : 0))
                        .animation(.spring(response: 0.5), value: isReversed)
                } else {
                    VStack(spacing: 8) {
                        Text(card.suitSymbol)
                            .font(.app(48))
                        Text(card.name)
                            .font(.app(13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                }
            }

            // Reversed toggle
            Button {
                withAnimation(.spring(response: 0.4)) { isReversed.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isReversed ? "arrow.up" : "arrow.down")
                    Text(isReversed ? "Reversed" : "Upright")
                }
                .font(.app(11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Content panel

    private var contentPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(card.name)
                            .font(.app(24, weight: .bold))
                            .foregroundColor(.white)
                        Text(card.displayNumber)
                            .font(.app(14, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    HStack(spacing: 10) {
                        metaBadge(card.arcana.rawValue)
                        if card.suit != .none { metaBadge(card.suit.rawValue) }
                        metaBadge(card.element)
                    }
                }

                // Keywords
                FlowLayout(spacing: 6) {
                    ForEach(card.keywords, id: \.self) { kw in
                        Text(kw)
                            .font(.app(11))
                            .foregroundColor(Color(red: 0.85, green: 0.75, blue: 1))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.35))
                            .clipShape(Capsule())
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Meaning section
                meaningSection(
                    title: isReversed ? "Reversed" : "Upright",
                    icon: isReversed ? "arrow.counterclockwise" : "sun.max",
                    text: isReversed ? card.reversed : card.upright
                )

                if !card.personalNote.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    meaningSection(title: "My Notes", icon: "moon.stars", text: card.personalNote)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metaBadge(_ text: String) -> some View {
        Text(text)
            .font(.app(10, weight: .medium))
            .foregroundColor(.white.opacity(0.55))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func meaningSection(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.app(12, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .kerning(0.8)
            if text.isEmpty {
                Text("Your interpretation…")
                    .font(.app(13))
                    .foregroundColor(.white.opacity(0.2))
                    .italic()
            } else {
                Text(text)
                    .font(.app(13))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Simple flow layout for keyword pills

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0, +)
            + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let s = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += s.width + spacing
            }
            y += rowH + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if x + w > maxW, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(view)
            x += w + spacing
        }
        return rows
    }
}
