#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# leMinibar Release Packaging Script
# Compiles leMinibar and packages it into standalone .dmg and .zip bundles.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
APP_NAME="leMinibar"

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
    
    if [ "$CLEAN" = true ]; then
        rm -rf "$SCRIPT_DIR/leMinibar.app"
    fi
    
    chmod +x "$SCRIPT_DIR/build.sh"
    "$SCRIPT_DIR/build.sh"
    
    COMPILED_APP="$SCRIPT_DIR/leMinibar.app"
    if [ ! -d "$COMPILED_APP" ]; then
        echo "Error: Compiled application not found at $COMPILED_APP" >&2
        exit 1
    fi
    STAGING_APP="$COMPILED_APP"
else
    if [ -d "$SCRIPT_DIR/leMinibar.app" ]; then
        STAGING_APP="$SCRIPT_DIR/leMinibar.app"
    elif [ -d "/Applications/$APP_NAME.app" ]; then
        STAGING_APP="/Applications/$APP_NAME.app"
    else
        echo "Error: No existing build found to package. Remove --skip-build to compile." >&2
        exit 1
    fi
fi

# Prepare temporary packaging staging area
WORK_DIR="$(mktemp -d /tmp/leminibar_pack_XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

TARGET_APP="$WORK_DIR/$APP_NAME.app"
echo "--> Staging application bundle to $TARGET_APP..."
cp -R "$STAGING_APP" "$TARGET_APP"

# Copy high-resolution AppIcon if available
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    echo "--> Installing high-resolution AppIcon.icns..."
    mkdir -p "$TARGET_APP/Contents/Resources"
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$TARGET_APP/Contents/Resources/AppIcon.icns"
fi

# Apply local ad-hoc signature
echo "--> Code signing bundle..."
codesign --force --deep --sign - "$TARGET_APP"

# 1. Create ZIP package
ZIP_OUTPUT="$DIST_DIR/$APP_NAME.zip"
echo "--> Creating $ZIP_OUTPUT..."
rm -f "$ZIP_OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$TARGET_APP" "$ZIP_OUTPUT"

# 2. Create DMG package (Drag-and-Drop installer)
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
CHECKSUM_NAMED_FILE="$DIST_DIR/$APP_NAME-checksums.txt"
echo "--> Generating checksums..."
(
    cd "$DIST_DIR"
    shasum -a 256 "$APP_NAME.dmg" "$APP_NAME.zip" > checksums.txt
    cp checksums.txt "$APP_NAME-checksums.txt"
)

echo ""
echo "=== Packaging Complete! ==="
ls -lh "$DIST_DIR"
echo ""
echo "Checksums ($CHECKSUM_FILE):"
cat "$CHECKSUM_FILE"
