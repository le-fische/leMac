#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "==> Building release binaries for leFan..."
swift build -c release

APP_NAME="leFan.app"
APP_DIR="$DIR/$APP_NAME"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Creating bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

echo "==> Copying executables..."
cp -f "$DIR/.build/release/leFan" "$MACOS/leFan"
cp -f "$DIR/.build/release/lefan-helper" "$MACOS/lefan-helper"
chmod +x "$MACOS/leFan"
chmod +x "$MACOS/lefan-helper"

echo "==> Copying helper assets and icon..."
cp -f "$DIR/Sources/Helper/install_helper.sh" "$RESOURCES/install_helper.sh"
cp -f "$DIR/Sources/Helper/com.le.lefan.helper.plist" "$RESOURCES/com.le.lefan.helper.plist"
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp -f "$DIR/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi
chmod +x "$RESOURCES/install_helper.sh"

echo "==> Generating PkgInfo..."
echo "APPL????" > "$CONTENTS/PkgInfo"

echo "==> Generating Info.plist..."
cat << 'EOF' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>leFan</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.le.lefan</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>leFan</string>
    <key>CFBundleDisplayName</key>
    <string>leFan</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Ad-hoc signing app bundle..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "==> Installing to /Applications/leFan.app..."
rm -rf "/Applications/leFan.app"
cp -R "$APP_DIR" "/Applications/leFan.app"

echo "==> Triggering Spotlight and LaunchServices registration..."
touch "/Applications/leFan.app"
mdimport "/Applications/leFan.app" 2>/dev/null || true

echo "==> Done! leFan is installed and indexed in /Applications/leFan.app"
