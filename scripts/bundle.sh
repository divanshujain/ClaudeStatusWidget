#!/usr/bin/env bash
set -euo pipefail

swift build -c release 2>&1

APP="build/ClaudeStatusWidget.app"
APP_CONTENTS="$APP/Contents"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
cp .build/release/ClaudeStatusWidget "$APP_CONTENTS/MacOS/"
cp Sources/ClaudeStatusWidget/Info.plist "$APP_CONTENTS/"

# Copy SPM resource bundle to Contents/Resources/. Icon lookup (see
# loadMenuBarIcon in ClaudeStatusWidgetApp.swift) enumerates nested bundles
# from Bundle.main.resourceURL, so no symlink at the app root is needed.
BUNDLE_NAME="ClaudeStatusWidget_ClaudeStatusWidget.bundle"
if [ -d ".build/release/$BUNDLE_NAME" ]; then
    rm -rf "$APP_CONTENTS/Resources/$BUNDLE_NAME"
    cp -r ".build/release/$BUNDLE_NAME" "$APP_CONTENTS/Resources/"
fi

# Ad-hoc re-sign so the resource manifest matches what's on disk. Without this,
# macOS refuses to launch bundles copied from other machines with:
# "code has no resources but signature indicates they must be present".
codesign --remove-signature "$APP_CONTENTS/MacOS/ClaudeStatusWidget" >/dev/null 2>&1 || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built: $APP"
