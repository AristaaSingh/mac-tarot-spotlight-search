import SwiftUI
import AppKit

/// Shared colour tokens for the app's beige-and-burgundy palette.
/// Reference these instead of repeating raw RGBA values throughout views.
enum Theme {

    // ── Solid base colours ────────────────────────────────────────────────
    static let bg  = Color(red: 0.98, green: 0.96, blue: 0.94)
    static let ink = Color(red: 0.278, green: 0, blue: 0.102)

    // ── Ink at standard opacities ─────────────────────────────────────────
    static let mid     = ink.opacity(0.50)   // subheadings, secondary labels
    static let faint   = ink.opacity(0.35)   // placeholder text, tertiary labels
    static let subtle  = ink.opacity(0.07)   // subtle fills, card slots
    static let divider = ink.opacity(0.10)   // horizontal rules

    // ── AppKit equivalents ────────────────────────────────────────────────
    static let nsInk = NSColor(red: 0.278, green: 0, blue: 0.102, alpha: 1)
    static let nsBg  = NSColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 1)
}
