#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# leFan Release Packaging Script
# Compiles leFan and packages it into standalone drag-and-drop .dmg and .zip bundles.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
APP_NAME="leFan"

SKIP_BUILD=false
CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --skip-build)
            SKIP_BUILD=true
            ;;
        --clean)
            CLEAN=true
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-build] [--clean]"
            echo "  --skip-build  Use existing build artifacts instead of recompiling"
            echo "  --clean       Perform a clean build"
            exit 0
            ;;
    esac
done

echo "=== Packaging $APP_NAME Release ==="
echo "Script directory: $SCRIPT_DIR"
echo "Dist directory:   $DIST_DIR"

mkdir -p "$DIST_DIR"

if [ "$CLEAN" = true ]; then
    echo "--> Cleaning previous build artifacts..."
    rm -rf "$SCRIPT_DIR/.build" "$DIST_DIR"
    mkdir -p "$DIST_DIR"
fi

# Prepare temporary packaging staging area
WORK_DIR="$(mktemp -d /tmp/lefan_pack_XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

TARGET_APP="$WORK_DIR/$APP_NAME.app"

if [ "$SKIP_BUILD" = false ]; then
    echo "--> Building $APP_NAME (Release configuration)..."
    cd "$SCRIPT_DIR"
    swift build -c release

    if [ ! -f "$SCRIPT_DIR/.build/release/leFan" ] || [ ! -f "$SCRIPT_DIR/.build/release/lefan-helper" ]; then
        echo "Error: Release binaries not found in $SCRIPT_DIR/.build/release/" >&2
        exit 1
    fi
else
    if [ ! -f "$SCRIPT_DIR/.build/release/leFan" ] && [ ! -d "$SCRIPT_DIR/$APP_NAME.app" ] && [ ! -d "/Applications/$APP_NAME.app" ]; then
        echo "Error: No existing build found to package. Remove --skip-build to compile." >&2
        exit 1
    fi
fi

# Assemble .app bundle structure
echo "--> Assembling application bundle..."
if [ "$SKIP_BUILD" = true ] && [ -d "$SCRIPT_DIR/$APP_NAME.app" ]; then
    cp -R "$SCRIPT_DIR/$APP_NAME.app" "$TARGET_APP"
elif [ "$SKIP_BUILD" = true ] && [ -d "/Applications/$APP_NAME.app" ]; then
    cp -R "/Applications/$APP_NAME.app" "$TARGET_APP"
else
    CONTENTS="$TARGET_APP/Contents"
    MACOS="$CONTENTS/MacOS"
    RESOURCES="$CONTENTS/Resources"

    mkdir -p "$MACOS"
    mkdir -p "$RESOURCES"

    cp -f "$SCRIPT_DIR/.build/release/leFan" "$MACOS/leFan"
    cp -f "$SCRIPT_DIR/.build/release/lefan-helper" "$MACOS/lefan-helper"
    chmod +x "$MACOS/leFan" "$MACOS/lefan-helper"

    cp -f "$SCRIPT_DIR/Sources/Helper/install_helper.sh" "$RESOURCES/install_helper.sh"
    cp -f "$SCRIPT_DIR/Sources/Helper/com.le.lefan.helper.plist" "$RESOURCES/com.le.lefan.helper.plist"
    chmod +x "$RESOURCES/install_helper.sh"

    if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
        cp -f "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
    fi

    echo "APPL????" > "$CONTENTS/PkgInfo"

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
fi

# Apply ad-hoc signature
echo "--> Code signing bundle..."
codesign --force --deep --sign - "$TARGET_APP"

# Update local leFan.app bundle in project folder
rm -rf "$SCRIPT_DIR/$APP_NAME.app"
cp -R "$TARGET_APP" "$SCRIPT_DIR/$APP_NAME.app"

# 1. Create ZIP package
ZIP_OUTPUT="$DIST_DIR/$APP_NAME.zip"
echo "--> Creating $ZIP_OUTPUT..."
rm -f "$ZIP_OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$TARGET_APP" "$ZIP_OUTPUT"

# 2. Create Drag-and-Drop DMG package
DMG_STAGING="$WORK_DIR/dmg_root"
mkdir -p "$DMG_STAGING"
cp -R "$TARGET_APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

DMG_OUTPUT="$DIST_DIR/$APP_NAME.dmg"
echo "--> Creating $DMG_OUTPUT..."
rm -f "$DMG_OUTPUT"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_OUTPUT"

# 3. Generate SHA256 checksums
CHECKSUM_FILE="$DIST_DIR/checksums.txt"
echo "--> Generating checksums..."
(
    cd "$DIST_DIR"
    shasum -a 256 "$APP_NAME.dmg" "$APP_NAME.zip" > checksums.txt
    cp checksums.txt "${APP_NAME}-checksums.txt"
)

echo ""
echo "=== Packaging Complete! ==="
ls -lh "$DIST_DIR"
echo ""
echo "Checksums ($CHECKSUM_FILE):"
cat "$CHECKSUM_FILE"
