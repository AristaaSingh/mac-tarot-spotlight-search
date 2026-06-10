import SwiftUI

// MARK: - Folder detail (inside a folder)

struct FolderDetailView: View {
    let folder:  Folder
    let onBack:  () -> Void

    @StateObject private var store       = ReadingStore.shared
    @StateObject private var folderStore = FolderStore.shared

    @State private var query           = ""
    @State private var searchFocused   = false

    // Selection
    @State private var isSelecting      = false
    @State private var selectedIDs      = Set<String>()
    @State private var pickerAction: PickerAction? = nil
    @State private var confirmingDelete = false

    private enum PickerAction: Equatable { case move, copy }

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    // Readings that belong to this folder
    var folderEntries: [ReadingEntry] {
        store.entries.filter { $0.folderID == folder.id }
    }

    // Filtered by the search query (only relevant when not selecting)
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
        for entry in (isSelecting ? folderEntries : filtered) {
            let key = Self.monthFmt.string(from: entry.date)
            if seen[key] == nil { order.append(key); seen[key] = [] }
            seen[key]!.append(entry)
        }
        return order.map { (month: $0, entries: seen[$0]!) }
    }

    private var otherFolders: [Folder] {
        folderStore.folders.filter { $0.id != folder.id }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                header
                Theme.divider.frame(height: 1)
                entryGrid
                Theme.divider.frame(height: 1)
                bottomBar
            }

            // Back + close buttons (hidden during selection)
            if !isSelecting {
                HStack(spacing: 6) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.faint)
                            .frame(width: 22, height: 22)
                            .background(Theme.subtle)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.faint)
                            .frame(width: 22, height: 22)
                            .background(Theme.subtle)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
            }

            // Folder picker bottom sheet
            folderPickerOverlay
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
            if isSelecting {
                TextHoverButton(label: "Cancel", action: exitSelection)

                Spacer()

                // Selection count
                Text(selectedIDs.isEmpty ? "Select readings" : "\(selectedIDs.count) selected")
                    .font(.app(13, weight: .semibold))
                    .foregroundColor(Theme.ink)

                Spacer()

                TextHoverButton(
                    label: selectedIDs.count == folderEntries.count ? "Deselect All" : "Select All"
                ) {
                    if selectedIDs.count == folderEntries.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(folderEntries.map { $0.id })
                    }
                }

            } else {
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
                    onEscape: { query.isEmpty ? onBack() : (query = "") }
                )

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.faint.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                // Select button (only when search is empty)
                if query.isEmpty && !folderEntries.isEmpty {
                    SelectButton { isSelecting = true }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 14)
    }

    // MARK: Entry grid

    private var entryGrid: some View {
        Group {
            let displayEntries = isSelecting ? folderEntries : filtered
            if displayEntries.isEmpty {
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
                                    ReadingThumbnail(
                                        entry:       entry,
                                        isSelecting: isSelecting,
                                        isSelected:  selectedIDs.contains(entry.id)
                                    )
                                    .onTapGesture {
                                        if isSelecting {
                                            toggleSelection(entry.id)
                                        } else {
                                            ReadingWindowManager.shared.open(entry: entry)
                                        }
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

    // MARK: Bottom bar

    private var bottomBar: some View {
        Group {
            if isSelecting {
                if confirmingDelete {
                    // Confirmation row
                    HStack(spacing: 16) {
                        let n = selectedIDs.count
                        Text("Delete \(n) reading\(n == 1 ? "" : "s")?")
                            .font(.app(13))
                            .foregroundColor(Theme.ink)
                        Spacer()
                        Button("Cancel") {
                            withAnimation(.easeOut(duration: 0.12)) { confirmingDelete = false }
                        }
                        .font(.app(13))
                        .foregroundColor(Theme.mid)
                        .buttonStyle(.plain)
                        Button("Delete") { deleteSelected() }
                            .font(.app(13, weight: .bold))
                            .foregroundColor(.red.opacity(0.8))
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                } else {
                    // Action row
                    HStack(spacing: 0) {
                        BottomBarButton(
                            icon:     "arrow.right.circle",
                            label:    "Move to…",
                            disabled: selectedIDs.isEmpty
                        ) { pickerAction = .move }

                        Theme.divider.frame(width: 1, height: 24)

                        BottomBarButton(
                            icon:     "doc.on.doc",
                            label:    "Copy to…",
                            disabled: selectedIDs.isEmpty
                        ) { pickerAction = .copy }

                        Theme.divider.frame(width: 1, height: 24)

                        BottomBarButton(
                            icon:     "trash",
                            label:    "Delete",
                            disabled: selectedIDs.isEmpty,
                            tint:     selectedIDs.isEmpty ? Theme.ink : .red.opacity(0.75)
                        ) {
                            withAnimation(.easeOut(duration: 0.12)) { confirmingDelete = true }
                        }
                    }
                }
            } else {
                BottomBarButton(icon: "plus", label: "New Reading") {
                    ReadingWindowManager.shared.openNew(in: folder.id)
                }
            }
        }
    }

    // MARK: Folder picker overlay

    private var folderPickerOverlay: some View {
        ZStack(alignment: .bottom) {
            if pickerAction != nil {
                // Scrim
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring(response: 0.3)) { pickerAction = nil } }

                // Picker card
                VStack(alignment: .leading, spacing: 0) {
                    // Title row
                    HStack {
                        Text(pickerAction == .move ? "Move to…" : "Copy to…")
                            .font(.app(15, weight: .bold))
                            .foregroundColor(Theme.ink)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) { pickerAction = nil }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.faint)
                                .frame(width: 20, height: 20)
                                .background(Theme.ink.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    Theme.divider.frame(height: 1)

                    if otherFolders.isEmpty {
                        Text("No other folders")
                            .font(.app(13))
                            .foregroundColor(Theme.faint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(otherFolders) { f in
                            FolderPickerRow(folder: f) {
                                if let action = pickerAction { performAction(action, toFolder: f.id) }
                            }
                            if f.id != otherFolders.last?.id {
                                Theme.divider.frame(height: 1).padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .background(Theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: pickerAction)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        // Disable hit-testing when picker is not shown so the full-size frame
        // doesn't shadow interactive views beneath it (e.g. the back button).
        .allowsHitTesting(pickerAction != nil)
    }

    // MARK: Helpers

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func exitSelection() {
        isSelecting      = false
        selectedIDs.removeAll()
        pickerAction     = nil
        confirmingDelete = false
    }

    private func deleteSelected() {
        store.delete(selectedIDs)
        withAnimation(.spring(response: 0.3)) {
            isSelecting      = false
            selectedIDs.removeAll()
            confirmingDelete = false
        }
    }

    private func performAction(_ action: PickerAction, toFolder targetID: String) {
        switch action {
        case .move: store.move(selectedIDs, toFolder: targetID)
        case .copy: store.copy(selectedIDs, toFolder: targetID)
        }
        // All state resets in one animation block so SwiftUI doesn't get
        // competing assignments (withAnimation + exitSelection both touching pickerAction).
        withAnimation(.spring(response: 0.3)) {
            pickerAction = nil
            isSelecting  = false
            selectedIDs.removeAll()
        }
    }

    private func close() { OverlayWindowController.shared.hide() }
}

// MARK: - Folder picker row

private struct FolderPickerRow: View {
    let folder: Folder
    let onTap:  () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.ink)
                Text(folder.name)
                    .font(.app(14))
                    .foregroundColor(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.faint)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(Theme.ink.opacity(isHovered ? 0.05 : 0))
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Select button (icon + label, mid tint)

struct SelectButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                Text("Select")
                    .font(.app(13))
            }
            .foregroundColor(Theme.mid)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.ink.opacity(isHovered ? 0.08 : 0))
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Plain text button with hover background

struct TextHoverButton: View {
    let label:  String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.app(13))
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.ink.opacity(isHovered ? 0.08 : 0))
                .clipShape(Capsule())
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Back button with circle + hover

private struct BackButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.ink)
                .frame(width: 22, height: 22)
                .background(Theme.ink.opacity(isHovered ? 0.14 : 0.08))
                .clipShape(Circle())
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Shared bottom bar button (hover-aware)

struct BottomBarButton: View {
    let icon:     String
    let label:    String
    var disabled: Bool    = false
    var tint:     Color   = Theme.ink
    let action:   () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.app(13, weight: .semibold))
            }
            .foregroundColor(tint.opacity(disabled ? 0.3 : 1))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.ink.opacity(!disabled && isHovered ? 0.06 : 0))
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { if !disabled { isHovered = $0 } }
    }
}

// MARK: - Reading thumbnail card

struct ReadingThumbnail: View {
    let entry:       ReadingEntry
    var isSelecting: Bool = false
    var isSelected:  Bool = false

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

                // Selection checkbox overlay
                if isSelecting {
                    Color.black.opacity(isSelected ? 0.18 : 0)
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Theme.ink : Color.white.opacity(0.85))
                                    .frame(width: 22, height: 22)
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Circle()
                                        .strokeBorder(Theme.ink.opacity(0.35), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                }
                            }
                            .padding(8)
                        }
                        Spacer()
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
                .stroke(
                    isSelected    ? Theme.ink.opacity(0.55) :
                    isHovered     ? Theme.ink.opacity(0.18) :
                                    Theme.ink.opacity(0.07),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(isHovered && !isSelecting ? 0.12 : 0.04),
                radius: isHovered && !isSelecting ? 10 : 4, y: 2)
        .scaleEffect(isHovered && !isSelecting ? 1.025 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isSelected)
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
