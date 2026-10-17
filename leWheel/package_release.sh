#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# leWheel Release Packaging Script
# Compiles leWheel and packages it into standalone .dmg and .zip bundles.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
APP_NAME="leWheel"

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
    echo "--> Building $APP_NAME (Release configuration via Swift Package Manager)..."
    
    if [ "$CLEAN" = true ]; then
        rm -rf "$SCRIPT_DIR/.build"
    fi
    
    (
        cd "$SCRIPT_DIR"
        swift build -c release
    )
    
    COMPILED_BIN="$SCRIPT_DIR/.build/release/OpenLaunchy"
    if [ ! -f "$COMPILED_BIN" ]; then
        echo "Error: Compiled binary not found at $COMPILED_BIN" >&2
        exit 1
    fi
    
    # Assemble .app bundle in dist/leWheel.app
    COMPILED_APP="$DIST_DIR/$APP_NAME.app"
    CONTENTS="$COMPILED_APP/Contents"
    MACOS="$CONTENTS/MacOS"
    RESOURCES="$CONTENTS/Resources"
    
    rm -rf "$COMPILED_APP"
    mkdir -p "$MACOS" "$RESOURCES"
    
    cp "$COMPILED_BIN" "$MACOS/OpenLaunchy"
    chmod +x "$MACOS/OpenLaunchy"
    cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
    
    if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
        cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
    elif [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
        cp "$SCRIPT_DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"
    fi
    
    # Backwards compatibility symlink
    rm -rf "$DIST_DIR/OpenLaunchy.app"
    ln -sf "$APP_NAME.app" "$DIST_DIR/OpenLaunchy.app"
    
    STAGING_APP="$COMPILED_APP"
else
    if [ -d "$DIST_DIR/$APP_NAME.app" ]; then
        STAGING_APP="$DIST_DIR/$APP_NAME.app"
    elif [ -d "/Applications/$APP_NAME.app" ]; then
        STAGING_APP="/Applications/$APP_NAME.app"
    else
        echo "Error: No existing build found to package. Remove --skip-build to compile." >&2
        exit 1
    fi
fi

# Prepare temporary packaging staging area
WORK_DIR="$(mktemp -d /tmp/lewheel_pack_XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

TARGET_APP="$WORK_DIR/$APP_NAME.app"
echo "--> Staging application bundle to $TARGET_APP..."
cp -R "$STAGING_APP" "$TARGET_APP"

# Apply local ad-hoc signature
echo "--> Code signing bundle..."
codesign --force --deep --sign - "$TARGET_APP"

# 1. Create ZIP package
ZIP_OUTPUT="$DIST_DIR/$APP_NAME.zip"
echo "--> Creating $ZIP_OUTPUT..."
rm -f "$ZIP_OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$TARGET_APP" "$ZIP_OUTPUT"

# 2. Create drag-and-drop DMG package
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
