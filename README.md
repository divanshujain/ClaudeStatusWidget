# Claude Status Widget

A native macOS menu bar widget that displays real-time Claude Code session status. Monitor context usage, rate limits, and costs across multiple sessions at a glance.

![Menu Bar](assets/menubar.png)

![Dropdown](assets/dropdown.png)

## Features

- Real-time context window usage per session (tokens used / total)
- 5-hour and 7-day rate limit tracking with burn rate projections
- "Safe" / "danger" indicators for rate limits
- Multiple concurrent session support
- Stale session detection (greyed out after 5 min inactivity)
- Dead session cleanup (auto-removed 30 min after process exits)
- Click session rows to open project in Finder
- Right-click to copy session info
- Native macOS frosted glass dropdown (MenuBarExtra)

## Requirements

- macOS 13+ (Ventura)
- Swift 5.9+
- Xcode (for running tests) or Command Line Tools (for building)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

## Installation

### 1. Clone and build

```bash
git clone https://github.com/divanshujain/ClaudeStatusWidget.git
cd ClaudeStatusWidget
bash Scripts/install.sh
```

This builds the app, installs it to `~/Applications/`, and updates the Claude Code statusline script.

### 2. Configure Claude Code statusline

The install script automatically copies the statusline script to `~/.claude/statusline-command.sh`. You need to tell Claude Code to use it by adding this to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

If you already have a `statusLine` entry, replace it with the above.

### 3. Launch the widget

```bash
open ~/Applications/ClaudeStatusWidget.app
```

To auto-start on login: **System Settings > General > Login Items > Add ClaudeStatusWidget**.

### 4. Start a Claude Code session

The widget will automatically detect any running Claude Code session and display its status in the menu bar. Start a session in any terminal:

```bash
claude
```

The menu bar will update in real-time as you interact with Claude.

## How It Works

```
Claude Code session
  -> statusline script fires on each turn
  -> writes JSON to ~/.claude/session-status/<session_id>.json
  -> widget's file watcher detects the change
  -> menu bar and dropdown update instantly
```

Each session writes its own JSON file containing context usage, rate limits, model, cost, and other metadata. The widget watches the `~/.claude/session-status/` directory and updates the UI whenever a file changes.

### Timers

| Timer | Interval | Purpose |
|-------|----------|---------|
| File watcher | Instant | Detects session data changes via DispatchSource |
| Staleness check | 30s | Greys out sessions with no updates for 5+ minutes |
| Dead process cleanup | 30s | Removes sessions whose process has exited (after 30 min) |
| Rate limit refresh | 60s | Recalculates countdown timers from stored reset timestamps |

## Building from Source

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run tests (requires Xcode)
bash Scripts/bundle.sh   # Create .app bundle in build/
bash Scripts/install.sh  # Build + install to ~/Applications
```

## Project Structure

```
Sources/ClaudeStatusWidget/
  ClaudeStatusWidgetApp.swift    # App entry, MenuBarExtra, session watcher setup
  Models/
    SessionData.swift            # Codable models for session JSON
    RateLimitStatus.swift        # Burn rate calculator, severity levels
    SessionColorPalette.swift    # Color assignments per session
  Services/
    SessionManager.swift         # Session lifecycle, staleness, cleanup
    SessionWatcher.swift         # DispatchSource directory watcher
  MenuBar/
    StatusBarController.swift    # NSStatusItem pill rendering (unused with MenuBarExtra)
    PillView.swift               # Custom pill view (unused with MenuBarExtra)
  Popover/
    PopoverContentView.swift     # Dropdown container
    SessionRowView.swift         # Session row with progress ring
    RateLimitsView.swift         # Rate limit bars and status
Scripts/
  statusline-command.sh          # Claude Code statusline script
  install.sh                     # Build + install automation
  bundle.sh                      # .app bundle creation
```

## License

MIT
