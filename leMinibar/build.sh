#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_BUNDLE="$DIR/leMinibar.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

echo "Building leMinibar..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "/private/tmp/minibar.iconset/icon_512x512.png" ]; then
    iconutil -c icns /private/tmp/minibar.iconset -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
fi

swiftc -O \
    "$DIR/Sources/Preferences.swift" \
    "$DIR/Sources/AppDelegate.swift" \
    "$DIR/Sources/main.swift" \
    -o "$MACOS_DIR/leMinibar" \
    -framework Cocoa \
    -framework ServiceManagement

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Successfully built $APP_BUNDLE"
