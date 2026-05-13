import SwiftUI
import AppKit

struct AnimatedGIFView: NSViewRepresentable {
    let filename: String

    func makeNSView(context: Context) -> NSImageView {
        let iv = NSImageView()
        if let url = Bundle.main.url(forResource: filename, withExtension: "gif"),
           let image = NSImage(contentsOf: url) {
            iv.image = image
            iv.animates = true
        }
        iv.imageScaling = .scaleAxesIndependently
        iv.wantsLayer = true
        return iv
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {}
}
