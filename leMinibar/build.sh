#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_BUNDLE="$DIR/leMinibar.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
LOCAL_FRAMEWORKS="$DIR/Frameworks"

echo "Building leMinibar..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$LOCAL_FRAMEWORKS"

cp "$DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "/private/tmp/minibar.iconset/icon_512x512.png" ]; then
    iconutil -c icns /private/tmp/minibar.iconset -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
fi

# Ensure Sparkle.framework is available in $LOCAL_FRAMEWORKS
if [ ! -d "$LOCAL_FRAMEWORKS/Sparkle.framework" ]; then
    MONOREPO_SPARKLE="$DIR/../build/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
    if [ -d "$MONOREPO_SPARKLE" ]; then
        echo "--> Copying Sparkle.framework from monorepo artifacts..."
        cp -R "$MONOREPO_SPARKLE" "$LOCAL_FRAMEWORKS/"
    else
        echo "--> Downloading Sparkle 2.6.4 release framework..."
        TEMP_SPARKLE="$(mktemp -d /tmp/sparkle_dl_XXXXXX)"
        curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz" | tar -xJ -C "$TEMP_SPARKLE"
        cp -R "$TEMP_SPARKLE/Sparkle.framework" "$LOCAL_FRAMEWORKS/"
        rm -rf "$TEMP_SPARKLE"
    fi
fi

# Bundle Sparkle.framework into the application bundle
echo "--> Bundling Sparkle.framework into application bundle..."
rm -rf "$FRAMEWORKS_DIR/Sparkle.framework"
cp -R "$LOCAL_FRAMEWORKS/Sparkle.framework" "$FRAMEWORKS_DIR/"

swiftc -O \
    "$DIR/Sources/Preferences.swift" \
    "$DIR/Sources/AppDelegate.swift" \
    "$DIR/Sources/main.swift" \
    -F "$LOCAL_FRAMEWORKS" \
    -framework Cocoa \
    -framework ServiceManagement \
    -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -o "$MACOS_DIR/leMinibar"

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Successfully built $APP_BUNDLE"
