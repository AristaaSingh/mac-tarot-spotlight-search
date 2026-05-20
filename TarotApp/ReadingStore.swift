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

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

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
}
