import SwiftUI
import WebKit

// MARK: - WebGL background

private struct FloatingLinesView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.wantsLayer = true
        if let url = Bundle.main.url(forResource: "floating-lines", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Root

struct FullscreenRootView: View {
    @ObservedObject private var state = FullscreenState.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FloatingLinesView().ignoresSafeArea()
                Color.black.opacity(0.15).ignoresSafeArea()

                // Canvas
                CanvasView(size: geo.size)

                // Empty-state hint
                if state.canvasCards.isEmpty && !state.showingSearch && state.selectedCard == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundColor(.white.opacity(0.18))
                        Text("Press F4 to add cards")
                            .font(.app(15))
                            .foregroundColor(.white.opacity(0.22))
                    }
                }

                // Add-to-journal bar
                if !state.canvasCards.isEmpty && state.selectedCard == nil && !state.showingSearch {
                    VStack {
                        Spacer()
                        AddToJournalBar()
                            .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Search overlay (F4)
                if state.showingSearch {
                    FullscreenSearchOverlay(canvasSize: geo.size)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                }

                // Card detail overlay
                if let card = state.selectedCard {
                    FullscreenCardDetailOverlay(card: card, canvasSize: geo.size)
                        .transition(.opacity)
                }

                // Toast
                if let msg = state.toastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.app(14))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 84)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: state.showingSearch)
            .animation(.easeInOut(duration: 0.22), value: state.selectedCard?.id)
            .animation(.easeInOut(duration: 0.3),  value: state.toastMessage)
            .animation(.easeInOut(duration: 0.25), value: state.canvasCards.isEmpty)
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .fullscreenWillShow)) { _ in
            // Open search immediately when fullscreen first appears
            FullscreenState.shared.showingSearch  = true
            FullscreenState.shared.selectedCard   = nil
        }
    }
}

// MARK: - Canvas

private struct CanvasView: View {
    let size: CGSize
    @ObservedObject private var state = FullscreenState.shared

    var body: some View {
        ZStack {
            ForEach(state.canvasCards) { placed in
                CanvasCardView(placed: placed)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Canvas card

private let canvasCardW: CGFloat = 92
private let canvasCardH: CGFloat = 138

private struct CanvasCardView: View {
    let placed: PlacedCard
    @State private var dragOffset: CGSize = .zero
    @State private var isHovered = false

    var body: some View {
        CardThumbnailView(card: placed.card)
            .frame(width: canvasCardW, height: canvasCardH)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .rotationEffect(.degrees(placed.rotation))
            .shadow(color: .black.opacity(isHovered ? 0.65 : 0.4),
                    radius: isHovered ? 28 : 14, x: 0, y: isHovered ? 14 : 7)
            .scaleEffect(isHovered ? 1.07 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in dragOffset = v.translation }
                    .onEnded { v in
                        let dist = hypot(v.translation.width, v.translation.height)
                        if dist < 6 {
                            // Treat tiny move as a tap → open detail
                            FullscreenState.shared.selectedCard = placed.card
                        } else {
                            FullscreenState.shared.updatePosition(
                                id: placed.id,
                                to: CGPoint(x: placed.position.x + v.translation.width,
                                            y: placed.position.y + v.translation.height)
                            )
                        }
                        dragOffset = .zero
                    }
            )
            .position(x: placed.position.x + dragOffset.width,
                      y: placed.position.y + dragOffset.height)
    }
}

// MARK: - Add to journal bar

private struct AddToJournalBar: View {
    @ObservedObject private var state = FullscreenState.shared

    var body: some View {
        Button(action: { state.addSpreadToJournal() }) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 13, weight: .medium))
                Text("Add spread to journal")
                    .font(.app(14))
            }
            .foregroundColor(.white.opacity(0.88))
            .padding(.horizontal, 26)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search overlay

private struct FullscreenSearchOverlay: View {
    let canvasSize: CGSize
    @State private var query          = ""
    @State private var debouncedQuery = ""
    @State private var debounceTimer: Timer?
    @State private var searchFocused  = false
    private let nsWhite = NSColor.white

    private let digitWords: [(String, String)] = [
        ("10","ten"),("2","two"),("3","three"),("4","four"),("5","five"),
        ("6","six"),("7","seven"),("8","eight"),("9","nine")
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
            let name = card.name.lowercased()
            let sig  = name.hasPrefix("the ") ? String(name.dropFirst(4)) : name
            return sig.contains(q) || name.contains(q)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 7)
    private let state   = FullscreenState.shared

    var body: some View {
        ZStack {
            // Tappable backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 32) {
                Color.clear.frame(height: 120)

                searchBar

                if !results.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(
                                Array(results.prefix(21).enumerated()),
                                id: \.element.id
                            ) { idx, card in
                                FullscreenCardTile(card: card, delay: Double(idx) * 0.03) {
                                    state.addCard(card, canvasSize: canvasSize)
                                    dismiss()
                                }
                                .aspectRatio(2/3, contentMode: .fit)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 40)
                    }
                } else if debouncedQuery.isEmpty {
                    Text("F4 to dismiss  ·  click a card to place it on the canvas")
                        .font(.app(13))
                        .foregroundColor(.white.opacity(0.3))
                }

                Spacer()
            }
        }
        .onAppear {
            query = ""; debouncedQuery = ""
            debounceTimer?.invalidate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { searchFocused = true }
        }
        .onChange(of: query) {
            debounceTimer?.invalidate()
            guard !query.isEmpty else { debouncedQuery = ""; return }
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                DispatchQueue.main.async { debouncedQuery = query }
            }
        }
    }

    private func dismiss() {
        query = ""; debouncedQuery = ""
        FullscreenState.shared.showingSearch = false
    }

    private var searchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.app(18))
                .foregroundColor(.white.opacity(0.75))

            ThemedTextField(
                text: $query,
                placeholder: "Search cards…",
                nsFont: .didot(22),
                textColor: nsWhite,
                cursorColor: nsWhite,
                isFocused: searchFocused,
                onSubmit: {
                    if let first = results.first {
                        state.addCard(first, canvasSize: canvasSize)
                        dismiss()
                    }
                },
                onEscape: { dismiss() }
            )

            if !query.isEmpty {
                Button { query = ""; debouncedQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .frame(width: 580, height: 68)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Card detail overlay

private struct FullscreenCardDetailOverlay: View {
    let card: TarotCard
    let canvasSize: CGSize

    var body: some View {
        let pad:   CGFloat = 60
        let availW         = canvasSize.width  - pad * 2
        let availH         = canvasSize.height - pad * 2
        let cH             = min(availH - 48, availW * 0.28 * 1.5)
        let cW             = cH * (2.0 / 3.0)
        let rW             = cW + 48
        let lW             = availW - rW

        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { FullscreenState.shared.selectedCard = nil }

            CardDetailPopupView(
                card: card,
                onClose: { FullscreenState.shared.selectedCard = nil },
                onEditorOpened:         { $0.window?.level = .screenSaver },
                onKeywordsEditorOpened: { $0.window?.level = .screenSaver },
                backgroundBlur:         10,
                backgroundCornerRadius: 20,
                closeInset:             22,
                windowW: availW, windowH: availH,
                leftW:   lW,     rightW:  rW,
                cardW:   cW,     cardH:   cH,
                fontBoost: 4
            )
            .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 20)
            .frame(width: availW, height: availH)
        }
    }
}

// MARK: - Card tile (shared)

struct FullscreenCardTile: View {
    let card:  TarotCard
    let delay: Double
    let onTap: () -> Void
    @State private var appeared  = false
    @State private var isHovered = false

    var body: some View {
        CardThumbnailView(card: card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(appeared ? (isHovered ? 1.06 : 1.0) : 0.82)
            .opacity(appeared ? 1 : 0)
            .shadow(color: .black.opacity(isHovered ? 0.45 : 0), radius: 18, x: 0, y: 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.72).delay(delay), value: appeared)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onAppear  { appeared  = true }
            .onTapGesture { onTap() }
            .onHover   { isHovered = $0 }
    }
}
