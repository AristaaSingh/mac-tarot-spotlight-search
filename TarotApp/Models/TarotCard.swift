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
    var url: String?

    // Loads from the Cards/ bundle folder, trying jpg then png
    var image: NSImage? {
        for ext in ["jpg", "png", "jpeg", "webp"] {
            if let url = Bundle.main.url(forResource: id, withExtension: ext, subdirectory: "Cards"),
               let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }

    var displayNumber: String {
        number == 0 ? "0" : Self.toRoman(number)
    }

    private static func toRoman(_ n: Int) -> String {
        let values = [1000,900,500,400,100,90,50,40,10,9,5,4,1]
        let glyphs  = ["M","CM","D","CD","C","XC","L","XL","X","IX","V","IV","I"]
        var result = "", n = n
        for (v, g) in zip(values, glyphs) {
            while n >= v { result += g; n -= v }
        }
        return result
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
