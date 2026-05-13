import Foundation

struct CardContent: Codable {
    var upright:      String
    var reversed:     String
    var personalNote: String
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
            return CardContent(upright: "", reversed: "", personalNote: "")
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

    // MARK: - Markdown parser

    private func parse(_ text: String) -> CardContent {
        var upright = "", reversed = "", notes = ""
        var current = ""

        for line in text.components(separatedBy: "\n") {
            switch line.trimmingCharacters(in: .whitespaces) {
            case "## Upright":   current = "upright"
            case "## Reversed":  current = "reversed"
            case "## My Notes":  current = "notes"
            default:
                switch current {
                case "upright":  upright  += line + "\n"
                case "reversed": reversed += line + "\n"
                case "notes":    notes    += line + "\n"
                default: break
                }
            }
        }

        return CardContent(
            upright:      upright.trimmingCharacters(in: .whitespacesAndNewlines),
            reversed:     reversed.trimmingCharacters(in: .whitespacesAndNewlines),
            personalNote: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
