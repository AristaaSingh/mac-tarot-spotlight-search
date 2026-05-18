import SwiftUI

struct JournalView: View {
    @StateObject private var store = ReadingStore.shared
    @State private var listQuery = ""
    @State private var selectedEntry: ReadingEntry? = nil
    @State private var isNewEntry = false
    @State private var appeared = false

    private let bg          = Color(red: 0.98, green: 0.96, blue: 0.94)
    private let ink         = Color(red: 0.278, green: 0, blue: 0.102)
    private let mid         = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.60)
    private let faint       = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.35)
    private let subtle      = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.07)
    private let dividerColor = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.12)

    private let nsInk = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)

    var filteredEntries: [ReadingEntry] {
        guard !listQuery.isEmpty else { return store.entries }
        let q = listQuery.lowercased()
        return store.entries.filter { entry in
            entry.title.lowercased().contains(q) ||
            entry.body.lowercased().contains(q) ||
            entry.cardEntries.contains { ce in
                ce.note.lowercased().contains(q) ||
                (allCards.first { $0.id == ce.cardID }?.name.lowercased().contains(q) ?? false)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                leftPanel
                dividerColor.frame(width: 1)
                rightPanel
            }

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
        .frame(width: OverlayWindowController.journalW, height: OverlayWindowController.journalH)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.2)) { appeared = true } }
        .onExitCommand { close() }
    }

    private func close() {
        OverlayWindowController.shared.hide()
    }

    private var leftPanel: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed")
                        .font(.app(10))
                        .foregroundColor(faint)
                    Text("READINGS")
                        .font(.app(10, weight: .semibold))
                        .foregroundColor(faint)
                        .kerning(1.2)
                }

                ThemedTextField(
                    text: $listQuery,
                    placeholder: "Search entries…",
                    nsFont: NSFont(name: "Didot", size: 13) ?? .systemFont(ofSize: 13),
                    textColor: nsInk,
                    cursorColor: nsInk,
                    onEscape: { close() }
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(subtle)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            .padding(.top, 50)
            .padding(.bottom, 10)

            dividerColor.frame(height: 1)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(filteredEntries) { entry in
                        EntryRow(entry: entry, isSelected: selectedEntry?.id == entry.id)
                            .onTapGesture {
                                selectedEntry = entry
                                isNewEntry = false
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            dividerColor.frame(height: 1)

            Button {
                selectedEntry = ReadingEntry()
                isNewEntry = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New Reading")
                }
                .font(.app(13, weight: .semibold))
                .foregroundColor(ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(subtle)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(width: 260)
    }

    @ViewBuilder
    private var rightPanel: some View {
        if let entry = selectedEntry {
            ReadingEditorView(
                entry: entry,
                isNew: isNewEntry,
                onSave: { saved in
                    store.save(saved)
                    selectedEntry = saved
                    isNewEntry = false
                },
                onDelete: {
                    store.delete(entry)
                    selectedEntry = nil
                    isNewEntry = false
                },
                onCancel: {
                    if isNewEntry {
                        selectedEntry = nil
                        isNewEntry = false
                    }
                }
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .font(.system(size: 32))
                    .foregroundColor(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.18))
                Text("Select a reading or start a new one")
                    .font(.app(13))
                    .foregroundColor(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.35))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Entry Row

private struct EntryRow: View {
    let entry: ReadingEntry
    let isSelected: Bool
    @State private var isHovered = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var cardSummary: String {
        let cards = entry.allCardIDs.compactMap { id in allCards.first { $0.id == id } }
        if cards.isEmpty { return "No cards" }
        if cards.count <= 2 { return cards.map { $0.name }.joined(separator: ", ") }
        return "\(cards.count) cards"
    }

    private let ink   = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.40)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.title.isEmpty ? "Untitled reading" : entry.title)
                    .font(.app(13))
                    .foregroundColor(entry.title.isEmpty ? faint : ink)
                    .lineLimit(2)
                Spacer()
            }
            HStack {
                Text(cardSummary)
                    .font(.app(10))
                    .foregroundColor(faint)
                Spacer()
                Text(Self.dateFmt.string(from: entry.date))
                    .font(.app(10))
                    .foregroundColor(faint)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            (isSelected || isHovered)
                ? Color(red: 0.278, green: 0, blue: 0.102, opacity: isSelected ? 0.10 : 0.05)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Reading Editor

private struct ReadingEditorView: View {
    let isNew: Bool
    let onSave: (ReadingEntry) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var draft: ReadingEntry
    @State private var pickingForID: String? = nil
    @State private var cardPickerQuery = ""

    private let ink    = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.38)
    private let subtle = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.07)
    private let nsInk  = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)
    private let nsFont14 = NSFont(name: "Didot", size: 14) ?? NSFont.systemFont(ofSize: 14)
    private let nsFont20 = NSFont(name: "Didot", size: 20) ?? NSFont.systemFont(ofSize: 20)

    init(entry: ReadingEntry, isNew: Bool,
         onSave: @escaping (ReadingEntry) -> Void,
         onDelete: (() -> Void)?,
         onCancel: @escaping () -> Void) {
        _draft = State(initialValue: entry)
        self.isNew = isNew; self.onSave = onSave
        self.onDelete = onDelete; self.onCancel = onCancel
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .long; return f
    }()

    var pickerResults: [TarotCard] {
        guard !cardPickerQuery.isEmpty else { return [] }
        let q = cardPickerQuery.lowercased()
        let taken = draft.cardEntries.compactMap { $0.cardID }
        return allCards.filter { $0.name.lowercased().contains(q) && !taken.contains($0.id) }.prefix(8).map { $0 }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Date
                    Text(Self.dateFmt.string(from: draft.date))
                        .font(.app(11))
                        .foregroundColor(faint)
                        .textCase(.uppercase)
                        .kerning(0.8)
                        .padding(.bottom, 12)

                    // Title
                    ThemedTextField(
                        text: $draft.title,
                        placeholder: "Title…",
                        nsFont: nsFont20,
                        textColor: nsInk,
                        cursorColor: nsInk,
                        onEscape: { OverlayWindowController.shared.hide() }
                    )
                    .padding(.bottom, 16)

                    // Free-form body
                    ZStack(alignment: .topLeading) {
                        ThemedTextEditor(text: $draft.body, nsFont: nsFont14, textColor: nsInk, cursorColor: nsInk)
                            .frame(minHeight: 72)
                        if draft.body.isEmpty {
                            Text("Write freely…")
                                .font(.appItalic(14))
                                .foregroundColor(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.28))
                                .padding(.top, 4)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.bottom, 24)

                    // Card entries
                    ForEach($draft.cardEntries) { $ce in
                        CardEntryRow(cardEntry: $ce,
                            onPick: { pickingForID = ce.id },
                            onRemove: { draft.cardEntries.removeAll { $0.id == ce.id } }
                        )
                        .padding(.bottom, 12)
                    }

                    // Add card row button
                    Button {
                        draft.cardEntries.append(CardEntry())
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Add card")
                                .font(.app(13))
                        }
                        .foregroundColor(faint)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)

                    Spacer(minLength: 60)
                }
                .padding(24)
            }

            // Fixed bottom bar
            HStack {
                if !isNew, let onDelete {
                    Button("Delete") { onDelete() }
                        .buttonStyle(JournalButtonStyle(primary: false))
                }
                Spacer()
                Button("Save") { onSave(draft) }
                    .buttonStyle(JournalButtonStyle(primary: true))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.96, blue: 0.94, opacity: 0),
                        Color(red: 0.98, green: 0.96, blue: 0.94, opacity: 0.95),
                        Color(red: 0.98, green: 0.96, blue: 0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            } // end VStack

            // Card picker overlay
            if let id = pickingForID {
                CardPickerOverlay(
                    query: $cardPickerQuery,
                    results: pickerResults,
                    onSelect: { card in
                        if let idx = draft.cardEntries.firstIndex(where: { $0.id == id }) {
                            draft.cardEntries[idx].cardID = card.id
                        }
                        pickingForID = nil
                        cardPickerQuery = ""
                    },
                    onDismiss: { pickingForID = nil; cardPickerQuery = "" }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: pickingForID != nil)
    }
}

// MARK: - Card Entry Row

private struct CardEntryRow: View {
    @Binding var cardEntry: CardEntry
    let onPick: () -> Void
    let onRemove: () -> Void

    @State private var noteHeight: CGFloat = 114

    private let ink    = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.35)
    private let subtle = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.07)
    private let nsInk  = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)
    private let nsFont13 = NSFont(name: "Didot", size: 13) ?? NSFont.systemFont(ofSize: 13)

    var card: TarotCard? { allCards.first { $0.id == cardEntry.cardID } }

    // card width + gap + divider + gap
    private let cardW:       CGFloat = 76
    private let cardH:       CGFloat = 114
    private let cardPadB:    CGFloat = 16   // gap between card bottom and text flowing below
    private let gapW:        CGFloat = 14
    private let dividerW:    CGFloat = 1

    private var exclusionW: CGFloat { cardW + gapW + dividerW + gapW }
    private var exclusionH: CGFloat { cardH + cardPadB }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // Full-width text editor — wraps around card via exclusion path
            ZStack(alignment: .topLeading) {
                GrowingTextEditor(
                    text: $cardEntry.note,
                    height: $noteHeight,
                    minHeight: cardH,
                    exclusionRect: CGRect(x: 0, y: 0, width: exclusionW, height: exclusionH),
                    nsFont: nsFont13,
                    textColor: nsInk,
                    cursorColor: nsInk
                )
                .frame(height: noteHeight)

                if cardEntry.note.isEmpty {
                    Text("Write about this card…")
                        .font(.appItalic(13))
                        .foregroundColor(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.28))
                        .padding(.leading, exclusionW + 5)
                        .padding(.top, 4)
                        .allowsHitTesting(false)
                }
            }

            // Card overlaid top-left
            ZStack(alignment: .topTrailing) {
                Button(action: onPick) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(subtle)
                        if let card {
                            if let img = card.image {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                VStack(spacing: 4) {
                                    Text(card.suitSymbol).font(.app(22))
                                    Text(card.name)
                                        .font(.app(8))
                                        .foregroundColor(ink.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 4)
                                }
                            }
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(faint)
                        }
                    }
                    .frame(width: cardW, height: cardH)
                }
                .buttonStyle(.plain)

                // Remove button on top-right corner of card
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(faint)
                        .frame(width: 16, height: 16)
                        .background(Color(red: 0.98, green: 0.96, blue: 0.94))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }

            // Vertical divider — only as tall as the card
            Rectangle()
                .fill(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.15))
                .frame(width: dividerW, height: cardH)
                .offset(x: cardW + gapW, y: 0)
        }
    }
}

// MARK: - Card Picker Overlay

private struct CardPickerOverlay: View {
    @Binding var query: String
    let results: [TarotCard]
    let onSelect: (TarotCard) -> Void
    let onDismiss: () -> Void

    private let ink    = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.38)
    private let subtle = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.07)
    private let nsInk  = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                ThemedTextField(
                    text: $query,
                    placeholder: "Search cards…",
                    nsFont: NSFont(name: "Didot", size: 14) ?? .systemFont(ofSize: 14),
                    textColor: nsInk,
                    cursorColor: nsInk,
                    onEscape: { onDismiss() }
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(subtle)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(faint)
                        .frame(width: 28, height: 28)
                        .background(subtle)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().background(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.1))

            if query.isEmpty {
                Text("Type a card name…")
                    .font(.appItalic(13))
                    .foregroundColor(faint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if results.isEmpty {
                Text("No cards found")
                    .font(.app(13))
                    .foregroundColor(faint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(results) { card in
                            Button { onSelect(card) } label: {
                                HStack(spacing: 10) {
                                    if let img = card.image {
                                        Image(nsImage: img)
                                            .resizable().scaledToFit()
                                            .frame(width: 28, height: 42)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        Text(card.suitSymbol)
                                            .frame(width: 28, height: 42)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.name).font(.app(13)).foregroundColor(ink)
                                        Text(card.suit == .none ? card.arcana.rawValue : card.suit.rawValue)
                                            .font(.app(10)).foregroundColor(faint)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.06))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.98, green: 0.96, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 16)
        .padding(20)
    }
}

// MARK: - Journal Button Style

private struct JournalButtonStyle: ButtonStyle {
    let primary: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let ink  = Color(red: 0.278, green: 0, blue: 0.102)
        let face = ink.opacity(primary ? (isHovered ? 1.0 : 0.85) : (isHovered ? 0.12 : 0.07))
        return configuration.label
            .font(.app(13, weight: .semibold))
            .foregroundColor(primary ? .white : ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(face)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: isHovered)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
