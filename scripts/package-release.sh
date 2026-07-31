#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.1.0}"
ARCH="$(uname -m)"
APP_DIR="$ROOT_DIR/dist/Headless Guard.app"
ARCHIVE="$ROOT_DIR/dist/HeadlessGuard-v$VERSION-macOS-$ARCH.zip"

"$ROOT_DIR/scripts/build-app.sh"
rm -f "$ARCHIVE" "$ROOT_DIR/dist/SHA256SUMS.txt"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"
(
    cd "$ROOT_DIR/dist"
    shasum -a 256 "$(basename "$ARCHIVE")" > SHA256SUMS.txt
)

echo "$ARCHIVE"
