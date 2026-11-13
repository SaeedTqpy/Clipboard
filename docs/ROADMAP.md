# Clipboard production release roadmap

## Implemented in source — macOS CI validated on 2026-11-13 (29/29 tests, universal release)

- SwiftUI + AppKit menu bar utility, floating Liquid Glass-capable shelf, ⌘⇧V.
- History for text, links, encrypted HTML/RTF content, images, multi-file selections; controls for pin, copy, formatted/plain-text paste, collections, kind filter.
- Paste Stack session queue, ⌘1–9 action shortcuts and destination-app PID check before posting paste events.
- Opt-in monitoring, source exclusions, recording toggles and retention limits.
- Keychain-backed AES-256-GCM encrypted history, encrypted PNG assets and keyed HMAC fingerprints.
- In-memory search without plaintext SQLite FTS; 32 MiB bounded decoded cache.
- Schema-v3 migration from legacy plaintext SQLite and PNG history; crash-interruption best-effort cleanup.
- Encrypted portable passphrase backups, restore merge, explicit database quarantine and reset.
- Async thumbnail decode, image decompression caps, 512 MiB unpinned image asset budget.
- Optional login-item controls and close-on-external-click interaction.
- Unit tests for vault, backup, storage, migration, recovery, filter and app exclusion policies.
- Workflow manually triggered only, to avoid consuming GitHub Actions minutes for each push.

## Competitive implementation batch — 2026-11-13 (CI validated: 37/37)

- Keyboard-first selection with NSPanel event handling, editable shortcut presets, Return / Option+Return / Cmd+P / Cmd+1–9.
- Optional offline Vision OCR for image search, encrypted alongside text titles and source metadata.
- Create/pin/edit encrypted Snippets, in-place text editing with fingerprint-safe collision handling.
- Filter by source application and time window; clear recent unpinned entries with confirmation.
- See [competitive analysis](COMPETITIVE_ANALYSIS.md) for comparison and explicit non-goals.
- **This batch passed 37 automated tests and built a universal Release** in [macOS Actions run 43398219188](https://github.com/SaeedTqpy/Clipboard/actions/runs/43398219188). Physical Mac QA and public-distribution signing are still pending.

## Must verify before beta

1. **Build validation passed:** macOS 26 Actions run [43389410106](https://github.com/SaeedTqpy/Clipboard/actions/runs/43389410106) built universal Release and passed all 29 tests. Do not confuse this with hardware/permission acceptance.
2. **Real device:** Apple Silicon and Intel macOS 15–26, Gatekeeper, Keychain access on unsigned app, Accessibility prompt, actual direct paste, global shortcut conflicts and login item approval.
3. **Legacy migration:** test against a backup copy of the v2 database and assets. Ensure no plaintext search index or image files remain in active storage after migration.
4. **Restore:** wrong password, corrupted archive, interrupted import, wrong device, lost Keychain key and missing referenced external files.
5. **Performance:** main-thread responsiveness with 5,000 records, image-heavy histories, Keychain latency, encrypted search and energy consumption.
6. **Privacy:** test non-cooperating password managers, concealed pasteboard types, focus changes, screen locking, and secret data in OS snapshots and previous backups.
7. **Quality:** UI automation, accessibility, keyboard navigation, VoiceOver, internationalization, reduced motion and multi-monitor layouts.

## Next engineering milestones

- Asynchronous serialized persistence actor and privacy-preserving blind search indexing if performance requires it.
- Remaining rich clipboard formats: RTFD, PDF, combined multiple-format preservation, advanced rich previews and file promises.
- Customizable shortcut recorder and keyboard navigation, collection drag/drop, Paste Stack persistence.
- Streaming encrypted backups for large histories and more robust import conflict control.
- Localization (English/Persian), icon asset creation, app metadata and release screenshots.
- Signed, notarized package and updater when Apple Developer ID becomes available.

## CI policy

The macOS workflow is **workflow_dispatch-only**, with a single manual validation at milestones. Never restore automatic on-push builds unless the repository owner explicitly asks.
