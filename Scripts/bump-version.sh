#!/bin/bash
set -euo pipefail

# Usage: Scripts/bump-version.sh [patch|minor|major|<x.y.z>]
#
# Computes the next version from the newest v* git tag (falling back to the
# current CFBundleShortVersionString when there is no tag), applies the bump, and
# writes it to CFBundleShortVersionString + CFBundleVersion in Resources/Info.plist.
# Prints the resulting version on stdout.
#
# An explicit x.y.z argument is used verbatim and ignores the bump keyword. This
# edits the working tree only; the caller decides whether to commit.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${PROJECT_DIR}"
INFO_PLIST="Resources/Info.plist"

BUMP="${1:-patch}"

current_tag="$(git tag --list 'v*' --sort=-v:refname | head -1 || true)"
current_tag="${current_tag#v}"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}" 2>/dev/null || echo '0.0.0')"

newer() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

# The base is whichever of the newest tag / Info.plist version is greater, so a
# manual bump is never rolled back.
BASE="${plist_version}"
if [ -n "${current_tag}" ] && newer "${current_tag}" "${plist_version}"; then
    BASE="${current_tag}"
fi

# Strip prerelease/build metadata before doing arithmetic on the core numbers.
CORE="${BASE%%-*}"
CORE="${CORE%%+*}"
IFS='.' read -r major minor patch <<< "${CORE}"
case "${major:-}" in ''|*[!0-9]*) major=0 ;; esac
case "${minor:-}" in ''|*[!0-9]*) minor=0 ;; esac
case "${patch:-}" in ''|*[!0-9]*) patch=0 ;; esac

case "${BUMP}" in
    patch)                VERSION="${major}.$((minor)).$((patch + 1))" ;;
    minor)                VERSION="${major}.$((minor + 1)).0" ;;
    major)                VERSION="$((major + 1)).0.0" ;;
    [0-9]*.[0-9]*.[0-9]*) VERSION="${BUMP}" ;;
    *)
        echo "error: invalid bump '${BUMP}' (expected patch, minor, major, or x.y.z)" >&2
        exit 1
        ;;
esac

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${INFO_PLIST}"

printf '%s\n' "${VERSION}"
