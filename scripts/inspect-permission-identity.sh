#!/bin/bash
# Read-only inspection. Never changes TCC, signatures or clipboard data.
set -euo pipefail
APP="/Applications/Clipboard.app"
if [[ $# -gt 0 ]]; then APP="$1"; fi
if [[ ! -d "$APP" ]]; then
  echo "ERROR: no Clipboard.app at $APP" >&2
  exit 1
fi

echo "== Clipboard permission identity diagnosis =="
echo "Selected app: $APP"
printf 'Bundle ID: '
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
echo
echo "Signature verification:"
if /usr/bin/codesign --verify --strict --verbose=2 "$APP"; then
  echo "Signature verification: passed"
else
  echo "Signature verification: FAILED (TCC identity may not match)"
fi
echo
echo "Signature and designated requirement:"
/usr/bin/codesign -dv --verbose=4 "$APP" 2>&1 \
  | grep -E 'Identifier=|Signature=|TeamIdentifier=|CDHash=' || true
/usr/bin/codesign -d -r- "$APP" 2>&1 || true
echo
echo "Running Clipboard executables (check duplicates):"
ps -axo pid=,command= | grep '[C]lipboard.app/Contents/MacOS/Clipboard' || true
echo
echo "Quarantine attribute (not modified):"
xattr -p com.apple.quarantine "$APP" 2>/dev/null || echo "none"
echo
echo "TCC authorization of the running process is shown inside Clipboard"
echo "Settings > Paste Diagnostics. This script cannot grant authorization."
echo "Never reset all TCC services or disable macOS security protections."
