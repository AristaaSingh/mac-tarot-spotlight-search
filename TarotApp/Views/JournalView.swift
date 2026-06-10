import SwiftUI

// MARK: - Navigation container

struct JournalView: View {
    @State private var selectedFolder: Folder? = nil
    @State private var appeared = false

    var body: some View {
        ZStack {
            if let folder = selectedFolder {
                FolderDetailView(folder: folder, onBack: {
                    withAnimation(.easeInOut(duration: 0.22)) { selectedFolder = nil }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal:   .move(edge: .trailing)
                ))
            } else {
                FolderListView(onSelect: { folder in
                    withAnimation(.easeInOut(duration: 0.22)) { selectedFolder = folder }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal:   .move(edge: .leading)
                ))
            }
        }
        .frame(width: OverlayWindowController.journalW,
               height: OverlayWindowController.journalH)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }
}

// MARK: - Folder list

struct FolderListView: View {
    let onSelect: (Folder) -> Void

    @StateObject private var folderStore  = FolderStore.shared
    @StateObject private var readingStore = ReadingStore.shared

    @State private var query              = ""
    @State private var searchFocused      = false

    @State private var isCreating         = false
    @State private var newFolderName      = ""
    @State private var createFieldFocused = false

    // Selection
    @State private var isSelecting        = false
    @State private var selectedIDs        = Set<String>()
    @State private var confirmingDelete   = false

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    private var entriesByFolder: [String: [ReadingEntry]] {
        Dictionary(grouping: readingStore.entries, by: \.folderID)
    }

    // Search across all readings (only used when query is non-empty)
    private var searchResults: [ReadingEntry] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return readingStore.entries.filter { e in
            e.title.lowercased().contains(q) ||
            e.body.lowercased().contains(q)  ||
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
                Theme.divider.frame(height: 1)
                folderGrid
                Theme.divider.frame(height: 1)
                bottomBar
            }

            // Close overlay (hidden during selection)
            if !isSelecting {
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

                Text(selectedIDs.isEmpty ? "Select folders" : "\(selectedIDs.count) selected")
                    .font(.app(13, weight: .semibold))
                    .foregroundColor(Theme.ink)

                Spacer()

                TextHoverButton(
                    label: selectedIDs.count == folderStore.folders.count ? "Deselect All" : "Select All"
                ) {
                    if selectedIDs.count == folderStore.folders.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(folderStore.folders.map { $0.id })
                    }
                }
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.faint)

                ThemedTextField(
                    text: $query,
                    placeholder: "Search all readings…",
                    nsFont: .didot(18),
                    textColor: Theme.nsInk,
                    cursorColor: Theme.nsInk,
                    isFocused: searchFocused,
                    onEscape: { query.isEmpty ? OverlayWindowController.shared.hide() : (query = "") }
                )

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.faint.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                if query.isEmpty && !folderStore.folders.isEmpty {
                    SelectButton { isSelecting = true }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 14)
    }

    // MARK: Folder grid / search results

    private var folderGrid: some View {
        Group {
            if !query.isEmpty {
                // Search results: flat reading grid across all folders
                if searchResults.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.faint.opacity(0.5))
                        Text("No matches")
                            .font(.app(13))
                            .foregroundColor(Theme.faint)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(searchResults) { entry in
                                ReadingThumbnail(entry: entry)
                                    .onTapGesture { ReadingWindowManager.shared.open(entry: entry) }
                            }
                        }
                        .padding(16)
                    }
                }
            } else if folderStore.folders.isEmpty && !isCreating {
                VStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.faint.opacity(0.5))
                    Text("No folders yet")
                        .font(.app(13))
                        .foregroundColor(Theme.faint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(folderStore.folders) { folder in
                            FolderThumbnail(
                                folder:      folder,
                                entries:     entriesByFolder[folder.id] ?? [],
                                isSelecting: isSelecting,
                                isSelected:  selectedIDs.contains(folder.id)
                            )
                            .onTapGesture {
                                if isSelecting {
                                    toggleSelection(folder.id)
                                } else {
                                    onSelect(folder)
                                }
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
                    HStack(spacing: 16) {
                        let n = selectedIDs.count
                        Text("Delete \(n) folder\(n == 1 ? "" : "s") and all their readings?")
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
                    BottomBarButton(
                        icon:     "trash",
                        label:    "Delete",
                        disabled: selectedIDs.isEmpty,
                        tint:     selectedIDs.isEmpty ? Theme.ink : .red.opacity(0.75)
                    ) {
                        withAnimation(.easeOut(duration: 0.12)) { confirmingDelete = true }
                    }
                }
            } else if isCreating {
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        createFieldFocused = true
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func exitSelection() {
        isSelecting      = false
        selectedIDs.removeAll()
        confirmingDelete = false
    }

    private func deleteSelected() {
        readingStore.deleteAll(inFolders: selectedIDs)
        selectedIDs.forEach { folderStore.delete(Folder(id: $0, name: "")) }
        withAnimation(.spring(response: 0.3)) {
            isSelecting      = false
            selectedIDs.removeAll()
            confirmingDelete = false
        }
    }

    private func commitCreate() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelCreate(); return }
        let folder = FolderStore.shared.create(name: name)
        newFolderName = ""
        isCreating = false
        createFieldFocused = false
        onSelect(folder)
    }

    private func cancelCreate() {
        newFolderName = ""
        isCreating = false
        createFieldFocused = false
    }

    private func close() { OverlayWindowController.shared.hide() }
}

// MARK: - Folder thumbnail card

private struct FolderThumbnail: View {
    let folder:      Folder
    let entries:     [ReadingEntry]
    var isSelecting: Bool = false
    var isSelected:  Bool = false

    @State private var isHovered = false

    var count: Int { entries.count }

    var previewCards: [TarotCard] {
        entries
            .flatMap { $0.allCardIDs }
            .prefix(3)
            .compactMap { id in allCards.first { $0.id == id } }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Preview area
            ZStack {
                Theme.ink.opacity(0.05)

                if previewCards.isEmpty {
                    Image(systemName: "folder")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.faint.opacity(0.5))
                } else {
                    let angles:  [Double]  = [-10, 0, 10]
                    let offsets: [CGFloat] = [-14, 0, 14]
                    ZStack {
                        ForEach(Array(previewCards.enumerated()), id: \.offset) { i, card in
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

            // Name + count
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.app(12, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(count == 1 ? "1 reading" : "\(count) readings")
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
