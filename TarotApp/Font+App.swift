import SwiftUI

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
