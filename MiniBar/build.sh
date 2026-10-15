#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_BUNDLE="$DIR/MiniBar.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

echo "Building MiniBar..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

swiftc -O \
    "$DIR/Sources/Preferences.swift" \
    "$DIR/Sources/AppDelegate.swift" \
    "$DIR/Sources/main.swift" \
    -o "$MACOS_DIR/MiniBar" \
    -framework Cocoa \
    -framework ServiceManagement

# Ad-hoc sign the app so macOS treats it as a valid bundle
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Successfully built $APP_BUNDLE"
