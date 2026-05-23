import Foundation

struct CardContent: Codable {
    var upright:          String
    var reversed:         String
    var uprightKeywords:  [String]
    var reversedKeywords: [String]

    init(upright: String = "", reversed: String = "",
         uprightKeywords: [String] = [], reversedKeywords: [String] = []) {
        self.upright          = upright
        self.reversed         = reversed
        self.uprightKeywords  = uprightKeywords
        self.reversedKeywords = reversedKeywords
    }

    // Custom decode: old files may have null or missing keyword arrays — treat as [].
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        upright          = try c.decode(String.self, forKey: .upright)
        reversed         = try c.decode(String.self, forKey: .reversed)
        uprightKeywords  = (try? c.decodeIfPresent([String].self, forKey: .uprightKeywords))  ?? []
        reversedKeywords = (try? c.decodeIfPresent([String].self, forKey: .reversedKeywords)) ?? []
    }
}

class ContentStore {
    static let shared = ContentStore()
    private init() {}

    private var cache: [String: CardContent] = [:]

    private static let base: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TarotApp")
    }()

    // MARK: - Public

    func content(for card: TarotCard) -> CardContent {
        if let cached = cache[card.id] { return cached }
        let url = Self.fileURL(for: card)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return CardContent()
        }
        let result = parse(text)
        cache[card.id] = result
        return result
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
        cache[card.id] = content
        let url = Self.fileURL(for: card)
        var text = "## Upright\n\(content.upright)\n\n## Reversed\n\(content.reversed)\n"
        if !content.uprightKeywords.isEmpty {
            text += "\n## Keywords Upright\n\(content.uprightKeywords.joined(separator: "\n"))\n"
        }
        if !content.reversedKeywords.isEmpty {
            text += "\n## Keywords Reversed\n\(content.reversedKeywords.joined(separator: "\n"))\n"
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Markdown parser

    private func parse(_ text: String) -> CardContent {
        var upright = "", reversed = ""
        var uprightKeywords:  [String] = []
        var reversedKeywords: [String] = []
        var current = ""

        for line in text.components(separatedBy: "\n") {
            switch line.trimmingCharacters(in: .whitespaces) {
            case "## Upright":           current = "upright"
            case "## Reversed":          current = "reversed"
            case "## My Notes":          current = ""
            case "## Keywords Upright",
                 "## Keywords":          current = "kwUpright"
            case "## Keywords Reversed": current = "kwReversed"
            default:
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                switch current {
                case "upright":    upright  += line + "\n"
                case "reversed":   reversed += line + "\n"
                case "kwUpright":  if !trimmed.isEmpty { uprightKeywords.append(trimmed) }
                case "kwReversed": if !trimmed.isEmpty { reversedKeywords.append(trimmed) }
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
