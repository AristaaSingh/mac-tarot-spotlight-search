import SwiftUI

struct SearchOverlayView: View {
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var debounceTimer: Timer?
    @FocusState private var searchFocused: Bool

    var results: [TarotCard] {
        guard !debouncedQuery.isEmpty else { return [] }
        let q = debouncedQuery.lowercased().trimmingCharacters(in: .whitespaces)
        return allCards.filter { card in
            let nameLower = card.name.lowercased()
            let sig = nameLower.hasPrefix("the ") ? String(nameLower.dropFirst(4)) : nameLower
            return sig.contains(q)
                || nameLower.contains(q)
                || card.suit.rawValue.lowercased().hasPrefix(q)
                || card.keywords.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        ZStack {
            Image("cloud-night-overlay")
                .resizable()
                .scaledToFill()
                .frame(width: OverlayWindowController.panelWidth,
                       height: OverlayWindowController.panelHeight)
                .clipped()
            Color.black.opacity(0.5)

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
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.75, green: 0.6, blue: 1))

            TextField("Search cards…", text: $query)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.white)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { }
                .onKeyPress(.escape) { handleEscape(); return .handled }

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

    private func handleEscape() {
        OverlayWindowController.shared.hide()
    }
}
