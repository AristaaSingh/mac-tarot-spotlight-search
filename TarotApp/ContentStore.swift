import Foundation

struct CardContent: Codable {
    var upright:      String
    var reversed:     String
    var personalNote: String
    var keywords:     [String]  // empty = fall back to TarotCard.keywords
}

class ContentStore {
    static let shared = ContentStore()
    private init() {}

    private static let base: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Programming/tarot-app/card-content")
    }()

    // MARK: - Public

    func content(for card: TarotCard) -> CardContent {
        let url = Self.fileURL(for: card)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return CardContent(upright: "", reversed: "", personalNote: "", keywords: [])
        }
        return parse(text)
    }

    // MARK: - File path

    static func fileURL(for card: TarotCard) -> URL {
        let subfolder: String
        switch card.arcana {
        case .major: subfolder = "major-arcana"
        case .minor: subfolder = card.suit.rawValue.lowercased()
        }
        return base
            .appendingPathComponent(subfolder)
            .appendingPathComponent("\(card.id).md")
    }

    // MARK: - Save

    func save(_ content: CardContent, for card: TarotCard) {
        let url = Self.fileURL(for: card)
        var text = "## Upright\n\(content.upright)\n\n## Reversed\n\(content.reversed)\n\n## My Notes\n\(content.personalNote)\n"
        if !content.keywords.isEmpty {
            text += "\n## Keywords\n\(content.keywords.joined(separator: "\n"))\n"
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Markdown parser

    private func parse(_ text: String) -> CardContent {
        var upright = "", reversed = "", notes = ""
        var keywords: [String] = []
        var current = ""

        for line in text.components(separatedBy: "\n") {
            switch line.trimmingCharacters(in: .whitespaces) {
            case "## Upright":   current = "upright"
            case "## Reversed":  current = "reversed"
            case "## My Notes":  current = "notes"
            case "## Keywords":  current = "keywords"
            default:
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                switch current {
                case "upright":  upright  += line + "\n"
                case "reversed": reversed += line + "\n"
                case "notes":    notes    += line + "\n"
                case "keywords":
                    if !trimmed.isEmpty { keywords.append(trimmed) }
                default: break
                }
            }
        }

        return CardContent(
            upright:      upright.trimmingCharacters(in: .whitespacesAndNewlines),
            reversed:     reversed.trimmingCharacters(in: .whitespacesAndNewlines),
            personalNote: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            keywords:     keywords
        )
    }
}
