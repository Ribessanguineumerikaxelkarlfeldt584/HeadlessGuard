#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Headless Guard.app"
CONTENTS="$APP_DIR/Contents"

cd "$ROOT_DIR"
swift build -c release --product HeadlessGuardApp
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/HeadlessGuardApp" "$CONTENTS/MacOS/HeadlessGuardApp"
cp "$ROOT_DIR/packaging/Info.plist" "$CONTENTS/Info.plist"

"$ROOT_DIR/scripts/make-icon.sh" "$ROOT_DIR/assets/app-icon.png" "$CONTENTS/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
