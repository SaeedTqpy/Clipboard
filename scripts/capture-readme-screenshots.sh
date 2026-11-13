#!/usr/bin/env bash
# Capture real macOS app windows (never AI-generated previews) for README.
# This script intentionally does not commit, push, upload, or run GitHub Actions.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: capture must run on a Mac with Clipboard.app open." >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

if ! grep -q '<!-- SCREENSHOTS:START -->' README.md ||
   ! grep -q '<!-- SCREENSHOTS:END -->' README.md ||
   ! grep -q '<!-- SCREENSHOTS:START -->' README.fa.md ||
   ! grep -q '<!-- SCREENSHOTS:END -->' README.fa.md; then
  echo "ERROR: screenshot gallery markers not found in both READMEs." >&2
  exit 1
fi

cat <<'MSG'
Capture real screenshots of Clipboard.app, using ONLY synthetic demo items.
Stop if you see passwords, tokens, personal file names or confidential apps.
macOS may request Screen Recording permission for Terminal.
For each stage, press Return, then click the Clipboard window.
MSG

mkdir -p docs/screenshots

capture() {
  local filename="$1"
  local description="$2"
  local destination="docs/screenshots/$filename"
  local pending="docs/screenshots/.pending-$filename"

  echo
  echo "$description"
  read -r -p "Press Return to select the Clipboard window (Ctrl-C cancels) ... " _
  rm -f "$pending"
  screencapture -i -W -o -t png "$pending"

  if [[ ! -s "$pending" ]]; then
    rm -f "$pending"
    echo "ERROR: no screenshot captured for $filename; README unchanged." >&2
    exit 1
  fi
  mv -f "$pending" "$destination"
  echo "Captured: $destination"
}

capture history.png "1/3: Show the shelf with fake text, link and image clips."
capture search.png "2/3: Search for a synthetic clip; keep the results visible."
capture settings.png "3/3: Open Clipboard privacy/settings with no private bundle IDs visible."

# Update README galleries only after all screenshots are successfully captured.
write_gallery() {
  local file="$1"
  local temp
  temp="$(mktemp)"
  awk '
    /^<!-- SCREENSHOTS:START -->$/ {
      print
      print ""
      print "| History shelf | Search | Privacy & settings |"
      print "| :---: | :---: | :---: |"
      print "| ![Real Clipboard shelf](docs/screenshots/history.png) | ![Real Clipboard search](docs/screenshots/search.png) | ![Real Clipboard settings](docs/screenshots/settings.png) |"
      print ""
      inside = 1
      next
    }
    /^<!-- SCREENSHOTS:END -->$/ {
      inside = 0
      print
      next
    }
    !inside { print }
  ' "$file" > "$temp"
  cat "$temp" > "$file"
  rm -f "$temp"
}

write_gallery README.md
write_gallery README.fa.md

cat <<'MSG'

Done: three real PNGs captured and README galleries updated.
BEFORE publishing, open all three files in Preview and inspect for secrets.
No git commit, git push, or GitHub Actions build was run by this script.
After verifying:
  git add README.md README.fa.md docs/screenshots/
  git commit -m "docs: add real macOS interface screenshots"
  git push origin main
MSG
