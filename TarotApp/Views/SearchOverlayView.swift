import SwiftUI

struct SearchOverlayView: View {
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var debounceTimer: Timer?
    @State private var searchFocused = false
    private let nsWhite = NSColor.white

    private let digitWords: [(String, String)] = [
        ("10", "ten"), ("2", "two"), ("3", "three"), ("4", "four"), ("5", "five"),
        ("6", "six"), ("7", "seven"), ("8", "eight"), ("9", "nine")
    ]

    private func normalize(_ q: String) -> String {
        for (digit, word) in digitWords {
            if q == digit || q.hasPrefix(digit + " ") {
                return word + q.dropFirst(digit.count)
            }
        }
        return q
    }

    var results: [TarotCard] {
        guard !debouncedQuery.isEmpty else { return [] }
        let q = normalize(debouncedQuery.lowercased().trimmingCharacters(in: .whitespaces))
        return allCards.filter { card in
            let nameLower = card.name.lowercased()
            let sig = nameLower.hasPrefix("the ") ? String(nameLower.dropFirst(4)) : nameLower
            return sig.contains(q) || nameLower.contains(q)
        }
    }

    var body: some View {
        ZStack {
            AnimatedGIFView(filename: "dreamy-banner")
                .frame(width: OverlayWindowController.panelWidth,
                       height: OverlayWindowController.panelHeight)
                .clipped()
            Color.black.opacity(0.25)

            searchBar
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .onChange(of: query) {
            debounceTimer?.invalidate()
            if query.isEmpty {
                debouncedQuery = ""
            } else {
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: false) { _ in
                    DispatchQueue.main.async { debouncedQuery = query }
                }
            }
        }
        .onChange(of: debouncedQuery) {
            if debouncedQuery.isEmpty {
                ThumbnailWindowManager.shared.clear()
            } else {
                ThumbnailWindowManager.shared.show(cards: results)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.app(16))
                .foregroundColor(.white)

            ThemedTextField(
                text: $query,
                placeholder: "Search cards…",
                nsFont: NSFont(name: "Didot", size: 18) ?? .systemFont(ofSize: 18),
                textColor: nsWhite,
                cursorColor: nsWhite,
                isFocused: searchFocused,
                onSubmit: { if let first = results.first { openCard(first) } },
                onEscape: { handleEscape() }
            )

            if !query.isEmpty {
                Button { query = ""; debouncedQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: OverlayWindowController.panelHeight)
    }

    private func openCard(_ card: TarotCard) {
        OverlayWindowController.shared.hide()
        CardPopupManager.shared.open(card: card)
    }

    private func handleEscape() {
        OverlayWindowController.shared.hide()
    }
}
