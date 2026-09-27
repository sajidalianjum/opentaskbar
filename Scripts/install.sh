#!/bin/bash
set -euo pipefail

# OpenTaskbar installer.
#
# Downloads the latest (or a pinned) GitHub release with curl, which — unlike a
# browser download — never applies the macOS quarantine attribute. The app is
# therefore not blocked by Gatekeeper on first launch, even though it is only
# ad-hoc signed. The quarantine attribute is also stripped defensively in case
# the archive was fetched by something that does set it.
#
# Usage:
#   curl -fsSL https://github.com/<owner>/opentaskbar/releases/latest/download/install.sh | bash
#   ./Scripts/install.sh
#
# Environment overrides:
#   OPENTASKBAR_OWNER        GitHub owner            (default: sajidalianjum)
#   OPENTASKBAR_VERSION      Pin a release, e.g. 0.1.0
#   OPENTASKBAR_INSTALL_DIR  Install location        (default: /Applications, then ~/Applications)
#   OPENTASKBAR_SHA256       Expected sha256 of the downloaded zip
#   OPENTASKBAR_URL          Force a download URL (mirrors, local testing)
#
# Uninstall:  rm -rf "/Applications/OpenTaskbar.app"   (settings live in UserDefaults)

APP_NAME="OpenTaskbar"
OWNER="${OPENTASKBAR_OWNER:-sajidalianjum}"
REPO="opentaskbar"

STABLE_URL="https://github.com/${OWNER}/${REPO}/releases/latest/download/${APP_NAME}.zip"
API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
fi

command -v curl  >/dev/null 2>&1 || die "curl is required"
command -v ditto >/dev/null 2>&1 || die "ditto is required (part of macOS)"

# --- Pick an install location -------------------------------------------------
if [ -n "${OPENTASKBAR_INSTALL_DIR:-}" ]; then
    INSTALL_DIR="${OPENTASKBAR_INSTALL_DIR}"
elif [ -w /Applications ]; then
    INSTALL_DIR="/Applications"
else
    INSTALL_DIR="${HOME}/Applications"
    log "note: /Applications is not writable; installing to ${INSTALL_DIR}"
fi
mkdir -p "${INSTALL_DIR}" || die "could not create ${INSTALL_DIR}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opentaskbar-install.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

# --- Resolve the download URL -------------------------------------------------
resolve_url() {
    if [ -n "${OPENTASKBAR_URL:-}" ]; then
        printf '%s' "${OPENTASKBAR_URL}"
        return 0
    fi

    if [ -n "${OPENTASKBAR_VERSION:-}" ]; then
        local version="${OPENTASKBAR_VERSION#v}"
        printf '%s' "https://github.com/${OWNER}/${REPO}/releases/download/v${version}/${APP_NAME}-${version}.zip"
        return 0
    fi

    # Preferred: the version-less release asset (fast, no API rate limit).
    if curl -fsIL "${STABLE_URL}" >/dev/null 2>&1; then
        printf '%s' "${STABLE_URL}"
        return 0
    fi

    # Fallback for older releases that only carry a versioned asset.
    local json url
    if json="$(curl -fsSL "${API_URL}" 2>/dev/null)"; then
        url="$(printf '%s' "${json}" | tr ',' '\n' \
            | grep -o "https://[^\"]*${APP_NAME}\.zip" | head -1)"
        if [ -z "${url}" ]; then
            url="$(printf '%s' "${json}" | tr ',' '\n' \
                | grep -o "https://[^\"]*${APP_NAME}-[0-9][^\"]*\.zip" | head -1)"
        fi
        if [ -n "${url}" ]; then
            printf '%s' "${url}"
            return 0
        fi
    fi

    die "could not resolve the latest release; retry with OPENTASKBAR_VERSION=<version>"
}

URL="$(resolve_url)"
log "Downloading ${URL}"
ZIP="${TMP_DIR}/${APP_NAME}.zip"
curl -fSL --retry 3 --retry-delay 1 -o "${ZIP}" "${URL}" || die "download failed"

# --- Optional integrity check -------------------------------------------------
if [ -n "${OPENTASKBAR_SHA256:-}" ]; then
    actual="$(shasum -a 256 "${ZIP}" | awk '{print $1}')"
    if [ "${actual}" != "${OPENTASKBAR_SHA256}" ]; then
        die "checksum mismatch: expected ${OPENTASKBAR_SHA256}, got ${actual}"
    fi
    log "Checksum verified"
fi

# --- Unpack -------------------------------------------------------------------
log "Unpacking..."
UNPACKED="${TMP_DIR}/unpacked"
mkdir -p "${UNPACKED}"
ditto -x -k "${ZIP}" "${UNPACKED}" || die "failed to unpack ${ZIP}"

APP_SRC="${UNPACKED}/${APP_NAME}.app"
[ -d "${APP_SRC}" ] || die "archive did not contain ${APP_NAME}.app"

# --- Install ------------------------------------------------------------------
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.3

DEST="${INSTALL_DIR}/${APP_NAME}.app"
rm -rf "${DEST}"
ditto "${APP_SRC}" "${DEST}" || die "failed to install to ${DEST}"

# curl never sets quarantine, but be explicit so the first launch is never blocked.
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true

log ""
log "Installed ${APP_NAME} to ${DEST}"
log ""
log "Next steps:"
log "  1. Open ${APP_NAME} (Spotlight, Launchpad, or: open \"${DEST}\")."
log "  2. Grant Accessibility permission when prompted — required."
log "  3. Optionally grant Screen Recording for hover thumbnails."
log ""
log "Updating: re-run this script. Because release builds are ad-hoc signed, you"
log "may need to re-grant Accessibility / Screen Recording after an update."
