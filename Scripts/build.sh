#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build/release"
APP_NAME="OpenTaskbar"
APP_BUNDLE="${PROJECT_DIR}/build/${APP_NAME}.app"

echo "Building ${APP_NAME}..."
swift build -c release --arch arm64 --arch x86_64 2>/dev/null || swift build -c release

UNIVERSAL_BINARY="${BUILD_DIR}/${APP_NAME}"
if [ ! -f "${UNIVERSAL_BINARY}" ]; then
    UNIVERSAL_BINARY="${PROJECT_DIR}/.build/apple/Products/Release/${APP_NAME}"
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

echo "Code signing..."
codesign --force --deep --sign "OpenTaskbarDev" "${APP_BUNDLE}"

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo ""
echo "To run: open \"${APP_BUNDLE}\""
echo ""
echo "Important: You must grant Accessibility permission in System Settings > Privacy & Security > Accessibility"
echo "           for OpenTaskbar to work. The app will prompt you on first launch."