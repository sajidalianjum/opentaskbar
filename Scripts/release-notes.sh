#!/bin/bash
set -euo pipefail

# Prints Markdown release notes to stdout.
#
# GitHub's built-in "auto-generate release notes" only lists *merged pull
# requests*, so a repo that pushes commits straight to the default branch gets
# nothing but a "Full Changelog" link. This script builds the notes from the
# commits instead, grouped into Features / Fixes / Other, with a commit link on
# every line and a compare link to the previous tag.
#
# Usage:
#   ./Scripts/release-notes.sh [VERSION] [PREVIOUS_TAG]
#
# VERSION defaults to CFBundleShortVersionString in Resources/Info.plist.
# PREVIOUS_TAG defaults to the newest reachable v* tag that is not VERSION.
#
# Environment:
#   OPENTASKBAR_OWNER   GitHub owner (default: sajidalianjum)
#   OPENTASKBAR_REPO    GitHub repository name (default: opentaskbar)

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo '0.0.0')}"
VERSION="${VERSION#v}"
TAG="v${VERSION}"

OWNER="${OPENTASKBAR_OWNER:-sajidalianjum}"
REPO="${OPENTASKBAR_REPO:-opentaskbar}"

# Previous release tag: newest v* tag reachable from HEAD, excluding the tag for
# the version being released.
PREV="${2:-}"
if [ -z "${PREV}" ]; then
    for candidate in $(git tag --list 'v*' --sort=-v:refname); do
        [ "${candidate}" = "${TAG}" ] && continue
        if git merge-base --is-ancestor "${candidate}" HEAD 2>/dev/null; then
            PREV="${candidate}"
            break
        fi
    done
fi

if [ -n "${PREV}" ]; then
    RANGE="${PREV}..HEAD"
    CHANGELOG_URL="https://github.com/${OWNER}/${REPO}/compare/${PREV}...${TAG}"
else
    RANGE="HEAD"
    CHANGELOG_URL="https://github.com/${OWNER}/${REPO}/commits/${TAG}"
fi

FEATURES=""
FIXES=""
OTHER=""

while IFS=$'\t' read -r hash subject; do
    [ -z "${hash}" ] && continue
    entry="- ${subject} ([${hash}](https://github.com/${OWNER}/${REPO}/commit/${hash}))"
    lower="$(printf '%s' "${subject}" | tr '[:upper:]' '[:lower:]')"
    case "${lower}" in
        feat:*|feat\(*|feat\ *|feature:*|feature\(*|add\ *|added\ *|adds\ *|introduce\ *|introduces\ *|implement\ *|implements\ *|support\ *|supports\ *|new\ *)
            FEATURES="${FEATURES}${entry}"$'\n' ;;
        fix:*|fix\(*|fix\ *|fixed\ *|fixes\ *|bugfix*|bug\ fix*|repair\ *|repairs\ *|resolve\ *|resolves\ *|correct\ *|corrects\ *)
            FIXES="${FIXES}${entry}"$'\n' ;;
        *)
            OTHER="${OTHER}${entry}"$'\n' ;;
    esac
done < <(git log --no-merges --reverse --pretty=format:'%h%x09%s' "${RANGE}")

cat <<EOF
Universal macOS build. Not notarized with an Apple Developer ID.

**Recommended install** (no Gatekeeper prompt):

\`\`\`bash
curl -fsSL https://github.com/${OWNER}/${REPO}/releases/latest/download/install.sh | bash
\`\`\`

Or download the zip, move \`OpenTaskbar.app\` to \`/Applications\`, and allow
it once — **System Settings → Privacy & Security → Open Anyway** on
macOS 15+, or **right-click → Open** on macOS 14.

> After updating, Accessibility / Screen Recording permissions may
> need to be re-granted once. Settings in UserDefaults are kept.
>
> Installed copies also update themselves: OpenTaskbar checks the
> release feed once a day and offers to install and relaunch.
> (Preferences > Updates, or the menu bar > Check for Updates…)

---

## What's Changed
EOF

if [ -n "${FEATURES}" ]; then
    printf '\n### 🚀 Features\n\n%s' "${FEATURES}"
fi
if [ -n "${FIXES}" ]; then
    printf '\n### 🐛 Fixes\n\n%s' "${FIXES}"
fi
if [ -n "${OTHER}" ]; then
    printf '\n### 🧰 Other Changes\n\n%s' "${OTHER}"
fi
if [ -z "${FEATURES}${FIXES}${OTHER}" ]; then
    printf '\n_No changes recorded._\n'
fi

printf '\n**Full Changelog**: %s\n' "${CHANGELOG_URL}"
