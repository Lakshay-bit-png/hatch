#!/bin/bash
# Builds Stash.app. Everything stays on this drive — SwiftPM keeps its cache in .build/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Stash.app"
CONFIG="${1:-release}"

# Universal so the app runs on Intel Macs too; UNIVERSAL=0 for a quicker host-only build.
UNIVERSAL="${UNIVERSAL:-1}"
if [ "$UNIVERSAL" = "1" ]; then
  echo "▸ Compiling ($CONFIG, arm64 + x86_64)…"
  swift build -c "$CONFIG" --package-path "$ROOT" --arch arm64 --arch x86_64
  # The multi-arch build lands under a different tree, with a capitalised config name.
  BIN="$ROOT/.build/apple/Products/$(echo "${CONFIG:0:1}" | tr '[:lower:]' '[:upper:]')${CONFIG:1}/Stash"
else
  echo "▸ Compiling ($CONFIG, this Mac only)…"
  swift build -c "$CONFIG" --package-path "$ROOT"
  BIN="$ROOT/.build/$CONFIG/Stash"
fi

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Stash"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/Stash.icns" "$APP/Contents/Resources/Stash.icns"

# Developer ID if one is in the keychain (override with SIGN_ID=…), ad-hoc otherwise.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')}"
if [ -n "$SIGN_ID" ]; then
  echo "▸ Signing with $SIGN_ID (hardened runtime)…"
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
  codesign --verify --strict --deep "$APP"
else
  echo "▸ Signing (ad-hoc, local use)…"
  codesign --force --sign - "$APP" 2>/dev/null
fi

echo "✓ Built $APP"
echo "  Run it:  open \"$APP\""
