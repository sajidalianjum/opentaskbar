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
    UNIVERSAL_BINARY="${BUILD_DIR}/${APP_NAME}"
fi

echo "Creating app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${UNIVERSAL_BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

echo "Code signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo ""
echo "To run: open \"${APP_BUNDLE}\""
echo ""
echo "Important: You must grant Accessibility permission in System Settings > Privacy & Security > Accessibility"
echo "           for OpenTaskbar to work. The app will prompt you on first launch."