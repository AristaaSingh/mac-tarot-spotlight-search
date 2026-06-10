import Foundation
import Combine

class ReadingStore: ObservableObject {
    static let shared = ReadingStore()

    @Published var entries: [ReadingEntry] = []

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("TarotApp/readings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let encoder = JSONEncoder.iso8601
    private let decoder = JSONDecoder.iso8601

    private init() {
        load()
    }

    func load() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil) else { return }
        entries = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> ReadingEntry? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(ReadingEntry.self, from: data)
            }
            .sorted { $0.date > $1.date }
        migrateOrphanedEntries()
    }

    /// Assign any entries that pre-date folders to a default "My Readings" folder.
    private func migrateOrphanedEntries() {
        let orphans = entries.filter { $0.folderID.isEmpty }
        guard !orphans.isEmpty else { return }

        let fs = FolderStore.shared
        let defaultFolder = fs.folders.first(where: { $0.name == "My Readings" })
                         ?? fs.create(name: "My Readings")

        for entry in orphans {
            var updated = entry
            updated.folderID = defaultFolder.id
            save(updated)
        }
    }

    func save(_ entry: ReadingEntry) {
        guard let data = try? encoder.encode(entry) else { return }
        let fileURL = storageURL.appendingPathComponent("\(entry.id).json")
        try? data.write(to: fileURL, options: .atomic)
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { $0.date > $1.date }
    }

    func delete(_ entry: ReadingEntry) {
        let fileURL = storageURL.appendingPathComponent("\(entry.id).json")
        try? FileManager.default.removeItem(at: fileURL)
        entries.removeAll { $0.id == entry.id }
    }

    /// Reassign a set of entries to a different folder.
    func move(_ ids: Set<String>, toFolder folderID: String) {
        for id in ids {
            guard let idx = entries.firstIndex(where: { $0.id == id }) else { continue }
            var entry = entries[idx]
            entry.folderID = folderID
            save(entry)
        }
    }

    /// Delete all entries that belong to any of the given folder IDs.
    func deleteAll(inFolders folderIDs: Set<String>) {
        let toDelete = entries.filter { folderIDs.contains($0.folderID) }
        toDelete.forEach { delete($0) }
    }

    /// Delete a set of entries by ID.
    func delete(_ ids: Set<String>) {
        for id in ids {
            if let entry = entries.first(where: { $0.id == id }) { delete(entry) }
        }
    }

    /// Duplicate a set of entries into a different folder (originals stay put).
    func copy(_ ids: Set<String>, toFolder folderID: String) {
        for id in ids {
            guard let entry = entries.first(where: { $0.id == id }) else { continue }
            var newEntry      = entry
            newEntry.id       = UUID().uuidString
            newEntry.folderID = folderID
            save(newEntry)
        }
    }
}
