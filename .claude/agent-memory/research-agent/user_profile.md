---
name: User Profile
description: Developer building a native macOS menu bar app called ClaudeStatusWidget in Swift/SwiftUI
type: user
---

Building ClaudeStatusWidget — a macOS menu bar app with a dropdown panel in Swift/SwiftUI.

Technical level: knows Swift, SwiftUI, AppKit (NSPanel, NSVisualEffectView). Asking detailed implementation questions about NSPanel styleMask combinations and NSVisualEffectView material values.

Goal: Achieve native macOS frosted glass look matching system widgets (Weather, Wi-Fi, Control Center).

Current approach: NSPanel + NSVisualEffectView with .menu material + .behindWindow — result is too dark/opaque.
