import SwiftUI

struct JournalView: View {
    @StateObject private var store = ReadingStore.shared
    @State private var query       = ""
    @State private var appeared    = false

    private let bg           = Color(red: 0.98, green: 0.96, blue: 0.94)
    private let ink          = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint        = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.35)
    private let subtle       = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.07)
    private let dividerColor = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.10)
    private let nsInk        = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)

    var filtered: [ReadingEntry] {
        guard !query.isEmpty else { return store.entries }
        let q = query.lowercased()
        return store.entries.filter { e in
            e.title.lowercased().contains(q) ||
            e.body.lowercased().contains(q) ||
            e.cardEntries.contains { ce in
                ce.note.lowercased().contains(q) ||
                (allCards.first { $0.id == ce.cardID }?.name.lowercased().contains(q) ?? false)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                header
                dividerColor.frame(height: 1)
                entryList
                dividerColor.frame(height: 1)
                newReadingButton
            }

            // Close button
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(faint)
                    .frame(width: 22, height: 22)
                    .background(subtle)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .frame(width: OverlayWindowController.journalW,
               height: OverlayWindowController.journalH)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.2)) { appeared = true } }
        .onExitCommand { close() }
    }

    // MARK: Header (search + label)

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(faint)

            ThemedTextField(
                text: $query,
                placeholder: "Search readings…",
                nsFont: NSFont(name: "Didot", size: 14) ?? .systemFont(ofSize: 14),
                textColor: nsInk,
                cursorColor: nsInk,
                onEscape: { close() }
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)   // clear close button
        .padding(.bottom, 14)
    }

    // MARK: Entry list

    private var entryList: some View {
        Group {
            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 28))
                        .foregroundColor(faint.opacity(0.5))
                    Text(query.isEmpty ? "No readings yet" : "No matches")
                        .font(.app(13))
                        .foregroundColor(faint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { entry in
                            JournalEntryRow(entry: entry)
                                .onTapGesture {
                                    ReadingWindowManager.shared.open(entry: entry)
                                }
                            dividerColor.frame(height: 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: New reading button

    private var newReadingButton: some View {
        Button {
            ReadingWindowManager.shared.openNew()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("New Reading")
                    .font(.app(13, weight: .semibold))
            }
            .foregroundColor(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func close() { OverlayWindowController.shared.hide() }
}

// MARK: - Entry Row

private struct JournalEntryRow: View {
    let entry: ReadingEntry
    @State private var isHovered = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private let ink   = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.40)

    var cardSummary: String {
        let cards = entry.allCardIDs.compactMap { id in allCards.first { $0.id == id } }
        if cards.isEmpty { return "" }
        if cards.count <= 3 { return cards.map { $0.name }.joined(separator: "  ·  ") }
        return "\(cards.count) cards"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Card thumbnails (up to 3)
            cardThumbnails

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title.isEmpty ? "Untitled reading" : entry.title)
                    .font(.app(14))
                    .foregroundColor(entry.title.isEmpty ? faint : ink)
                    .lineLimit(1)

                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(.app(12))
                        .foregroundColor(faint)
                        .lineLimit(1)
                }

                if !cardSummary.isEmpty {
                    Text(cardSummary)
                        .font(.app(11))
                        .foregroundColor(faint.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Date
            Text(Self.dateFmt.string(from: entry.date))
                .font(.app(11))
                .foregroundColor(faint.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            isHovered
                ? Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.05)
                : Color.clear
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var cardThumbnails: some View {
        let cards = entry.allCardIDs.prefix(2).compactMap { id in allCards.first { $0.id == id } }
        if cards.isEmpty {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.06))
                .frame(width: 30, height: 44)
        } else {
            ZStack(alignment: .leading) {
                ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                    Group {
                        if let img = card.image {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 30, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.08))
                                .frame(width: 30, height: 44)
                                .overlay(Text(card.suitSymbol).font(.app(12)))
                        }
                    }
                    .offset(x: CGFloat(i) * 18)
                    .zIndex(Double(cards.count - i))
                }
            }
            .frame(width: cards.count == 1 ? 30 : 48, height: 44)
        }
    }
}
