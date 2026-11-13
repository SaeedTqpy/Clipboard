# Clipboard — macOS manual acceptance and security test plan

The GitHub Actions runner cannot verify real user input, Accessibility authorization or native Mac clipboard integration. Do not mark any checklist item complete without evidence.

## Build gate

- [x] Trigger exactly one restricted milestone validation after fixing failures; restore manual-only CI after it starts.
- [x] All 29 unit/performance tests pass (privacy exclusions, migration, encryption, backup, recovery).
- [x] Universal arm64/x86_64 Release was produced; nested ZIP SHA-256 matched SHA256SUMS.txt.
- [ ] On a real Mac, run the package diagnostic and check macOS security prompts.
- [ ] Run the app on an actual macOS 26 Mac; check fallback on macOS 15–25.
- [ ] Verify Liquid Glass effect only on macOS 26; reduced transparency remains usable.

## Encryption and migration

- [ ] Fresh installation defaults to paused; copied data is not persisted until enabled.
- [ ] SQLite does not contain copied text, file paths or source names in readable form.
- [ ] Asset files contain authenticated ciphertext, not plaintext PNG data.
- [ ] Changing the Keychain key prevents decryption and fails closed without resetting history.
- [ ] Migrating legacy v2 DB retains pins, collections and image assets, removes legacy FTS.
- [ ] Interrupt a copied test migration midway; re-launch with no silent loss.
- [ ] Move a damaged DB to quarantine after explicit confirmation; verify original files remain intact.
- [ ] Check that data from old backups/APFS snapshots may persist despite VACUUM.

## Backup and restore

- [ ] Export with a 12+ character passphrase; source never leaves app as plaintext.
- [ ] Restore on a second Mac using only the backup file and passphrase.
- [ ] Wrong password or tampered backup does not change history.
- [ ] Preserve pins, collections, image previews and copyable text after restore.
- [ ] Restore duplicate records without creating duplicates; backup import stays atomic.
- [ ] Oversized backup yields an actionable error.
- [ ] Missing external file URL is handled without crashing; actual external file bytes are not in the backup.

## Capture and user interaction

- [ ] Capture Persian and English text, code, links, HTML/RTF rich text and images from multiple apps.
- [ ] Verify formatted Paste preserves rich text and Paste as Plain Text strips formatting.
- [ ] Copy multiple files in Finder, then paste into Finder with selection intact.
- [ ] Excluded bundle IDs and known concealed/transient annotations suppress capture.
- [ ] Toggle image and file capture; paused content is not imported on resume.
- [ ] Duplicate copies move the old item to top without losing pin/collection.
- [ ] Search, pin, collections, kind filters, clear and Paste Stack operate correctly.
- [ ] ⌘⇧V and ⌘1–9 work with keyboard focus, including text field and fullscreen apps.
- [ ] Clicking outside the panel closes it; panel appears on correct display.
- [ ] Direct Paste to Notes, Finder, Safari, browser inputs and VS Code; verify target focus.
- [ ] Clipboard doesn't synthesize keystrokes without Accessibility permission.
- [ ] Launch-at-login works, or provides actionable signed-build limitation.

## Performance and quality

- [ ] Fast scrolling of 500 clips with many images doesn't trigger large CPU spikes.
- [ ] Copying large images never blocks the main event loop.
- [ ] Energy use over 30 minutes of idle polling is acceptable.
- [ ] Search among 5,000 encrypted records remains responsive; cache stays bounded.
- [ ] Unpinned image assets are pruned at 512 MiB; pinned assets are exempt.
- [ ] App launches and stores history with locked/unlocked Keychain behavior understood.
- [ ] No clipboard contents are logged, uploaded or included in crash diagnostics.
- [ ] VoiceOver, high contrast, reduced motion and Persian UI are reviewed.

## Release gate

A successful compilation is **not** a production-release approval. Complete encryption, migration, security, device, usability and performance gates before a wider beta. Distributable signed/notarized versions require a suitable Apple Developer account.
