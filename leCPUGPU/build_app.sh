#!/usr/bin/env bash
set -e

APP_NAME="leCPUGPU"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building ${APP_NAME} binary..."
swiftc -O -target arm64-apple-macos14.0 \
    -framework AppKit \
    -framework IOKit \
    -framework ServiceManagement \
    Sources/*.swift \
    -o "${APP_NAME}"

echo "==> Constructing ${BUNDLE_DIR} bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

mv "${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp Info.plist "${CONTENTS_DIR}/Info.plist"

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "==> Ad-hoc code signing..."
codesign --force --deep -s - "${BUNDLE_DIR}" 2>/dev/null || true

touch "${BUNDLE_DIR}"
echo "==> Successfully created ${BUNDLE_DIR}!"
