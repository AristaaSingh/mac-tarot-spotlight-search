import Foundation

struct CardContent: Codable {
    var upright:          String
    var reversed:         String
    var uprightKeywords:  [String]?
    var reversedKeywords: [String]?
}

class ContentStore {
    static let shared = ContentStore()
    private init() {}

    private static let base: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TarotApp")
    }()

    // MARK: - Public

    func content(for card: TarotCard) -> CardContent {
        let url = Self.fileURL(for: card)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return CardContent(upright: "", reversed: "", uprightKeywords: nil, reversedKeywords: nil)
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
        var text = "## Upright\n\(content.upright)\n\n## Reversed\n\(content.reversed)\n"
        if let kws = content.uprightKeywords {
            text += "\n## Keywords Upright\n\(kws.joined(separator: "\n"))\n"
        }
        if let kws = content.reversedKeywords {
            text += "\n## Keywords Reversed\n\(kws.joined(separator: "\n"))\n"
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Markdown parser

    private func parse(_ text: String) -> CardContent {
        var upright = "", reversed = ""
        var uprightKeywords:  [String]? = nil
        var reversedKeywords: [String]? = nil
        var current = ""

        for line in text.components(separatedBy: "\n") {
            switch line.trimmingCharacters(in: .whitespaces) {
            case "## Upright":
                current = "upright"
            case "## Reversed":
                current = "reversed"
            case "## My Notes":
                current = ""
            case "## Keywords Upright", "## Keywords":
                current = "kwUpright"
                if uprightKeywords == nil { uprightKeywords = [] }
            case "## Keywords Reversed":
                current = "kwReversed"
                if reversedKeywords == nil { reversedKeywords = [] }
            default:
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                switch current {
                case "upright":    upright  += line + "\n"
                case "reversed":   reversed += line + "\n"
                case "kwUpright":  if !trimmed.isEmpty { uprightKeywords?.append(trimmed) }
                case "kwReversed": if !trimmed.isEmpty { reversedKeywords?.append(trimmed) }
                default: break
                }
            }
        }

        return CardContent(
            upright:          upright.trimmingCharacters(in: .whitespacesAndNewlines),
            reversed:         reversed.trimmingCharacters(in: .whitespacesAndNewlines),
            uprightKeywords:  uprightKeywords,
            reversedKeywords: reversedKeywords
        )
    }
}
