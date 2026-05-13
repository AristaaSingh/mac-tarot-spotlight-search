import Foundation
import AppKit

enum Arcana: String, Codable {
    case major = "Major Arcana"
    case minor = "Minor Arcana"
}

enum Suit: String, Codable, CaseIterable {
    case wands = "Wands"
    case cups = "Cups"
    case swords = "Swords"
    case pentacles = "Pentacles"
    case none = ""
}

struct TarotCard: Identifiable, Codable {
    let id: String
    let name: String
    let number: Int
    let arcana: Arcana
    let suit: Suit
    let element: String
    let keywords: [String]
    var upright: String
    var reversed: String
    var personalNote: String

    // Loads from the Cards/ bundle folder, trying jpg then png
    var image: NSImage? {
        for ext in ["jpg", "png", "jpeg", "webp"] {
            if let url = Bundle.main.url(forResource: id, withExtension: ext, subdirectory: "Cards"),
               let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }

    var displayNumber: String {
        switch arcana {
        case .major: return number == 0 ? "0" : "\(number)"
        case .minor: return "\(number)"
        }
    }

    var suitSymbol: String {
        switch suit {
        case .wands:     return "🔥"
        case .cups:      return "💧"
        case .swords:    return "💨"
        case .pentacles: return "🌿"
        case .none:      return "✨"
        }
    }
}
