import AppKit

class PillView: NSView {
    var label: String = ""
    var percentage: Int = 0
    var pillColor: NSColor = .systemPurple
    var isDimmed: Bool = false

    override var intrinsicContentSize: NSSize {
        let text = "\(label) \(percentage)%"
        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attrs)
        return NSSize(width: textSize.width + 12, height: 18)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 1, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)

        let alpha: CGFloat = isDimmed ? 0.3 : 0.85
        pillColor.withAlphaComponent(alpha).setFill()
        path.fill()

        let text = "\(label) \(percentage)%"
        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        let textColor: NSColor = isDimmed ? .secondaryLabelColor : .white
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }
}
