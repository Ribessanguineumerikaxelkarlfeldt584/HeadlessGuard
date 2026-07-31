#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_ROOT="${HEADLESS_GUARD_INSTALL_DIR:-$HOME/Applications}"

"$ROOT_DIR/scripts/build-app.sh"
mkdir -p "$INSTALL_ROOT"
ditto "$ROOT_DIR/dist/Headless Guard.app" "$INSTALL_ROOT/Headless Guard.app"
open "$INSTALL_ROOT/Headless Guard.app"

echo "Installed Headless Guard to $INSTALL_ROOT/Headless Guard.app"
