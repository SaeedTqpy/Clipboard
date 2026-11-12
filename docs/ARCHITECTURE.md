# Architecture

## Layering

\`\`\`text
menu-bar app / native SwiftUI floating shelf (macOS 15–26+)
       |
AppKit NSPanel + Carbon global hotkey + Accessibility-gated synthetic paste
       |
ClipboardModel (main-actor observable state)
       |
ClipboardMonitor → ClipboardPrivacy → ClipPayload
       |
ClipboardStore → SQLite WAL + FTS5 + PNG asset files
\`\`\`

No Electron, browser runtime, Rust bridge, remote backend or sync services are required. AppKit handles system integration; SwiftUI renders controls and uses native Liquid Glass on macOS 26.

## Capture and paste

- NSPasteboard.changeCount is polled at 650 ms; stale changes are skipped when monitoring is paused or restarted.
- Monitoring is opt-in on first launch. Sensitive/transient pasteboard annotations, known password-manager app identifiers and custom ignore rules prevent capture when detected.
- The foreground app is a best-effort heuristic, **not a secure origin identifier**. Uncooperative apps can still leak copied secrets.
- Images are converted into up-to-12-MiB PNG assets; large text and image payloads are bounded. File selections are serialized as a JSON path array with legacy single-path compatibility. Files themselves are not copied into app storage.
- SHA-256 content fingerprints deduplicate while updating the most recent timestamp.
- Copy writes an item to NSPasteboard and suppresses recapture of the app's own writes.
- Auto-paste copies the item, checks Accessibility trust, restores the previous app, verifies frontmost PID again and only then posts ⌘V. Posting input does not prove the destination accepted it.
- Paste Stack is an in-memory queue of up to 100 items. A queued item is removed after the paste event is posted, not after receiving application-level acknowledgment.

## Data layout and migration

- Application Support/Clipboard/history.sqlite3: local metadata, text, collections, pin status and FTS5 external-content search index.
- Application Support/Clipboard/Assets/: SHA-256-named PNGs. Directory permissions are 0700; SQLite DB and PNG files are 0600 where supported.
- SQLite schema uses PRAGMA user_version; migration to v2 adds collections without dropping existing history.
- Default retention is 30 days / 1,000 unpinned clips; users may configure 1–365 days and 50–5,000 unpinned entries. Pinned records are exempt.
- Cleanup runs on startup, on explicit retention changes and periodically after writes. Orphaned PNG files are deleted.
- SQLite query conditions are parameterized; FTS search tokens are quoted. The view presents up to 500 results.

## Privacy and risk register

- **No at-rest encryption.** Local permissions are not a substitute for cryptography. An attacker with access to the user account or device may obtain copied secrets.
- **Sensitive-content exclusion is best-effort.** Do not present it as a guarantee. Do not add telemetry of clipboard payloads.
- **Automatic paste is heuristic.** The destination application may reject or transform simulated keyboard events. Requires real-device testing.
- **No disk budget for unlimited pinned images.** Add total-storage caps and user-visible quota diagnostics before release.
- **Main actor capture/conversion and synchronous DB writes.** Profile and move expensive operations off the main thread before scaling.
- **Unsigned binaries.** Public downloads need Developer ID and notarization; Apple Developer account not needed for GitHub Actions development artifacts.
- **No App Sandbox.** Distribution and entitlement requirements must be reviewed separately, especially if targeting the Mac App Store.

## Testing and release gates

Unit tests live in ClipboardTests and use temporary roots rather than the user's real Application Support directory. CI is deliberately manual-only. See TEST_PLAN.md for hardware tests covering actual paste focus, file handling, permission behavior, screen layout, memory, and privacy.
