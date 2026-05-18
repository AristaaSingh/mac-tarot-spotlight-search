import SwiftUI

// Standalone editor/detail panel — hosted in ReadingWindowController.

struct ReadingEditorView: View {
    let isNew: Bool
    let onSave:   (ReadingEntry) -> Void
    let onDelete: (() -> Void)?
    let onClose:  () -> Void

    @State private var draft: ReadingEntry
    @State private var bodyHeight: CGFloat = 44
    @State private var pickingForID: String? = nil
    @State private var cardPickerQuery = ""

    private let bg     = Color(red: 0.98, green: 0.96, blue: 0.94)
    private let ink    = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.38)
    private let subtle = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.07)
    private let nsInk    = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)
    private let nsFont14 = NSFont(name: "Didot", size: 14) ?? NSFont.systemFont(ofSize: 14)
    private let nsFont20 = NSFont(name: "Didot", size: 20) ?? NSFont.systemFont(ofSize: 20)

    init(entry: ReadingEntry, isNew: Bool,
         onSave:   @escaping (ReadingEntry) -> Void,
         onDelete: (() -> Void)? = nil,
         onClose:  @escaping () -> Void) {
        _draft = State(initialValue: entry)
        self.isNew   = isNew
        self.onSave  = onSave
        self.onDelete = onDelete
        self.onClose = onClose
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .long; return f
    }()

    var pickerResults: [TarotCard] {
        guard !cardPickerQuery.isEmpty else { return [] }
        let q = cardPickerQuery.lowercased()
        let taken = draft.cardEntries.compactMap { $0.cardID }
        return allCards
            .filter { $0.name.lowercased().contains(q) && !taken.contains($0.id) }
            .prefix(8).map { $0 }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {

                // ── Top bar ──────────────────────────────────────────────
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(faint)
                            .frame(width: 22, height: 22)
                            .background(subtle)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(isNew ? "New Reading" : "Edit Reading")
                        .font(.app(12, weight: .semibold))
                        .foregroundColor(faint)
                        .kerning(0.6)

                    Spacer()
                    Color.clear.frame(width: 22, height: 22) // balance
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.08).frame(height: 1)

                // ── Scrollable content ───────────────────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        Text(Self.dateFmt.string(from: draft.date))
                            .font(.app(11))
                            .foregroundColor(faint)
                            .textCase(.uppercase)
                            .kerning(0.8)
                            .padding(.bottom, 12)

                        ThemedTextField(
                            text: $draft.title,
                            placeholder: "Title…",
                            nsFont: nsFont20,
                            textColor: nsInk,
                            cursorColor: nsInk,
                            onEscape: { onClose() }
                        )
                        .padding(.bottom, 16)

                        // Body — starts 2 lines, grows as you type
                        ZStack(alignment: .topLeading) {
                            GrowingTextEditor(
                                text: $draft.body,
                                height: $bodyHeight,
                                minHeight: 44,
                                nsFont: nsFont14,
                                textColor: nsInk,
                                cursorColor: nsInk
                            )
                            .frame(height: bodyHeight)
                            if draft.body.isEmpty {
                                Text("Write freely…")
                                    .font(.appItalic(14))
                                    .foregroundColor(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.28))
                                    .padding(.top, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(.bottom, 4)

                        // Card entries
                        ForEach($draft.cardEntries) { $ce in
                            CardEntryRow(
                                cardEntry: $ce,
                                onPick:   { pickingForID = ce.id },
                                onRemove: { draft.cardEntries.removeAll { $0.id == ce.id } }
                            )
                            .padding(.bottom, 12)
                        }

                        Button { draft.cardEntries.append(CardEntry()) } label: {
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

                // ── Fixed bottom bar ────────────────────────────────────
                HStack {
                    if !isNew, let onDelete {
                        Button("Delete") { onDelete() }
                            .buttonStyle(ReadingButtonStyle(primary: false))
                    }
                    Spacer()
                    Button("Save") { onSave(draft) }
                        .buttonStyle(ReadingButtonStyle(primary: true))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            bg.opacity(0),
                            bg.opacity(0.97),
                            bg
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
            .background(bg)

            // ── Card picker overlay ──────────────────────────────────────
            if let id = pickingForID {
                Color.black.opacity(0.10).ignoresSafeArea()
                CardPickerView(
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

struct CardEntryRow: View {
    @Binding var cardEntry: CardEntry
    let onPick:   () -> Void
    let onRemove: () -> Void

    @State private var noteHeight: CGFloat = 114

    private let ink    = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.35)
    private let subtle = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.07)
    private let nsInk    = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)
    private let nsFont13 = NSFont(name: "Didot", size: 13) ?? NSFont.systemFont(ofSize: 13)

    var card: TarotCard? { allCards.first { $0.id == cardEntry.cardID } }

    private let cardW:    CGFloat = 76
    private let cardH:    CGFloat = 114
    private let cardPadB: CGFloat = 16
    private let gapW:     CGFloat = 14
    private let dividerW: CGFloat = 1

    private var exclusionW: CGFloat { cardW + gapW + dividerW + gapW }
    private var exclusionH: CGFloat { cardH + cardPadB }

    var body: some View {
        ZStack(alignment: .topLeading) {

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

            ZStack(alignment: .topTrailing) {
                Button(action: onPick) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(subtle)
                        if let card {
                            if let img = card.image {
                                Image(nsImage: img)
                                    .resizable().scaledToFill()
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

            Rectangle()
                .fill(Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.15))
                .frame(width: dividerW, height: cardH)
                .offset(x: cardW + gapW, y: 0)
        }
    }
}

// MARK: - Card Picker

struct CardPickerView: View {
    @Binding var query: String
    let results:   [TarotCard]
    let onSelect:  (TarotCard) -> Void
    let onDismiss: () -> Void

    private let bg     = Color(red: 0.98, green: 0.96, blue: 0.94)
    private let ink    = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.38)
    private let subtle = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.07)
    private let nsInk  = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)

    var body: some View {
        VStack(spacing: 0) {
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
                                        Text(card.suitSymbol).frame(width: 28, height: 42)
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
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.14), radius: 18)
        .padding(20)
    }
}

// MARK: - Button style

struct ReadingButtonStyle: ButtonStyle {
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
