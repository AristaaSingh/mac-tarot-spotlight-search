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

    @State private var isCreating        = false
    @State private var newFolderName     = ""
    @State private var createFieldFocused = false

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    // Pre-compute entries per folder so thumbnails don't each filter the array
    private var entriesByFolder: [String: [ReadingEntry]] {
        Dictionary(grouping: readingStore.entries, by: \.folderID)
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

            // Close overlay
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
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Readings")
                .font(.app(20, weight: .bold))
                .foregroundColor(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 14)
    }

    // MARK: Folder grid

    private var folderGrid: some View {
        Group {
            if folderStore.folders.isEmpty && !isCreating {
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
                                folder:  folder,
                                entries: entriesByFolder[folder.id] ?? []
                            )
                            .onTapGesture { onSelect(folder) }
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
                Button {
                    isCreating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        createFieldFocused = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("New Folder")
                            .font(.app(13, weight: .semibold))
                    }
                    .foregroundColor(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Actions

    private func commitCreate() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelCreate(); return }
        let folder = FolderStore.shared.create(name: name)
        newFolderName = ""
        isCreating = false
        createFieldFocused = false
        onSelect(folder)   // navigate straight into the new folder
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
    let folder:  Folder
    let entries: [ReadingEntry]

    @State private var isHovered = false

    var count: Int { entries.count }

    // Show a card fan from the most recent entries in this folder
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
