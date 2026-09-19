#!/bin/bash
# Packages Stash.app into a styled drag-to-install disk image.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Stash.app"
STAGE="$ROOT/build/dmg-stage"
RW="$ROOT/build/stash-rw.dmg"
DMG="$ROOT/build/Stash.dmg"
VOLUME="Stash"

[ -d "$APP" ] || { echo "Build the app first: ./build.sh"; exit 1; }

rm -rf "$STAGE" "$RW" "$DMG"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/Resources/dmg-background.png" "$STAGE/.background/background.png"

# A writable image first, so Finder can lay the window out before it's compressed.
# hdiutil's own -srcfolder copy is refused by macOS app protection when the source is a
# signed .app, so the image is created empty and filled with ditto below.
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 30 ))
hdiutil create -volname "$VOLUME" -size "${SIZE_MB}m" -fs HFS+ -ov "$RW" >/dev/null
# Track the device: a leftover /Volumes/Stash directory makes macOS mount this at
# "/Volumes/Stash 1", so detaching by path is unreliable.
ATTACH=$(hdiutil attach "$RW" -noautoopen)
DEV=$(echo "$ATTACH" | awk '/^\/dev\// {dev=$1} END {print dev}')
MNT=$(echo "$ATTACH" | grep -o '/Volumes/.*' | tail -1)

ditto "$STAGE/Stash.app" "$MNT/Stash.app"
ln -s /Applications "$MNT/Applications"
mkdir -p "$MNT/.background"
cp "$ROOT/Resources/dmg-background.png" "$MNT/.background/background.png"

# Finder owns icon positions and the background picture; there is no hdiutil flag for them.
osascript <<APPLESCRIPT >/dev/null 2>&1 || echo "  (Finder styling skipped — the image still works)"
tell application "Finder"
  tell folder (POSIX file "$MNT" as alias)
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 540}
    set theOptions to the icon view options of container window
    set arrangement of theOptions to not arranged
    set icon size of theOptions to 112
    set background picture of theOptions to POSIX file "$MNT/.background/background.png"
    set position of item "Stash.app" of container window to {170, 230}
    set position of item "Applications" of container window to {490, 230}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

sync
# Finder can hold the volume for a moment after styling; retry, then force.
for i in 1 2 3 4 5; do
  hdiutil detach "$DEV" >/dev/null 2>&1 && break
  sleep 2
done
mount | grep -q "^$DEV" && hdiutil detach -force "$DEV" >/dev/null 2>&1 || true
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf "$STAGE" "$RW"

# Sign the image with the same Developer ID as the app, then notarize if credentials are stored.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')}"
NOTARY_PROFILE="${NOTARY_PROFILE:-stash}"
if [ -n "$SIGN_ID" ]; then
  echo "▸ Signing disk image…"
  codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "▸ Notarizing (usually a few minutes)…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
  else
    echo "  (not notarized — no \"$NOTARY_PROFILE\" profile; see: xcrun notarytool store-credentials)"
  fi
fi

echo "✓ $DMG  ($(du -h "$DMG" | cut -f1))"
