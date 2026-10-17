#!/usr/bin/env bash
set -e

APP_NAME="leCG"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

echo "==> Building ${APP_NAME} binary via Swift Package Manager..."
swift build -c release

echo "==> Constructing ${BUNDLE_DIR} bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"

cp -f ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [ -d ".build/release/Sparkle.framework" ]; then
    cp -R ".build/release/Sparkle.framework" "${FRAMEWORKS_DIR}/"
fi

cp Info.plist "${CONTENTS_DIR}/Info.plist"

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "==> Ad-hoc code signing..."
codesign --force --deep -s - "${BUNDLE_DIR}" 2>/dev/null || true

touch "${BUNDLE_DIR}"
echo "==> Successfully created ${BUNDLE_DIR}!"
