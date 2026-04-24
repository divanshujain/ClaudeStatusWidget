#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ClaudeStatusWidget Installer ==="

echo "Building..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

APP="$HOME/Applications/ClaudeStatusWidget.app"
APP_CONTENTS="$APP/Contents"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
cp .build/release/ClaudeStatusWidget "$APP_CONTENTS/MacOS/"
cp Sources/ClaudeStatusWidget/Info.plist "$APP_CONTENTS/"

BUNDLE_NAME="ClaudeStatusWidget_ClaudeStatusWidget.bundle"
if [ -d ".build/release/$BUNDLE_NAME" ]; then
    rm -rf "$APP_CONTENTS/Resources/$BUNDLE_NAME"
    cp -r ".build/release/$BUNDLE_NAME" "$APP_CONTENTS/Resources/"
fi

codesign --remove-signature "$APP_CONTENTS/MacOS/ClaudeStatusWidget" >/dev/null 2>&1 || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Installed app to ~/Applications/ClaudeStatusWidget.app"

cp "$SCRIPT_DIR/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
chmod +x "$HOME/.claude/statusline-command.sh"
echo "Updated statusline script at ~/.claude/statusline-command.sh"

mkdir -p "$HOME/.claude/session-status"
echo "Created ~/.claude/session-status/"

echo ""
echo "=== Installation complete ==="
echo "  - Open ~/Applications/ClaudeStatusWidget.app to start"
echo "  - To auto-start on login: System Settings > General > Login Items"
echo ""
