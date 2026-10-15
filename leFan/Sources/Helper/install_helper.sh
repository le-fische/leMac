#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPER_BIN="$DIR/lefan-helper"

if [ ! -f "$HELPER_BIN" ]; then
    if [ -f "$DIR/../../.build/release/lefan-helper" ]; then
        HELPER_BIN="$DIR/../../.build/release/lefan-helper"
    elif [ -f "$DIR/../../.build/debug/lefan-helper" ]; then
        HELPER_BIN="$DIR/../../.build/debug/lefan-helper"
    elif [ -f "$DIR/../MacOS/lefan-helper" ]; then
        HELPER_BIN="$DIR/../MacOS/lefan-helper"
    fi
fi

if [ ! -f "$HELPER_BIN" ]; then
    echo "Helper binary not found at $HELPER_BIN"
    exit 1
fi

DEST_DIR="/Library/PrivilegedHelperTools"
DEST_BIN="$DEST_DIR/com.le.lefan.helper"
PLIST_SRC="$DIR/com.le.lefan.helper.plist"
PLIST_DEST="/Library/LaunchDaemons/com.le.lefan.helper.plist"

mkdir -p "$DEST_DIR"
mkdir -p "/Library/LaunchDaemons"

launchctl bootout system/com.le.lefan.helper 2>/dev/null || true
launchctl unload "$PLIST_DEST" 2>/dev/null || true

cp -f "$HELPER_BIN" "$DEST_BIN"
chown root:wheel "$DEST_BIN"
chmod 755 "$DEST_BIN"

cp -f "$PLIST_SRC" "$PLIST_DEST"
chown root:wheel "$PLIST_DEST"
chmod 644 "$PLIST_DEST"

launchctl bootstrap system "$PLIST_DEST" 2>/dev/null || launchctl load -w "$PLIST_DEST" 2>/dev/null || true

echo "leFan helper successfully installed and started."
