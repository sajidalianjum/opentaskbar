#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

"${SCRIPT_DIR}/build.sh"

APP_BUNDLE="${PROJECT_DIR}/build/OpenTaskbar.app"
echo "Launching ${APP_BUNDLE}..."
open "${APP_BUNDLE}"
