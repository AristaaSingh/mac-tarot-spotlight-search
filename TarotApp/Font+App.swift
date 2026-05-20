import SwiftUI
import AppKit

extension Font {
    // Didot for all app text. Bold/semibold → Didot-Bold, everything else → Didot.
    static func app(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .semibold, .heavy, .black:
            return .custom("Didot-Bold", size: size)
        default:
            return .custom("Didot", size: size)
        }
    }

    static func appItalic(_ size: CGFloat) -> Font {
        .custom("Didot-Italic", size: size)
    }
}

extension NSFont {
    /// Didot at the given point size, with a system-font fallback.
    static func didot(_ size: CGFloat) -> NSFont {
        NSFont(name: "Didot", size: size) ?? .systemFont(ofSize: size)
    }
}
