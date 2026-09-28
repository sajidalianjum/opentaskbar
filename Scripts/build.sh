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

# The app bundle is assembled manually, so copy locale resources explicitly.
for localization in "${PROJECT_DIR}"/Resources/*.lproj; do
    if [ -d "${localization}" ]; then
        ditto "${localization}" "${APP_BUNDLE}/Contents/Resources/$(basename "${localization}")"
    fi
done

echo "Code signing..."
# Prefer a stable signing identity automatically. macOS keys the Accessibility
# (TCC) grant to the app's code requirement; ad-hoc signing changes that on
# every rebuild, so the user would have to re-grant permission after each
# update. Nothing needs configuring — the first available identity wins:
#   OPENTASKBAR_SIGN_IDENTITY (optional override) > Developer ID Application >
#   Apple Development > OpenTaskbarDev (see Scripts/setup-signing.sh) > ad-hoc
# `find-identity -v` lists only *trusted* identities; a self-signed identity
# imported in CI is still usable by codesign, so we also consult the unfiltered
# list as a fallback.
IDENTITIES_VALID="$(security find-identity -v -p codesigning 2>/dev/null || true)"
IDENTITIES_ALL="$(security find-identity -p codesigning 2>/dev/null || true)"
pick_identity() {
    local source found
    for source in "${IDENTITIES_VALID}" "${IDENTITIES_ALL}"; do
        found="$(printf '%s\n' "${source}" | grep -o '"[^"]*"' | tr -d '"' | grep -m1 "$1" || true)"
        if [ -n "${found}" ]; then
            printf '%s' "${found}"
            return
        fi
    done
    printf '%s' ""
}
resolve_sign_identity() {
    if [ -n "${OPENTASKBAR_SIGN_IDENTITY:-}" ]; then
        printf '%s' "${OPENTASKBAR_SIGN_IDENTITY}"
        return
    fi
    local pattern found
    for pattern in "Developer ID Application" "Apple Development" "OpenTaskbarDev"; do
        found="$(pick_identity "${pattern}")"
        if [ -n "${found}" ]; then
            printf '%s' "${found}"
            return
        fi
    done
    printf '%s' ""
}
try_sign() {
    codesign --force --sign "$1" \
        --entitlements "${ENTITLEMENTS}" \
        --options runtime \
        "${APP_BUNDLE}"
}
SIGN_IDENTITY="$(resolve_sign_identity)"
if [ -n "${SIGN_IDENTITY}" ]; then
    if try_sign "${SIGN_IDENTITY}" 2>/tmp/opentaskbar-codesign.log; then
        echo "  signed with '${SIGN_IDENTITY}'"
    else
        echo "  warning: signing with '${SIGN_IDENTITY}' failed (see /tmp/opentaskbar-codesign.log); using ad-hoc signing"
        try_sign -
    fi
else
    echo "  using ad-hoc signing (no stable identity found)"
    try_sign -
fi

SIGNATURE_KIND="$(codesign -dv "${APP_BUNDLE}" 2>&1 | awk -F'=' '/^Signature/{print $2}')"
if [ "${SIGNATURE_KIND}" = "adhoc" ]; then
    echo "  note: ad-hoc builds change identity on every rebuild, so macOS invalidates a"
    echo "        previously granted Accessibility permission. Run Scripts/setup-signing.sh"
    echo "        once for a stable local identity. Releases built in CI stay ad-hoc and"
    echo "        rely on Scripts/install.sh clearing the stale grant on update."
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || echo "0.1.0")"
ZIP="${PROJECT_DIR}/build/${APP_NAME}-${VERSION}.zip"
# Version-less alias so installers can use the stable `releases/latest/download` URL.
ALIAS="${PROJECT_DIR}/build/${APP_NAME}.zip"
rm -f "${ZIP}" "${ALIAS}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP}"
cp -f "${ZIP}" "${ALIAS}"

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo "Release artifact: ${ZIP}"
echo "Stable alias:     ${ALIAS}"
echo ""
echo "To run: open \"${APP_BUNDLE}\""
echo ""
echo "Important: You must grant Accessibility permission in System Settings > Privacy & Security > Accessibility"
echo "           for OpenTaskbar to work. The app will prompt you on first launch."