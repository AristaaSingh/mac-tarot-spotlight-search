import Foundation
import Combine

class OverlayMode: ObservableObject {
    static let shared = OverlayMode()
    enum Mode { case search, journal }

    /// The mode the window controller is animating toward.
    @Published var current: Mode = .search

    /// The mode OverlayRootView actually renders — updated only after the
    /// window has already resized so content never shows at the wrong size.
    @Published var displayed: Mode = .search

    private init() {}
    func toggle() { current = current == .search ? .journal : .search }
}
