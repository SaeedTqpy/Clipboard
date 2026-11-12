# Manual macOS acceptance checklist

> GitHub Actions does not have physical access to the user's Mac, other desktop apps or a real Accessibility permission flow. Mark these checks only after hands-on testing.

## 1. Install and first launch

- [ ] Download the unsigned universal app artifact and verify SHA-256.
- [ ] Launch on macOS 26 Apple Silicon; later repeat on macOS 15+ and Intel.
- [ ] Approve an unsigned personal build in Privacy & Security if needed.
- [ ] App starts as a menu bar agent and opens the shelf for first-launch discovery.
- [ ] Monitoring starts **paused** on a fresh install; no earlier clipboard data was saved.
- [ ] Enabling monitoring records new text but not stale paused items.

## 2. Core capture

- [ ] Copy plain text, UTF-8/Persian text, multiline code and large text.
- [ ] Copy HTTP/HTTPS links; kind filter identifies them.
- [ ] Copy screenshots and images; previews display and persist after relaunch.
- [ ] Copy one file and multiple files; paste back into Finder with correct selection.
- [ ] Recopy the same payload; only one entry remains and moves to the top.
- [ ] Copy from a password manager with concealed/transient annotations: not recorded.
- [ ] Add a running app to ignored bundle IDs; new copies from that app do not appear.
- [ ] Disable images/files; copying them no longer creates those entries.
- [ ] Pause, copy data, resume; paused content is not imported retroactively.

## 3. UI and workflow

- [ ] ⌘⇧V opens and closes the shelf from another app.
- [ ] Search focuses on open; Escape closes.
- [ ] Search recognizes partial words, punctuation and Persian text where applicable.
- [ ] Pin, unpin and delete work without duplicate entries.
- [ ] Collections can be created and clips assigned/filtered.
- [ ] Kind filter combines correctly with collection, pin and search.
- [ ] ⌘1–9 targets the corresponding visible clip.
- [ ] Paste Stack processes multiple items in added order.
- [ ] Clear All requires confirmation and removes image assets.
- [ ] Settings open from both the panel and menu bar.

## 4. Accessibility and target safety

- [ ] Without Accessibility permission, Copy succeeds and Paste does not synthesize keys.
- [ ] Request Accessibility permission through settings; verify Security settings.
- [ ] With permission, paste into Notes, Safari, a code editor and Finder.
- [ ] Change focus while an automatic paste is pending; no simulated paste is sent to the wrong app.
- [ ] Test full-screen apps, multiple Spaces and multiple monitors.
- [ ] Test that global shortcut conflicts display an actionable warning.

## 5. Persistence and migration

- [ ] Relaunch: entries, pins, collections, search and retention settings persist.
- [ ] Migrate a database made by the older release to schema v2 without losing history.
- [ ] Reduce retention count/days and verify only unpinned entries are pruned.
- [ ] Verify database and image directory permissions for the user account.
- [ ] Delete an image entry and confirm its unreferenced asset is removed.
- [ ] Run SQLite integrity_check on a copied test database (not active production DB).
- [ ] Verify no clipboard payload appears in app logs, CI logs or network traffic.

## 6. Performance and release criteria

- [ ] Observe idle CPU/energy impact over a 30-minute session.
- [ ] Copy dozens of screenshots; verify responsive UI and reasonable memory usage.
- [ ] Run search on 1,000 items with no freezes.
- [ ] Check VoiceOver, Dark/Light, high contrast and keyboard-only use.
- [ ] Run a **single** manually triggered macOS Actions build at the agreed validation checkpoint.
- [ ] Do not declare the app production ready until security, corruption recovery and real-device gates pass.
