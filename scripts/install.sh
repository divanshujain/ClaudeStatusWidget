#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ClaudeStatusWidget Installer ==="

# 1. Build the app
echo "Building..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

# 2. Create .app bundle
APP_DIR="$HOME/Applications/ClaudeStatusWidget.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp .build/release/ClaudeStatusWidget "$APP_DIR/MacOS/"
cp Sources/ClaudeStatusWidget/Info.plist "$APP_DIR/"
# Copy SPM resource bundle (icons etc.)
if [ -d ".build/release/ClaudeStatusWidget_ClaudeStatusWidget.bundle" ]; then
    cp -r .build/release/ClaudeStatusWidget_ClaudeStatusWidget.bundle "$APP_DIR/Resources/"
fi
echo "Installed app to ~/Applications/ClaudeStatusWidget.app"

# 3. Install statusline script
cp "$SCRIPT_DIR/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
chmod +x "$HOME/.claude/statusline-command.sh"
echo "Updated statusline script at ~/.claude/statusline-command.sh"

# 4. Create session-status directory
mkdir -p "$HOME/.claude/session-status"
echo "Created ~/.claude/session-status/"

echo ""
echo "=== Installation complete ==="
echo "  - Open ~/Applications/ClaudeStatusWidget.app to start"
echo "  - To auto-start on login: System Settings > General > Login Items"
echo ""
