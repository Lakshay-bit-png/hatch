import AppKit

enum MenuBarIcon {
    /// The app icon's glyph — a stack of kept cards — as a template image, so the
    /// menu bar tints it for light and dark automatically.
    static func image() -> NSImage {
        let size = NSSize(width: 16, height: 14)

        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()

            // The two cards peeking out behind.
            let backs: [(CGFloat, CGFloat, CGFloat)] = [
                (0.40, 0.90, 0.075),
                (0.56, 0.74, 0.085)
            ]
            for (widthFraction, yFraction, heightFraction) in backs {
                let w = rect.width * widthFraction
                let h = rect.height * heightFraction
                let bar = NSRect(x: (rect.width - w) / 2, y: rect.height * yFraction - h, width: w, height: h)
                NSBezierPath(roundedRect: bar, xRadius: h / 2, yRadius: h / 2).fill()
            }

            // The front card, hollow so the stack stays legible at menu bar size.
            let w = rect.width * 0.76
            let h = rect.height * 0.44
            let front = NSRect(x: (rect.width - w) / 2, y: rect.height * 0.08, width: w, height: h)
            let path = NSBezierPath(roundedRect: front, xRadius: rect.width * 0.11, yRadius: rect.width * 0.11)
            path.lineWidth = rect.height * 0.11
            path.stroke()

            return true
        }

        image.isTemplate = true
        return image
    }
}
