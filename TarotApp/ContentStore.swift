import Foundation

// Manages loading card content from ~/Documents/TarotApp/cards.json.
// On first launch it writes a template with all 78 cards so the user
// can open the file and fill in their interpretations.

struct CardContent: Codable {
    var upright:      String
    var reversed:     String
    var personalNote: String
}

class ContentStore {
    static let shared = ContentStore()

    private var store: [String: CardContent] = [:]

    private init() {
        ensureTemplateExists()
        load()
    }

    func content(for id: String) -> CardContent {
        store[id] ?? CardContent(upright: "", reversed: "", personalNote: "")
    }

    // MARK: - File location

    static var fileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Desktop/Programming/tarot-app/cards.json")
    }

    // MARK: - Load

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode([String: CardContent].self, from: data)
        else { return }
        store = decoded
    }

    // MARK: - Template

    private func ensureTemplateExists() {
        let url = Self.fileURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        try? FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let template = Dictionary(uniqueKeysWithValues: allCards.map {
            ($0.id, CardContent(upright: "", reversed: "", personalNote: ""))
        })
        if let data = try? JSONEncoder().encode(template) {
            // Pretty-print so it's easy to read in a text editor
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj,
                                                         options: [.prettyPrinted, .sortedKeys]) {
                try? pretty.write(to: url)
            }
        }
    }
}
