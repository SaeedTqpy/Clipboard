#!/usr/bin/env bash
# Publish static site/ to gh-pages root without npm, Xcode, or macOS Actions.
# Requires local git and authorization to push to this repository.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: commit or stash local changes before publishing." >&2
  exit 1
fi
if [[ ! -f site/index.html || ! -f site/world.js || ! -f site/styles.css ]]; then
  echo "ERROR: site/ source is incomplete." >&2
  exit 1
fi
git fetch origin gh-pages
WORKTREE="$(mktemp -d)"
cleanup() {
  git worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
  rmdir "$WORKTREE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git worktree add --detach "$WORKTREE" origin/gh-pages
# Do not touch the Git worktree metadata in this temporary checkout.
rsync -a --delete --exclude='.git' --exclude='README.md' "$ROOT/site/" "$WORKTREE/"
touch "$WORKTREE/.nojekyll"
git -C "$WORKTREE" add -A
if git -C "$WORKTREE" diff --cached --quiet; then
  echo "GitHub Pages already matches site/: no new commit or deploy."
  exit 0
fi
git -C "$WORKTREE" commit -m "deploy: sync Clipboard immersive website from main/site"
git -C "$WORKTREE" push origin HEAD:gh-pages
echo "Published static assets to gh-pages. Check Settings → Pages for source configuration."
