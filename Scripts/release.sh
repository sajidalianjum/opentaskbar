#!/bin/bash
set -euo pipefail

# Builds the distribution artifact and prints the exact commands to publish it.
#
# Usage:
#   ./Scripts/release.sh                  # build + print publish instructions
#   OPENTASKBAR_PUBLISH=1 ./Scripts/release.sh   # build + publish via `gh` if available
#
# Requires: Xcode Command Line Tools (swift), codesign. No Apple Developer ID needed.
# build.sh signs with a stable identity when one is available and otherwise falls
# back to ad-hoc. Prefer the `curl` installer (Scripts/install.sh), which avoids
# the macOS quarantine attribute entirely; users who download the zip through a
# browser must unblock the first launch manually (see README).

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"${PROJECT_DIR}/Scripts/build.sh"

APP_NAME="OpenTaskbar"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${PROJECT_DIR}/build/${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || echo "0.1.0")"
ZIP="${PROJECT_DIR}/build/${APP_NAME}-${VERSION}.zip"
# Version-less alias so the installer can use `releases/latest/download/OpenTaskbar.zip`.
ALIAS="${PROJECT_DIR}/build/${APP_NAME}.zip"

echo ""
echo "=============================================================="
echo "Release artifact ready:"
echo "  ${ZIP}"
echo ""

if [ "${OPENTASKBAR_PUBLISH:-0}" = "1" ]; then
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        NOTES_FILE="${PROJECT_DIR}/build/release-notes-${VERSION}.md"
        "${PROJECT_DIR}/Scripts/release-notes.sh" "${VERSION}" > "${NOTES_FILE}"
        echo "Publishing v${VERSION} via gh..."
        gh release create "v${VERSION}" "${ZIP}" "${ALIAS}" "${PROJECT_DIR}/Scripts/install.sh" \
            --title "OpenTaskbar ${VERSION}" \
            --notes-file "${NOTES_FILE}"
        echo "Published: https://github.com/${OPENTASKBAR_OWNER:-sajidalianjum}/opentaskbar/releases/tag/v${VERSION}"
    else
        echo "error: OPENTASKBAR_PUBLISH=1 requires the GitHub CLI (gh) to be installed and authenticated." >&2
        echo "  Install:  brew install gh && gh auth login" >&2
        echo "  Or publish manually with the commands below." >&2
        exit 1
    fi
else
    NOTES_FILE="${PROJECT_DIR}/build/release-notes-${VERSION}.md"
    "${PROJECT_DIR}/Scripts/release-notes.sh" "${VERSION}" > "${NOTES_FILE}"
    echo "Release notes written to ${NOTES_FILE} (generated from commits since the previous tag)."
    echo "Publish it manually with:"
    echo "  gh release create v${VERSION} \"${ZIP}\" \"${ALIAS}\" Scripts/install.sh \\
  --title \"OpenTaskbar ${VERSION}\" \\
  --notes-file \"${NOTES_FILE}\""
    echo ""
    echo "(Or upload ${ZIP} at https://github.com/sajidalianjum/opentaskbar/releases/new)"
    echo "=============================================================="
fi