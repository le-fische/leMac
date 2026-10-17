#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# leFan Release Packaging Script
# Compiles leFan and packages it into standalone drag-and-drop .dmg and .zip bundles.
# Signs release archive with Curve25519 and updates Sparkle appcast.xml feed.
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
    FRAMEWORKS="$CONTENTS/Frameworks"

    mkdir -p "$MACOS"
    mkdir -p "$RESOURCES"
    mkdir -p "$FRAMEWORKS"

    cp -f "$SCRIPT_DIR/.build/release/leFan" "$MACOS/leFan"
    cp -f "$SCRIPT_DIR/.build/release/lefan-helper" "$MACOS/lefan-helper"
    chmod +x "$MACOS/leFan" "$MACOS/lefan-helper"

    # Copy Sparkle framework
    SPARKLE_SRC=""
    if [ -d "$SCRIPT_DIR/.build/release/Sparkle.framework" ]; then
        SPARKLE_SRC="$SCRIPT_DIR/.build/release/Sparkle.framework"
    elif [ -d "$SCRIPT_DIR/.build/arm64-apple-macosx/release/Sparkle.framework" ]; then
        SPARKLE_SRC="$SCRIPT_DIR/.build/arm64-apple-macosx/release/Sparkle.framework"
    elif [ -d "$SCRIPT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" ]; then
        SPARKLE_SRC="$SCRIPT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
    fi

    if [ -n "$SPARKLE_SRC" ]; then
        echo "--> Copying Sparkle framework from $SPARKLE_SRC..."
        cp -R "$SPARKLE_SRC" "$FRAMEWORKS/"
        install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/leFan" 2>/dev/null || true
    fi

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
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/le-fische/leMac/main/leFan/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>a24A4iOxvUr/i64Tjz3q8qraXdawXglnVQwKOV1DZMw=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>SUEnableDownloaderService</key>
    <true/>
    <key>SUEnableInstallerLauncherService</key>
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

# 4. Sign update with Sparkle and update appcast.xml
SIGN_SCRIPT="$SCRIPT_DIR/Configuration/sparkle/sign_update.swift"
APPCAST_FILE="$SCRIPT_DIR/appcast.xml"
if [ -f "$SIGN_SCRIPT" ]; then
    VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$TARGET_APP/Contents/Info.plist" 2>/dev/null || echo "1.0.0")"
    BUILD_NUM="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$TARGET_APP/Contents/Info.plist" 2>/dev/null || echo "1")"
    echo "--> Signing Sparkle update archive and updating appcast (v$VERSION build $BUILD_NUM)..."
    "$SIGN_SCRIPT" --archive "$ZIP_OUTPUT" --version "$VERSION" --build "$BUILD_NUM" --appcast "$APPCAST_FILE"
fi

echo ""
echo "=== Packaging Complete! ==="
ls -lh "$DIST_DIR"
echo ""
echo "Checksums ($CHECKSUM_FILE):"
cat "$CHECKSUM_FILE"
