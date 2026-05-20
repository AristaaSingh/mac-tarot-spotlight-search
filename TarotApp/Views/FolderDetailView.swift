import SwiftUI

// MARK: - Folder detail (inside a folder)

struct FolderDetailView: View {
    let folder:  Folder
    let onBack:  () -> Void

    @StateObject private var store = ReadingStore.shared
    @State private var query          = ""
    @State private var searchFocused  = false

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    // Readings that belong to this folder
    var folderEntries: [ReadingEntry] {
        store.entries.filter { $0.folderID == folder.id }
    }

    // Filtered by the search query
    var filtered: [ReadingEntry] {
        guard !query.isEmpty else { return folderEntries }
        let q = query.lowercased()
        return folderEntries.filter { e in
            e.title.lowercased().contains(q) ||
            e.body.lowercased().contains(q)  ||
            e.cardEntries.contains { ce in
                ce.note.lowercased().contains(q) ||
                (allCards.first { $0.id == ce.cardID }?.name.lowercased().contains(q) ?? false)
            }
        }
    }

    var groupedEntries: [(month: String, entries: [ReadingEntry])] {
        var seen:  [String: [ReadingEntry]] = [:]
        var order: [String] = []
        for entry in filtered {
            let key = Self.monthFmt.string(from: entry.date)
            if seen[key] == nil { order.append(key); seen[key] = [] }
            seen[key]!.append(entry)
        }
        return order.map { (month: $0, entries: seen[$0]!) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                header
                Theme.divider.frame(height: 1)
                entryGrid
                Theme.divider.frame(height: 1)
                newReadingButton
            }

            // Close overlay button
            Button(action: close) {
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
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .frame(width: OverlayWindowController.journalW,
               height: OverlayWindowController.journalH)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { searchFocused = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)
            }
            .buttonStyle(.plain)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(Theme.faint)

            ThemedTextField(
                text: $query,
                placeholder: "Search in \(folder.name)…",
                nsFont: .didot(18),
                textColor: Theme.nsInk,
                cursorColor: Theme.nsInk,
                isFocused: searchFocused,
                onEscape: { query.isEmpty ? onBack() : (query = "") },
                onTab: { OverlayMode.shared.toggle() }
            )

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.faint.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 14)
    }

    // MARK: Entry grid

    private var entryGrid: some View {
        Group {
            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: query.isEmpty ? "book.closed" : "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.faint.opacity(0.5))
                    Text(query.isEmpty ? "No readings yet" : "No matches")
                        .font(.app(13))
                        .foregroundColor(Theme.faint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(groupedEntries, id: \.month) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    ReadingThumbnail(entry: entry)
                                        .onTapGesture {
                                            ReadingWindowManager.shared.open(entry: entry)
                                        }
                                }
                            } header: {
                                Text(group.month.uppercased())
                                    .font(.app(10, weight: .semibold))
                                    .foregroundColor(Theme.faint)
                                    .kerning(1.4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 6)
                                    .padding(.bottom, 2)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: New reading button

    private var newReadingButton: some View {
        Button { ReadingWindowManager.shared.openNew(in: folder.id) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("New Reading")
                    .font(.app(13, weight: .semibold))
            }
            .foregroundColor(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func close() { OverlayWindowController.shared.hide() }
}

// MARK: - Reading thumbnail card

struct ReadingThumbnail: View {
    let entry: ReadingEntry
    @State private var isHovered = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var cards: [TarotCard] {
        entry.allCardIDs.prefix(3).compactMap { id in allCards.first { $0.id == id } }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Card image area
            ZStack {
                Theme.ink.opacity(0.05)

                if cards.isEmpty {
                    Image(systemName: "book.closed")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.faint.opacity(0.5))
                } else {
                    let angles:  [Double]  = [-10, 0, 10]
                    let offsets: [CGFloat] = [-14, 0, 14]
                    ZStack {
                        ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                            let angle  = i < angles.count  ? angles[i]  : 0
                            let offset = i < offsets.count ? offsets[i] : 0
                            CardFace(card: card)
                                .frame(width: 62, height: 93)
                                .rotationEffect(.degrees(angle))
                                .offset(x: offset * 0.6, y: abs(offset) * 0.05)
                                .zIndex(i == 1 ? 2 : 1)
                        }
                    }
                }
            }
            .frame(height: 128)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))

            // Text area
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.app(12, weight: .semibold))
                    .foregroundColor(entry.title.isEmpty ? Theme.faint : Theme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(Self.dateFmt.string(from: entry.date))
                    .font(.app(10))
                    .foregroundColor(Theme.faint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bg)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.bg))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.ink.opacity(isHovered ? 0.18 : 0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0.04),
                radius: isHovered ? 10 : 4, y: 2)
        .scaleEffect(isHovered ? 1.025 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
}

// MARK: - Single card face (used in thumbnail fans)

struct CardFace: View {
    let card: TarotCard

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(Theme.ink.opacity(0.08))
            if let img = card.image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Text(card.suitSymbol)
                    .font(.app(18))
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}
