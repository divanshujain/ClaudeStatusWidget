# ClaudeStatusWidget

macOS menu bar widget displaying real-time Claude Code session status.

## Build

```bash
swift build            # Debug build
swift build -c release # Release build
swift test             # Run tests (requires Xcode)
bash scripts/bundle.sh # Create .app bundle in build/
bash Scripts/install.sh # Build + install to ~/Applications + update statusline
```

## Architecture

- **Swift 6.2 + SPM** — no Xcode IDE required for building
- **AppKit** (`NSStatusItem` + custom `NSView`) for menu bar pill rendering
- **SwiftUI** (hosted in `NSPanel` via `NSHostingView`) for the dropdown
- **DispatchSource** for real-time file watching on `~/.claude/session-status/`
- **NSPanel** (not NSPopover) for precise dropdown positioning below menu bar

## Data Flow

Each Claude Code session's statusline script writes a JSON file to `~/.claude/session-status/<session_id>.json`. The Swift app watches that directory and updates the UI on each change.

## Key Files

- `Sources/ClaudeStatusWidget/main.swift` — App entry, AppDelegate, panel wiring
- `Sources/ClaudeStatusWidget/Services/SessionManager.swift` — Session lifecycle, staleness, cleanup
- `Sources/ClaudeStatusWidget/Services/SessionWatcher.swift` — DispatchSource directory watcher
- `Sources/ClaudeStatusWidget/MenuBar/StatusBarController.swift` — Menu bar pills
- `Sources/ClaudeStatusWidget/MenuBar/PillView.swift` — Individual pill rendering (glass effect)
- `Sources/ClaudeStatusWidget/Popover/PopoverContentView.swift` — Dropdown UI container
- `Scripts/statusline-command.sh` — Modified statusline that writes per-session JSON
- `Scripts/install.sh` — Build + install script
