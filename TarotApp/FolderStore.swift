import Foundation
import Combine

class FolderStore: ObservableObject {
    static let shared = FolderStore()

    @Published var folders: [Folder] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask).first!
            .appendingPathComponent("TarotApp")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("folders.json")
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    private init() { load() }

    func load() {
        guard let data    = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([Folder].self, from: data)
        else { return }
        folders = decoded.sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func create(name: String) -> Folder {
        let folder = Folder(name: name)
        folders.append(folder)
        persist()
        return folder
    }

    func rename(_ folder: Folder, to name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].name = name
        persist()
    }

    func delete(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(folders) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
