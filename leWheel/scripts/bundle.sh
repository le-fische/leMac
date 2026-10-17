#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "==> Compiling in release mode..."
swift build -c release

APP_NAME="leWheel.app"
CONTENTS="$DIR/dist/$APP_NAME/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Creating macOS application bundle at dist/$APP_NAME..."
rm -rf "$DIR/dist/$APP_NAME"
mkdir -p "$MACOS" "$RESOURCES"

cp "$DIR/.build/release/OpenLaunchy" "$MACOS/OpenLaunchy"
chmod +x "$MACOS/OpenLaunchy"
cp "$DIR/Resources/Info.plist" "$CONTENTS/Info.plist"

if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
elif [ -f "$DIR/AppIcon.icns" ]; then
    cp "$DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

echo "==> Signing app bundle with ad-hoc signature..."
codesign --force --deep --sign - "$DIR/dist/$APP_NAME"

echo "==> Installing to /Applications/$APP_NAME..."
rm -rf "/Applications/$APP_NAME"
cp -R "$DIR/dist/$APP_NAME" "/Applications/$APP_NAME"

# Backwards compatibility symlinks
rm -rf "$DIR/dist/OpenLaunchy.app"
ln -sf "$DIR/dist/$APP_NAME" "$DIR/dist/OpenLaunchy.app"

echo "==> Done! leWheel.app is installed at /Applications/$APP_NAME"
