# Claude Status Widget — Design Spec

## Overview

A native macOS menu bar widget that displays real-time Claude Code session status. Shows colored folder pills per session in the menu bar, with an Apple-themed dropdown popover showing session details and shared rate limits.

## Problem

Claude Code's built-in statusline only shows data for the current session within the terminal. When running multiple sessions in parallel, there's no unified view of all sessions, context usage, or shared rate limits.

## Solution

Two components:

1. **Modified statusline script** — writes per-session JSON files on each Claude turn
2. **Native macOS Swift app** — watches those files and renders a menu bar widget with dropdown

---

## Architecture

### Data Flow

```
Claude turn → statusline script fires → writes ~/.claude/session-status/<session_id>.json
→ FS event (DispatchSource) → Swift app reads file → UI updates
```

### Components

- **Statusline script** (`~/.claude/statusline-command.sh`): Modified to write per-session JSON to `~/.claude/session-status/`. Keeps existing stdout output for Claude Code's built-in statusline and existing `mark2-health.json` for Rocket.
- **SessionEnd hook** (`session-cleanup.sh`): Deletes the session's JSON file when Claude exits cleanly.
- **Swift app** (`ClaudeStatusWidget.app`): Watches the session-status directory, renders menu bar + popover.

### Timers

| Timer | Interval | Purpose |
|-------|----------|---------|
| Staleness check | 30s | Compare `timestamp` age, check `kill(pid, 0)` for liveness |
| Rate limit refresh | 60s | Recalculate countdowns from `resets_at` locally |

---

## Menu Bar Item

**Implementation:** `NSStatusItem` with custom `NSView`.

**Layout:** Colored pills per session + shared rate limit.

```
[Widget 67%] [Rocket 23%] [Portfolio 8%]  ·  5h: 42%
```

### Session Pills

- Each session gets a unique color from a predefined palette (Apple system colors: purple, blue, green, teal, orange, pink, indigo)
- Folder name truncated to ~10 chars with ellipsis if needed
- Context usage percentage shown in the pill

### Rate Limit Display

- Shows 5-hour usage percentage
- Color-coded: green (< 50%), yellow (50-75%), red (> 75% or projected to hit limit before reset)

### Session States

| State | Appearance | Trigger |
|-------|-----------|---------|
| Active | Full color pill | Updates within last 5 min |
| Stale | Dimmed/greyed pill | No updates > 5 min, process alive |
| Dead | Removed after 30 min timeout | Process gone (`kill(pid, 0)` fails) |

### Edge Cases

- **0 sessions:** Show just the icon `◆` with no pills
- **5+ sessions:** Truncate to first 4 pills + `+N` badge
- **Stale but alive:** Keep visible (greyed) as a reminder to close the session

---

## Dropdown Popover

**Triggered by:** Click on menu bar item. Opens `NSPopover` with SwiftUI content.

**Width:** ~280px. Height adapts to session count (max height with scroll for 10+ sessions).

### Sessions List (top section)

Each row contains:
- Colored dot (matching pill color)
- Folder name (bold)
- Subtitle: model + token count (e.g., "Opus · 670k / 1M")
- Thin progress bar on the right

**Stale sessions:** Same row but dimmed, "idle" label replacing token count.

**Interactions:**
- Click session row → open directory in Finder (or Terminal if detectable)
- Right-click / secondary action → copy session info to clipboard

### Divider

### Usage Limits (bottom section)

Header: "Usage Limits" in small uppercase.

For each limit (5-hour, 7-day):
- Label + progress bar + percentage
- Burn rate (e.g., "6.2%/h")
- Reset countdown (e.g., "resets 2h 14m")
- Text label: "safe" (green) or "~1h 12m to full" (orange/red)
- Bar color: green = safe, yellow = moderate (> 60%), red = will hit limit before reset

### Footer

Small muted text: total cost across all sessions.

---

## Session JSON File Format

Path: `~/.claude/session-status/<session_id>.json`

```json
{
  "session_id": "abc123",
  "pid": 12345,
  "folder_name": "ClaudeStatusWidget",
  "folder_path": "/Users/divanshujain/Documents/Projects/ClaudeStatusWidget",
  "model": "Opus",
  "context": {
    "used_tokens": 670000,
    "total_tokens": 1000000,
    "used_percentage": 67
  },
  "rate_limits": {
    "five_hour": {
      "used_percentage": 42.0,
      "resets_at": 1738425600
    },
    "seven_day": {
      "used_percentage": 18.0,
      "resets_at": 1738857600
    }
  },
  "cost_usd": 0.42,
  "lines_added": 156,
  "lines_removed": 23,
  "timestamp": 1738420000
}
```

### Field Notes

- `pid`: Captured via `$PPID` in the statusline script. Used for liveness checks.
- `timestamp`: Unix epoch seconds. Used for staleness detection.
- `rate_limits`: Shared across sessions. Written by whichever session fires last, so always fresh from the most recent API call.
- `context.used_tokens`: Sum of `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`.

---

## Statusline Script Changes

The existing `statusline-command.sh` is modified to:

1. Write per-session JSON to `~/.claude/session-status/<session_id>.json`
2. Capture PID via `$PPID`
3. Keep existing stdout output (Claude Code's built-in statusline still works)
4. Keep existing `mark2-health.json` write (Rocket system compatibility)

### Session Cleanup

The statusline script writes `pid` to each session file. The Swift app's 30s heartbeat checks `kill(pid, 0)` — when the process is gone, the session is marked dead and its JSON file is deleted after 30 min. No additional hook is needed; the heartbeat is the primary cleanup mechanism.

If we want faster cleanup, a `Stop` hook could delete the file, but since the hook receives session context via stdin, the cleanup script would extract `session_id` from stdin and remove the file. This is optional — the heartbeat covers it reliably.

---

## Project Structure

```
ClaudeStatusWidget/
├── ClaudeStatusWidget.xcodeproj
├── ClaudeStatusWidget/
│   ├── App/
│   │   ├── ClaudeStatusWidgetApp.swift      # App entry, NSApplicationDelegate
│   │   └── AppDelegate.swift                # NSStatusItem setup, popover management
│   ├── MenuBar/
│   │   ├── StatusBarController.swift        # NSStatusItem + custom NSView for pills
│   │   └── PillView.swift                   # Individual session pill rendering
│   ├── Popover/
│   │   ├── PopoverContentView.swift         # Main SwiftUI popover container
│   │   ├── SessionRowView.swift             # Individual session row
│   │   └── RateLimitsView.swift             # Usage limits section with bars
│   ├── Models/
│   │   ├── SessionData.swift                # Codable model for session JSON
│   │   └── RateLimitStatus.swift            # Burn rate calc, safe/danger state
│   ├── Services/
│   │   ├── SessionWatcher.swift             # DispatchSource file watcher
│   │   ├── SessionManager.swift             # Session lifecycle, staleness, cleanup
│   │   └── RateLimitCalculator.swift        # Burn rate, projection, color coding
│   └── Resources/
│       └── Assets.xcassets                  # App icon, colors
├── Scripts/
│   ├── statusline-command.sh                # Modified statusline script
│   └── session-cleanup.sh                   # SessionEnd hook script
└── README.md
```

## Requirements

- macOS 13+ (Ventura)
- Swift 5.9+
- No external dependencies — Apple frameworks only (SwiftUI, AppKit, Foundation)
- `LSUIElement = true` in Info.plist (no dock icon, menu bar app only)

## Tech Stack

- **Menu bar:** `NSStatusItem` + custom `NSView` (AppKit) for pill rendering
- **Dropdown:** `NSPopover` hosting SwiftUI views
- **File watching:** `DispatchSource.makeFileSystemObjectSource`
- **Data:** `Codable` JSON parsing, no persistence layer needed
