import SwiftUI

// Clips to a rounded rect whose HEIGHT animates — top corners never move.
private struct RevealClip: Shape {
    var height: CGFloat
    var radius: CGFloat = 24

    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: radius)
            .path(in: CGRect(x: rect.minX, y: rect.minY,
                             width: rect.width, height: height))
    }
}

struct SearchOverlayView: View {
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var debounceTimer: Timer?
    @State private var selectedIndex = 0
    @State private var clipHeight: CGFloat = searchBarH
    @FocusState private var searchFocused: Bool

    private static let searchBarH: CGFloat = 72
    private static let rowH:       CGFloat = 74
    private static let maxRows:    Int     = 5

    var results: [TarotCard] {
        guard !debouncedQuery.isEmpty else { return [] }
        let q = debouncedQuery.lowercased()
        return allCards.filter {
            $0.name.lowercased().contains(q)
            || $0.suit.rawValue.lowercased().contains(q)
            || $0.keywords.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var targetHeight: CGFloat {
        if results.isEmpty { return Self.searchBarH }
        let rows = min(results.count, Self.maxRows)
        return Self.searchBarH + CGFloat(rows) * Self.rowH
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundImage

            VStack(spacing: 0) {
                searchBar
                if !results.isEmpty {
                    Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)
                    resultsList
                } else if !debouncedQuery.isEmpty {
                    emptyState
                } else {
                    idleHint
                }
            }
        }
        .clipShape(RevealClip(height: clipHeight))
        .overlay(RevealClip(height: clipHeight).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .frame(width: OverlayWindowController.panelWidth,
               height: OverlayWindowController.panelHeight,
               alignment: .top)
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
        .onChange(of: targetHeight) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                clipHeight = targetHeight
            }
        }
        .onChange(of: results.count) { selectedIndex = 0 }
        .onAppear {
            clipHeight = Self.searchBarH
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
    }

    // MARK: - Background

    private var backgroundImage: some View {
        ZStack {
            Image("cloud-night-overlay")
                .resizable()
                .scaledToFill()
                .frame(width: OverlayWindowController.panelWidth,
                       height: OverlayWindowController.panelHeight,
                       alignment: .top)
                .clipped()
            // Dark scrim so text stays readable over any background image
            Color.black.opacity(0.45)
        }
        .frame(width: OverlayWindowController.panelWidth,
               height: OverlayWindowController.panelHeight)
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
                .onSubmit { selectCurrent() }
                .onKeyPress(.upArrow)   { moveSelection(by: -1); return .handled }
                .onKeyPress(.downArrow) { moveSelection(by: 1);  return .handled }
                .onKeyPress(.escape)    { handleEscape();         return .handled }

            if !query.isEmpty {
                Button { query = ""; debouncedQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: Self.searchBarH)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { i, card in
                        SearchResultRow(card: card, isSelected: i == selectedIndex)
                            .id(i)
                            .onTapGesture { openCard(card) }
                            .onHover { if $0 { selectedIndex = i } }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(height: CGFloat(min(results.count, Self.maxRows)) * Self.rowH)
            .scrollIndicators(.never)
            .onChange(of: selectedIndex) {
                withAnimation { proxy.scrollTo(selectedIndex, anchor: .center) }
            }
        }
    }

    private var emptyState: some View {
        Text("No cards found for \"\(debouncedQuery)\"")
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.35))
            .padding(24)
    }

    private var idleHint: some View {
        HStack(spacing: 16) {
            hintChip("↩ open")
            hintChip("↑↓ navigate")
            hintChip("⎋ close")
        }
        .padding(.vertical, 14)
    }

    private func hintChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Actions

    private func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + results.count) % results.count
    }

    private func selectCurrent() {
        guard selectedIndex < results.count else { return }
        openCard(results[selectedIndex])
    }

    private func openCard(_ card: TarotCard) {
        CardPopupManager.shared.open(card: card)
        OverlayWindowController.shared.hide()
    }

    private func handleEscape() {
        OverlayWindowController.shared.hide()
    }
}
