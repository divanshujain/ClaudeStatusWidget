import AppKit

class PillView: NSView {
    var label: String = ""
    var percentage: Int = 0
    var pillColor: NSColor = .systemPurple
    var isDimmed: Bool = false

    override var intrinsicContentSize: NSSize {
        let text = "\(label) \(percentage)%"
        let font = NSFont.menuBarFont(ofSize: 0)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attrs)
        // dot + gap + text + padding; height matches menu bar (22pt)
        return NSSize(width: textSize.width + 28, height: 22)
    }

    // Fill the entire status bar height
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(NSSize(width: newSize.width, height: superview?.bounds.height ?? newSize.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0, dy: 0)

        // Semi-transparent dark capsule background — readable on any menu bar
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        NSColor(white: 0.0, alpha: isDimmed ? 0.15 : 0.35).setFill()
        bgPath.fill()

        // Thin border for definition
        NSColor(white: 1.0, alpha: isDimmed ? 0.05 : 0.12).setStroke()
        bgPath.lineWidth = 0.5
        bgPath.stroke()

        // Colored dot
        let dotSize: CGFloat = 6
        let dotY = (bounds.height - dotSize) / 2
        let dotRect = NSRect(x: 9, y: dotY, width: dotSize, height: dotSize)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        pillColor.withAlphaComponent(isDimmed ? 0.3 : 0.9).setFill()
        dotPath.fill()

        // Text — use label color for automatic light/dark adaptation
        let text = "\(label) \(percentage)%"
        let font = NSFont.menuBarFont(ofSize: 0)
        let textColor: NSColor = isDimmed
            ? NSColor.secondaryLabelColor
            : NSColor.white.withAlphaComponent(0.95)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let textX: CGFloat = 9 + dotSize + 5
        let textRect = NSRect(
            x: textX,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }
}
