#!/bin/bash
# No Xcode and no Apple Developer account required.
# This checks built app packaging only; it does not grant permissions,
# read clipboard contents, or pretend to test interactive paste.
set -euo pipefail
APP="/Applications/Clipboard.app"
if [[ $# -gt 0 ]]; then APP="$1"; fi
BIN="$APP/Contents/MacOS/Clipboard"
INFO="$APP/Contents/Info.plist"

if [[ ! -d "$APP" || ! -f "$BIN" || ! -f "$INFO" ]]; then
  echo "ERROR: expected Clipboard.app at: $APP" >&2
  exit 1
fi

echo "Clipboard macOS package diagnostics"
echo "App: $APP"
echo "----------------------------------"
plutil -lint "$INFO"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO"
/usr/libexec/PlistBuddy -c "Print :LSUIElement" "$INFO"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO" || true
echo "Executable:"
file "$BIN"

if command -v lipo >/dev/null 2>&1; then
  architectures="$(lipo -archs "$BIN")"
  echo "Architectures: $architectures"
  if [[ "$architectures" != *"arm64"* || "$architectures" != *"x86_64"* ]]; then
    echo "WARNING: universal binary not confirmed"
  fi
fi

echo "Code signature (the new ad-hoc preview must pass):"
codesign --verify --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E 'Identifier=|Signature=|CDHash='
codesign -d -r- "$APP" 2>&1
echo
echo "Gatekeeper assessment (ad-hoc preview is not notarized):"
spctl --assess --type execute --verbose "$APP" 2>&1 || true
echo
echo "NOTICE: This script does not test clipboard capture, Accessibility,"
echo "global hotkeys, migration, Paste Stack, or actual paste into other apps."
echo "Follow docs/MAC_DEVICE_QA.md on a real Mac, using synthetic test text."
