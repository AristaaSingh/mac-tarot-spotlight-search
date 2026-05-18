import Foundation
import Combine

class OverlayMode: ObservableObject {
    static let shared = OverlayMode()
    enum Mode { case search, journal }
    @Published var current: Mode = .search
    private init() {}
    func toggle() { current = current == .search ? .journal : .search }
}
