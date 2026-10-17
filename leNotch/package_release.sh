#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# leNotch Release Packaging Script
# Compiles leNotch and packages it into standalone .dmg and .zip bundles.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="leNotch"

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

STAGING_APP=""

if [ "$SKIP_BUILD" = false ]; then
    echo "--> Building $APP_NAME (Release configuration)..."
    
    XCODE_BUILD_ARGS=(
        -project "$SCRIPT_DIR/boringNotch.xcodeproj"
        -scheme "boringNotch"
        -configuration "Release"
        -derivedDataPath "$BUILD_DIR"
        CODE_SIGNING_ALLOWED=NO
    )
    
    if [ "$CLEAN" = true ]; then
        xcodebuild "${XCODE_BUILD_ARGS[@]}" clean
    fi
    
    xcodebuild "${XCODE_BUILD_ARGS[@]}" build
    
    COMPILED_APP="$BUILD_DIR/Build/Products/Release/boringNotch.app"
    if [ ! -d "$COMPILED_APP" ]; then
        echo "Error: Compiled application not found at $COMPILED_APP" >&2
        exit 1
    fi
    STAGING_APP="$COMPILED_APP"
else
    if [ -d "$BUILD_DIR/Build/Products/Release/boringNotch.app" ]; then
        STAGING_APP="$BUILD_DIR/Build/Products/Release/boringNotch.app"
    elif [ -d "/Applications/$APP_NAME.app" ]; then
        STAGING_APP="/Applications/$APP_NAME.app"
    else
        echo "Error: No existing build found to package. Remove --skip-build to compile." >&2
        exit 1
    fi
fi

# Prepare temporary packaging staging area
WORK_DIR="$(mktemp -d /tmp/lenotch_pack_XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

TARGET_APP="$WORK_DIR/$APP_NAME.app"
echo "--> Staging application bundle to $TARGET_APP..."
cp -R "$STAGING_APP" "$TARGET_APP"

# Copy high-resolution AppIcon if available
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    echo "--> Installing high-resolution AppIcon.icns..."
    cp "$SCRIPT_DIR/AppIcon.icns" "$TARGET_APP/Contents/Resources/AppIcon.icns"
fi

# Apply local ad-hoc signature
echo "--> Code signing bundle..."
codesign --force --deep --sign - "$TARGET_APP"

# 1. Create ZIP package
ZIP_OUTPUT="$DIST_DIR/$APP_NAME.zip"
echo "--> Creating $ZIP_OUTPUT..."
rm -f "$ZIP_OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$TARGET_APP" "$ZIP_OUTPUT"

# 2. Create DMG package
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
)

# 4. Sign update with Sparkle and update appcast.xml
SIGN_SCRIPT="$SCRIPT_DIR/Configuration/sparkle/sign_update.swift"
APPCAST_FILE="$SCRIPT_DIR/appcast.xml"
if [ -f "$SIGN_SCRIPT" ]; then
    VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$TARGET_APP/Contents/Info.plist" 2>/dev/null || echo "2.7.3")"
    BUILD_NUM="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$TARGET_APP/Contents/Info.plist" 2>/dev/null || echo "271")"
    echo "--> Signing Sparkle update archive and updating appcast (v$VERSION build $BUILD_NUM)..."
    "$SIGN_SCRIPT" --archive "$ZIP_OUTPUT" --version "$VERSION" --build "$BUILD_NUM" --appcast "$APPCAST_FILE"
fi

echo ""
echo "=== Packaging Complete! ==="
ls -lh "$DIST_DIR"
echo ""
echo "Checksums ($CHECKSUM_FILE):"
cat "$CHECKSUM_FILE"
