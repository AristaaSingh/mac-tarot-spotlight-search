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
                        Text("Press Space to add cards")
                            .font(.app(15))
                            .foregroundColor(.white.opacity(0.22))
                    }
                }

                // Add-to-journal bar
                if !state.canvasCards.isEmpty && state.selectedCard == nil
                    && !state.showingSearch && !state.showingFolderPicker {
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

                // Folder picker overlay
                if state.showingFolderPicker {
                    SpreadFolderPickerOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
            .animation(.easeInOut(duration: 0.22), value: state.showingFolderPicker)
            .animation(.easeInOut(duration: 0.3),  value: state.toastMessage)
            .animation(.easeInOut(duration: 0.25), value: state.canvasCards.isEmpty)
        }
        .ignoresSafeArea()
        .onExitCommand { FullscreenWindowController.shared.handleEscape() }
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
        Button(action: { state.requestJournalFolder() }) {
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
                    Text("Space to dismiss  ·  click a card to place it on the canvas")
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

// MARK: - Folder picker overlay

private struct SpreadFolderPickerOverlay: View {
    @ObservedObject private var folderStore = FolderStore.shared
    @ObservedObject private var state       = FullscreenState.shared

    @State private var isCreating         = false
    @State private var newFolderName      = ""
    @State private var createFieldFocused = false

    private let w: CGFloat = 540
    private let h: CGFloat = 520
    private let columns    = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var entriesByFolder: [String: [ReadingEntry]] {
        Dictionary(grouping: ReadingStore.shared.entries, by: \.folderID)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                header
                Theme.divider.frame(height: 1)
                folderGrid
                Theme.divider.frame(height: 1)
                bottomBar
            }
            .frame(width: w, height: h)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.35), radius: 40, x: 0, y: 16)
            // X close button
            .overlay(alignment: .topLeading) {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.faint)
                        .frame(width: 22, height: 22)
                        .background(Theme.subtle)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(14)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Add to Journal")
                .font(.app(16, weight: .semibold))
                .foregroundColor(Theme.ink)

            // Mini card preview row
            let cards = state.canvasCards.prefix(5)
            if !cards.isEmpty {
                HStack(spacing: -10) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { idx, placed in
                        CardThumbnailView(card: placed.card)
                            .frame(width: 28, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .rotationEffect(.degrees(Double(idx - 2) * 3))
                            .zIndex(Double(idx))
                    }
                }
                .padding(.top, 2)

                let extra = state.canvasCards.count - 5
                if extra > 0 {
                    Text("+ \(extra) more")
                        .font(.app(11))
                        .foregroundColor(Theme.faint)
                }
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 14)
        .padding(.horizontal, 20)
    }

    // MARK: Folder grid

    private var folderGrid: some View {
        Group {
            if folderStore.folders.isEmpty && !isCreating {
                VStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.faint.opacity(0.5))
                    Text("No folders yet — create one below")
                        .font(.app(13))
                        .foregroundColor(Theme.faint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(folderStore.folders.enumerated()), id: \.element.id) { idx, folder in
                            PickerFolderTile(
                                folder:    folder,
                                entries:   entriesByFolder[folder.id] ?? [],
                                iconIndex: idx % PickerFolderTile.icons.count
                            ) {
                                state.saveSpread(toFolder: folder)
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        Group {
            if isCreating {
                HStack(spacing: 10) {
                    ThemedTextField(
                        text: $newFolderName,
                        placeholder: "Folder name…",
                        nsFont: .didot(15),
                        textColor: Theme.nsInk,
                        cursorColor: Theme.nsInk,
                        isFocused: createFieldFocused,
                        onSubmit: { commitCreate() },
                        onEscape: { cancelCreate() }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.ink.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Create", action: commitCreate)
                        .font(.app(13, weight: .semibold))
                        .foregroundColor(Theme.ink)
                        .buttonStyle(.plain)

                    Button(action: cancelCreate) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.faint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            } else {
                BottomBarButton(icon: "folder.badge.plus", label: "New Folder") {
                    isCreating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { createFieldFocused = true }
                }
            }
        }
    }

    // MARK: Helpers

    private func commitCreate() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelCreate(); return }
        let folder = FolderStore.shared.create(name: name)
        newFolderName = ""; isCreating = false; createFieldFocused = false
        state.saveSpread(toFolder: folder)
    }

    private func cancelCreate() {
        newFolderName = ""; isCreating = false; createFieldFocused = false
    }

    private func dismiss() {
        state.showingFolderPicker = false
    }
}

// MARK: - Picker folder tile

private struct PickerFolderTile: View {
    let folder:    Folder
    let entries:   [ReadingEntry]
    let iconIndex: Int
    let onTap:     () -> Void

    @State private var isHovered = false

    static let icons = ["Lanterns", "Cherry", "Herons", "Waves", "Peaches", "Purple"]

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(Self.icons[iconIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .scaleEffect(isHovered ? 1.07 : 1)
                    .animation(.easeOut(duration: 0.15), value: isHovered)

                Text(folder.name)
                    .font(.app(12, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("\(entries.count) reading\(entries.count == 1 ? "" : "s")")
                    .font(.app(10))
                    .foregroundColor(Theme.faint)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
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
