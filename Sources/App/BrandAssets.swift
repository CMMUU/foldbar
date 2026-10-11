import AppKit
import SwiftUI

enum BrandAssets {
    static let appIcon: NSImage = {
        guard let url = Bundle.main.url(forResource: "FoldBar", withExtension: "png"), let image = NSImage(contentsOf: url) else { return NSImage() }
        return image
    }()

    // The folded F is simplified to a monochrome silhouette for the 18 pt menu bar.
    static func menuIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 3, y: 2, width: 4, height: 14), xRadius: 1.6, yRadius: 1.6).fill()
            NSBezierPath(roundedRect: NSRect(x: 3, y: 12, width: 12, height: 4), xRadius: 1.6, yRadius: 1.6).fill()
            NSBezierPath(roundedRect: NSRect(x: 5, y: 7, width: 8, height: 3.5), xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}

struct BrandIcon: View {
    var size: CGFloat = 32
    var body: some View { Image(nsImage: BrandAssets.appIcon).resizable().scaledToFit().frame(width: size, height: size).accessibilityHidden(true) }
}
