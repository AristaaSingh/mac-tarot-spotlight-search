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

// MARK: - Root view (switches between search / journal / card)

struct FullscreenRootView: View {
    @ObservedObject private var state = FullscreenState.shared

    var body: some View {
        ZStack {
            FloatingLinesView().ignoresSafeArea()
            Color.black.opacity(0.12)

            switch state.screen {
            case .search:
                FullscreenSearchContent()
            case .journal:
                FullscreenJournalContent()
            case .card(let card):
                FullscreenCardContent(card: card)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fullscreenWillShow)) { _ in
            state.screen = .search
        }
    }
}

// MARK: - Search content

struct FullscreenSearchContent: View {
    @State private var query          = ""
    @State private var debouncedQuery = ""
    @State private var debounceTimer: Timer?
    @State private var searchFocused  = false
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
            let name = card.name.lowercased()
            let sig  = name.hasPrefix("the ") ? String(name.dropFirst(4)) : name
            return sig.contains(q) || name.contains(q)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 7)

    var body: some View {
        ZStack {
            // Close button pinned to top-right
            VStack {
                HStack {
                    // Journal toggle
                    Button(action: { FullscreenWindowController.shared.navigate(to: .journal) }) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open Journal")
                    .padding(.leading, 22)
                    .padding(.top, 22)

                    Spacer()

                    Button(action: { FullscreenWindowController.shared.hide() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 22)
                    .padding(.top, 22)
                }
                Spacer()
            }

            // Search + results
            VStack(spacing: 36) {
                Color.clear.frame(height: 160)
                searchBar
                if !results.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(
                                Array(results.prefix(21).enumerated()),
                                id: \.element.id
                            ) { idx, card in
                                FullscreenCardTile(card: card, delay: Double(idx) * 0.03) {
                                    FullscreenWindowController.shared.navigate(to: .card(card))
                                }
                                .aspectRatio(2/3, contentMode: .fit)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 40)
                    }
                }
                Spacer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fullscreenWillShow)) { _ in
            query = ""; debouncedQuery = ""
            debounceTimer?.invalidate()
            searchFocused = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { searchFocused = true }
        }
        .onChange(of: query) {
            debounceTimer?.invalidate()
            guard !query.isEmpty else { debouncedQuery = ""; return }
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: false) { _ in
                DispatchQueue.main.async { debouncedQuery = query }
            }
        }
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
                        FullscreenWindowController.shared.navigate(to: .card(first))
                    }
                },
                onEscape: { FullscreenWindowController.shared.hide() }
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

// MARK: - Journal content

private struct FullscreenJournalContent: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            JournalView()
                .environment(\.journalIsFullscreen, true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Back to search
            Button(action: { FullscreenWindowController.shared.navigate(to: .search) }) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Search")
                        .font(.app(12))
                }
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }
}

// MARK: - Card content

private struct FullscreenCardContent: View {
    let card: TarotCard
    private let pad: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let availW = geo.size.width  - pad * 2
            let availH = geo.size.height - pad * 2
            let cH     = min(availH - 48, availW * 0.28 * 1.5)
            let cW     = cH * (2.0 / 3.0)
            let rW     = cW + 48
            let lW     = availW - rW

            ZStack {
                CardDetailPopupView(
                    card: card,
                    onClose: { FullscreenWindowController.shared.navigate(to: .search) },
                    onEditorOpened:         { editor in editor.window?.level = .screenSaver },
                    onKeywordsEditorOpened: { editor in editor.window?.level = .screenSaver },
                    backgroundBlur:         10,
                    backgroundCornerRadius: 20,
                    closeInset:             22,
                    windowW:                availW,
                    windowH:                availH,
                    leftW:                  lW,
                    rightW:                 rW,
                    cardW:                  cW,
                    cardH:                  cH,
                    fontBoost:              4
                )
                .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 20)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card tile

private struct FullscreenCardTile: View {
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
            .onHover   { isHovered = $0  }
    }
}
