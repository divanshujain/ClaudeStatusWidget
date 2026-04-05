import AppKit
import SwiftUI

enum SessionColorPalette {
    private static let colors: [NSColor] = [
        .systemPurple,
        .systemBlue,
        .systemGreen,
        .systemTeal,
        .systemOrange,
        .systemPink,
        .systemIndigo,
    ]

    /// Maps used to persist color assignments per session_id across reloads.
    private static var assignments: [String: Int] = [:]
    private static var nextIndex: Int = 0

    static func color(for sessionId: String) -> NSColor {
        if let idx = assignments[sessionId] {
            return colors[idx % colors.count]
        }
        let idx = nextIndex
        assignments[sessionId] = idx
        nextIndex += 1
        return colors[idx % colors.count]
    }

    static func swiftUIColor(for sessionId: String) -> Color {
        Color(nsColor: color(for: sessionId))
    }

    static func reset() {
        assignments.removeAll()
        nextIndex = 0
    }
}
