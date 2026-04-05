#!/usr/bin/env bash
set -euo pipefail

swift build -c release 2>&1

APP_DIR="build/ClaudeStatusWidget.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp .build/release/ClaudeStatusWidget "$APP_DIR/MacOS/"
cp Sources/ClaudeStatusWidget/Info.plist "$APP_DIR/"

# Copy SPM resource bundle (contains icons etc.)
if [ -d ".build/release/ClaudeStatusWidget_ClaudeStatusWidget.bundle" ]; then
    cp -r .build/release/ClaudeStatusWidget_ClaudeStatusWidget.bundle "$APP_DIR/Resources/"
fi

echo "Built: build/ClaudeStatusWidget.app"
