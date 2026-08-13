#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build/release"
APP_NAME="OpenTaskbar"
APP_BUNDLE="${PROJECT_DIR}/build/${APP_NAME}.app"

echo "Building ${APP_NAME}..."
swift build -c release

UNIVERSAL_BINARY="${BUILD_DIR}/apple/Products/Release/${APP_NAME}"
if [ ! -f "${UNIVERSAL_BINARY}" ]; then
    UNIVERSAL_BINARY="${BUILD_DIR}/${APP_NAME}"
fi

echo "Creating app bundle..."
echo "Stopping running instance if any..."
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.5

echo "Removing previous app bundle to avoid popup..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${UNIVERSAL_BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${PROJECT_DIR}/Resources/OpenTaskbar.icns" "${APP_BUNDLE}/Contents/Resources/OpenTaskbar.icns"
cp "${PROJECT_DIR}/Resources/status-icon.png" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
cp "${PROJECT_DIR}/Resources/status-icon@2x.png" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
cp "${PROJECT_DIR}/Resources/status-icon@3x.png" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true

echo "Code signing..."
SIGN_IDENTITY="${OPENTASKBAR_SIGN_IDENTITY:-OpenTaskbarDev}"
if security find-identity -v -p codesigning | grep -qF "${SIGN_IDENTITY}"; then
    codesign --force --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
else
    echo "  (identity '${SIGN_IDENTITY}' not found — falling back to ad-hoc signing)"
    codesign --force --sign - "${APP_BUNDLE}"
fi

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo ""
echo "To run: open \"${APP_BUNDLE}\""
echo ""
echo "Important: You must grant Accessibility permission in System Settings > Privacy & Security > Accessibility"
echo "           for OpenTaskbar to work. The app will prompt you on first launch."