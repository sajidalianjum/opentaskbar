#!/bin/bash
set -euo pipefail

# Creates a stable, self-signed code-signing identity ("OpenTaskbarDev") in the
# login keychain. Run once per machine; idempotent.
#
# Why: macOS ties the Accessibility (TCC) grant to the app's code requirement.
# An ad-hoc build gets a fresh identity on every rebuild, so the grant is lost
# each time and the permission has to be re-granted. A stable identity keeps it.
#
# This is a local convenience only. You do not need it to build or run
# OpenTaskbar, and it is unrelated to GitHub releases, which are built ad-hoc on
# a clean CI runner (no signing secrets). build.sh picks the identity up
# automatically once it exists.

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

IDENTITY_NAME="OpenTaskbarDev"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    grep '^# ' "$0" | sed 's/^# \{0,1\}//'
    exit 0
fi

if security find-identity -v -p codesigning 2>/dev/null | grep -qF "\"${IDENTITY_NAME}\""; then
    log "'${IDENTITY_NAME}' code-signing identity already exists — nothing to do."
    exit 0
fi

command -v openssl  >/dev/null 2>&1 || die "openssl is required (ships with macOS)"
command -v security >/dev/null 2>&1 || die "security is required (ships with macOS)"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opentaskbar-signing.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

KEY="${TMP_DIR}/key.pem"
CERT="${TMP_DIR}/cert.pem"

cat > "${TMP_DIR}/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = ${IDENTITY_NAME}
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

log "Generating self-signed code-signing certificate '${IDENTITY_NAME}'..."
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "${KEY}" -out "${CERT}" \
    -config "${TMP_DIR}/openssl.cnf" >/dev/null 2>&1

# Import the key and certificate as separate PEM files. A PKCS#12 exported by
# OpenSSL 3 carries a MAC that macOS `security import` rejects, and LibreSSL
# emits a different algorithm set; PEM imports cleanly under both.
log "Importing into the login keychain (macOS may ask to allow access)..."
security import "${CERT}" -k "${KEYCHAIN}" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security import "${KEY}"  -k "${KEYCHAIN}" -T /usr/bin/codesign -T /usr/bin/security >/dev/null

# The identity is intentionally not marked trusted: codesign can use it anyway,
# and build.sh looks it up with `find-identity -p codesigning` so it is found.
if security find-identity -p codesigning 2>/dev/null | grep -qF "\"${IDENTITY_NAME}\""; then
    log "Done — Scripts/build.sh will use '${IDENTITY_NAME}' automatically."
    log "To sign releases on CI with it, export it from Keychain Access as a .p12"
    log "and follow the signing section in docs/RELEASE.md."
else
    die "imported the identity but the keychain does not list it for code signing"
fi
