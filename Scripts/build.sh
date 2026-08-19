#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="OpenTaskbar"
APP_BUNDLE="${PROJECT_DIR}/build/${APP_NAME}.app"
ENTITLEMENTS="${PROJECT_DIR}/Resources/OpenTaskbar.entitlements"

locate_binary() {
    local candidates=(
        "${PROJECT_DIR}/.build/apple/Products/Release/${APP_NAME}"
        "${PROJECT_DIR}/.build/release/apple/Products/Release/${APP_NAME}"
        "${PROJECT_DIR}/.build/release/${APP_NAME}"
        "${PROJECT_DIR}/.build/${APP_NAME}/${APP_NAME}"
    )
    for candidate in "${candidates[@]}"; do
        if [ -f "${candidate}" ]; then
            echo "${candidate}"
            return 0
        fi
    done
    return 1
}

echo "Building ${APP_NAME}..."

BINARY=""
if swift build -c release --arch arm64 --arch x86_64 2>/tmp/opentaskbar-universal.log; then
    echo "  universal binary build succeeded"
else
    echo "  warning: universal build failed (see /tmp/opentaskbar-universal.log); falling back to native arch"
    swift build -c release
fi

if ! BINARY="$(locate_binary)"; then
    echo "error: could not locate the built binary" >&2
    exit 1
fi
echo "  binary: ${BINARY}"

echo "Creating app bundle..."
echo "Stopping running instance if any..."
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.5

echo "Removing previous app bundle to avoid popup..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${PROJECT_DIR}/Resources/OpenTaskbar.icns" "${APP_BUNDLE}/Contents/Resources/OpenTaskbar.icns"
cp "${PROJECT_DIR}/Resources/status-icon.png" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
cp "${PROJECT_DIR}/Resources/status-icon@2x.png" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
cp "${PROJECT_DIR}/Resources/status-icon@3x.png" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true

echo "Code signing..."
SIGN_IDENTITY="${OPENTASKBAR_SIGN_IDENTITY:-OpenTaskbarDev}"
try_sign() {
    codesign --force --sign "$1" \
        --entitlements "${ENTITLEMENTS}" \
        --options runtime \
        "${APP_BUNDLE}"
}
if security find-identity -v -p codesigning | grep -qF "${SIGN_IDENTITY}"; then
    if try_sign "${SIGN_IDENTITY}" 2>/tmp/opentaskbar-codesign.log; then
        echo "  signed with '${SIGN_IDENTITY}'"
    else
        echo "  warning: signing with '${SIGN_IDENTITY}' failed (see /tmp/opentaskbar-codesign.log); using ad-hoc signing"
        try_sign -
    fi
else
    echo "  (identity '${SIGN_IDENTITY}' not found — using ad-hoc signing)"
    try_sign -
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || echo "0.1.0")"
ZIP="${PROJECT_DIR}/build/${APP_NAME}-${VERSION}.zip"
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP}"

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo "Release artifact: ${ZIP}"
echo ""
echo "To run: open \"${APP_BUNDLE}\""
echo ""
echo "Important: You must grant Accessibility permission in System Settings > Privacy & Security > Accessibility"
echo "           for OpenTaskbar to work. The app will prompt you on first launch."