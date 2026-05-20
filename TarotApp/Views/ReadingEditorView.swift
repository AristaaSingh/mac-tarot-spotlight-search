import SwiftUI

// MARK: - Card deletion undo proxy
//
// NSUndoManager needs a class (reference type) as its target.
// This proxy holds a live Binding to the card entries array so that undo/redo
// operations can modify state even when the SwiftUI view struct has been recreated.

private final class CardUndoProxy: ObservableObject {
    var cardEntries: Binding<[CardEntry]>?

    // Live reference to the whole draft — Binding wraps @State storage, so it always
    // reflects the current value even though it's only assigned once on appear.
    var draft: Binding<ReadingEntry>?

    // Retains the local key monitor so we can remove it on disappear.
    var keyMonitor: Any?

    /// Call this right before removing a card. Records undo (restore) + wires up redo (remove again).
    func recordRemoval(of card: CardEntry, at idx: Int, undoManager: UndoManager?) {
        undoManager?.registerUndo(withTarget: self) { [weak self] proxy in
            let safeIdx = min(idx, proxy.cardEntries?.wrappedValue.count ?? 0)
            proxy.cardEntries?.wrappedValue.insert(card, at: safeIdx)
            // Registering undo while NSUndoManager.isUndoing == true pushes to the redo stack.
            self?.recordInsertion(of: card, at: idx, undoManager: undoManager)
        }
        undoManager?.setActionName("Delete Card")
    }

    /// Called during undo (card was restored). Registers the inverse so redo removes it again.
    private func recordInsertion(of card: CardEntry, at idx: Int, undoManager: UndoManager?) {
        undoManager?.registerUndo(withTarget: self) { [weak self] proxy in
            proxy.cardEntries?.wrappedValue.removeAll { $0.id == card.id }
            self?.recordRemoval(of: card, at: idx, undoManager: undoManager)
        }
    }
}

// MARK: -

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
    @State private var showDatePicker = false

    @StateObject private var undoProxy = CardUndoProxy()
    @Environment(\.undoManager) var undoManager

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
                            .foregroundColor(Theme.faint)
                            .frame(width: 22, height: 22)
                            .background(Theme.subtle)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(isNew ? "New Reading" : "Edit Reading")
                        .font(.app(12, weight: .semibold))
                        .foregroundColor(Theme.faint)
                        .kerning(0.6)

                    Spacer()
                    Color.clear.frame(width: 22, height: 22) // balance
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Theme.ink.opacity(0.08).frame(height: 1)

                // ── Scrollable content ───────────────────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Title + date on the same line
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            ThemedTextField(
                                text: $draft.title,
                                placeholder: "Title…",
                                nsFont: .didot(24),
                                textColor: Theme.nsInk,
                                cursorColor: Theme.nsInk,
                                onEscape: { onClose() }
                            )

                            DateBubbleButton(date: draft.date) {
                                showDatePicker.toggle()
                            }
                            .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                                CalendarPicker(selection: $draft.date)
                            }
                            .fixedSize()
                        }
                        .padding(.bottom, 16)

                        // Body — starts 2 lines, grows as you type
                        ZStack(alignment: .topLeading) {
                            GrowingTextEditor(
                                text: $draft.body,
                                height: $bodyHeight,
                                minHeight: 44,
                                nsFont: .didot(14),
                                textColor: Theme.nsInk,
                                cursorColor: Theme.nsInk
                            )
                            .frame(height: bodyHeight)
                            if draft.body.isEmpty {
                                Text("Write freely…")
                                    .font(.appItalic(14))
                                    .foregroundColor(Theme.ink.opacity(0.28))
                                    .padding(.top, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(.bottom, 4)

                        // Card entries
                        // Use value-based ForEach + a safe Binding so that when an entry
                        // is removed, any final updateNSView calls on GrowingTextEditor
                        // don't access an out-of-bounds index and crash/loop.
                        ForEach(draft.cardEntries, id: \.id) { ce in
                            CardEntryRow(
                                cardEntry: Binding(
                                    get: {
                                        draft.cardEntries.first { $0.id == ce.id } ?? ce
                                    },
                                    set: { newVal in
                                        if let idx = draft.cardEntries.firstIndex(where: { $0.id == ce.id }) {
                                            draft.cardEntries[idx] = newVal
                                        }
                                    }
                                ),
                                        onPick:   { pickingForID = ce.id },
                                onRemove: {
                                    guard let idx = draft.cardEntries.firstIndex(where: { $0.id == ce.id }) else { return }
                                    let removed = draft.cardEntries[idx]
                                    undoProxy.recordRemoval(of: removed, at: idx, undoManager: undoManager)
                                    draft.cardEntries.remove(at: idx)
                                }
                            )
                            .padding(.bottom, 12)
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(24)
                }

                // ── Fixed bottom bar ────────────────────────────────────
                HStack {
                    // Add card lives here so it can never overlap scroll content
                    Button { draft.cardEntries.append(CardEntry()) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Add card")
                        }
                    }
                    .buttonStyle(ReadingButtonStyle(primary: false))

                    Spacer()

                    if !isNew, let onDelete {
                        Button("Delete") { onDelete() }
                            .buttonStyle(ReadingButtonStyle(primary: false))
                    }
                    Button("Save") { onSave(draft) }
                        .buttonStyle(ReadingButtonStyle(primary: true))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            Theme.bg.opacity(0),
                            Theme.bg.opacity(0.97),
                            Theme.bg
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
            .background(Theme.bg)

            // ── Card picker search pill ──────────────────────────────────
            if pickingForID != nil {
                CardPickerView(
                    query: $cardPickerQuery,
                    onSubmit: {
                        if let first = pickerResults.first { applySelection(first) }
                    },
                    onDismiss: { dismissPicker() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: pickingForID != nil)
        // Give the undo proxy a live binding to the card entries array.
        // Binding captures @State storage by reference, so one assignment in onAppear is enough.
        .onAppear {
            undoProxy.cardEntries = $draft.cardEntries
            undoProxy.draft       = $draft

            // Cmd+S and Escape both save + close.
            undoProxy.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak undoProxy] event in
                let isEscape = event.keyCode == 53
                let isCmdS   = event.keyCode == 1 && event.modifierFlags.contains(.command)
                guard isEscape || isCmdS else { return event }
                if let current = undoProxy?.draft?.wrappedValue {
                    onSave(current)
                }
                return nil
            }
        }
        .onDisappear {
            if let m = undoProxy.keyMonitor { NSEvent.removeMonitor(m); undoProxy.keyMonitor = nil }
        }
        // Drive thumbnail panels whenever the query changes
        .onChange(of: cardPickerQuery) { _ in
            guard pickingForID != nil else { return }
            let results = pickerResults
            if results.isEmpty {
                CardPickerThumbnailManager.shared.clear()
            } else {
                let frame = NSApp.keyWindow?.frame ?? .zero
                CardPickerThumbnailManager.shared.show(
                    cards: results,
                    relativeTo: frame,
                    onSelect: { card in applySelection(card) }
                )
            }
        }
        // Clear thumbnails when picker closes
        .onChange(of: pickingForID) { id in
            if id == nil { CardPickerThumbnailManager.shared.clear() }
        }
    }

    private func applySelection(_ card: TarotCard) {
        guard let id = pickingForID else { return }
        if let idx = draft.cardEntries.firstIndex(where: { $0.id == id }) {
            draft.cardEntries[idx].cardID = card.id
        }
        pickingForID    = nil
        cardPickerQuery = ""
        CardPickerThumbnailManager.shared.clear()
    }

    private func dismissPicker() {
        pickingForID    = nil
        cardPickerQuery = ""
        CardPickerThumbnailManager.shared.clear()
    }
}

// MARK: - Date Bubble Button

private struct DateBubbleButton: View {
    let date:   Date
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
    }()

    private let face  = Theme.ink.opacity(0.11)
    private let hover = Theme.ink.opacity(0.18)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(Self.fmt.string(from: date).uppercased())
                    .font(.app(10, weight: .semibold))
                    .kerning(0.7)
                Image(systemName: "calendar")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(Theme.ink.opacity(0.60))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? hover : face)
            )
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .animation(.spring(response: 0.12, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Card Entry Row

struct CardEntryRow: View {
    @Binding var cardEntry: CardEntry
    let onPick:   () -> Void
    let onRemove: () -> Void

    @State private var noteHeight:    CGFloat = 114
    @State private var isCardHovered: Bool    = false

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
                    nsFont: .didot(14),
                    textColor: Theme.nsInk,
                    cursorColor: Theme.nsInk
                )
                .frame(height: noteHeight)

                if cardEntry.note.isEmpty {
                    Text("Write about this card…")
                        .font(.appItalic(13))
                        .foregroundColor(Theme.ink.opacity(0.28))
                        .padding(.leading, exclusionW + 5)
                        .padding(.top, 4)
                        .allowsHitTesting(false)
                }
            }

            // ── Card slot ────────────────────────────────────────────────
            Button(action: card != nil ? onRemove : onPick) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.subtle)

                    if let card {
                        // Card image or symbol fallback
                        if let img = card.image {
                            Image(nsImage: img)
                                .resizable().scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            VStack(spacing: 4) {
                                Text(card.suitSymbol).font(.app(22))
                                Text(card.name)
                                    .font(.app(8))
                                    .foregroundColor(Theme.ink.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 4)
                            }
                        }

                        // Hover overlay — dark tint + trash icon
                        if isCardHovered {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.45))
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.white.opacity(0.90))
                        }
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(Theme.faint)
                    }
                }
                .frame(width: cardW, height: cardH)
            }
            .buttonStyle(.plain)
            .onHover { isCardHovered = card != nil && $0 }
            .animation(.easeOut(duration: 0.12), value: isCardHovered)

            Rectangle()
                .fill(Theme.ink.opacity(0.15))
                .frame(width: dividerW, height: cardH)
                .offset(x: cardW + gapW, y: 0)
        }
    }
}

// MARK: - Card Picker
// Just the search pill — results appear as floating thumbnail panels via CardPickerThumbnailManager.

struct CardPickerView: View {
    @Binding var query: String
    let onSubmit:  () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.app(15))
                .foregroundColor(Theme.ink.opacity(0.40))

            ThemedTextField(
                text: $query,
                placeholder: "Search cards…",
                nsFont: .didot(18),
                textColor: Theme.nsInk,
                cursorColor: Theme.nsInk,
                isFocused: true,
                onSubmit: onSubmit,
                onEscape: onDismiss
            )

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.faint.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 360)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 6)
    }
}

// MARK: - Button style

struct ReadingButtonStyle: ButtonStyle {
    let primary: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let face = Theme.ink.opacity(primary ? (isHovered ? 1.0 : 0.85) : (isHovered ? 0.12 : 0.07))
        return configuration.label
            .font(.app(13, weight: .semibold))
            .foregroundColor(primary ? .white : Theme.ink)
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
