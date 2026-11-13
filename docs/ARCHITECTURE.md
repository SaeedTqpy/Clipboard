# Clipboard system design — security-aware native macOS

## Core architecture

\`\`\`text
SwiftUI shelf / settings / asynchronous previews
              |
AppKit (NSPanel, MenuBar, NSPasteboard, accessibility), Carbon hotkey
              |
ClipboardModel (@MainActor, opt-in capture, commands)
              |
ClipboardMonitor -----------> ImageNormalizer (utility Task)
              |
ClipboardStore (SQLite3) ---> ClipboardVault (CryptoKit AES.GCM)
   |                           |
   |                           +---- Keychain master key, device-bound
   +---- secure_clips: ciphertext + metadata + keyed HMAC fingerprint
   +---- Assets/*.bin: AES-GCM sealed image bytes
   +---- temporary decrypted cache (<=32 MiB)
   |
ClipboardBackupCrypto (310k PBKDF2-SHA256, AES-GCM)
              |
User-chosen portable .clipbackup file
\`\`\`

No Electron runtime or remote API. No analytics, outbound sync or logging of clipboard data.

## Trust boundaries

- Clipboard contents are sensitive and can include one-time codes, passwords, documents, access tokens, filenames and confidential images.
- First launch is **paused**; capture only after explicit user action.
- Input source detection is best effort: protected/transient pasteboard types, known password managers and user-configured app bundle IDs are excluded. Some applications omit all these signals, so secrets can still be recorded.
- Keychain stores an app-specific 256-bit key with \`WhenUnlockedThisDeviceOnly\` accessibility; Keychain error or missing key **fails closed** instead of silently recreating the history key.
- AES-GCM authenticated encryption binds each encrypted record to its row ID and each asset to the keyed content fingerprint.
- HMAC-SHA256 fingerprints protect against offline dictionary attacks on known short clipboard values; fingerprints still reveal equality between matching copied items.
- The database preserves creation time and pin state as unencrypted metadata, but preview, body, paths, application names and collection names are sealed.
- The previous plaintext SQLite FTS5 table is removed in schema v3. Search decrypts records inside the app and caches at most 32 MiB of decoded content. **Large-history performance is not yet verified.**
- HTML/RTF flavors (capped at 2 MiB) are preserved inside encrypted content records; users can paste with formatting or as plain text. Additional pasteboard flavors are not yet supported.
- External file references are copied by URL only; actual referenced file bytes are not archived by Clipboard.

## Legacy migration and storage safety

1. Open SQLite with secure_delete and check database integrity.
2. Create secure_clips schema if absent.
3. Read legacy clips, encrypt each content record and PNG asset, using temporary ciphertext files.
4. Commit encrypted metadata transactionally; do not remove legacy rows on failure.
5. Drop legacy plaintext FTS/table within the transaction; checkpoint WAL, VACUUM and checkpoint again.
6. Remove legacy PNG files after successful migration. On interruption, clean them at next startup.
7. Run retention maintenance and remove orphan encrypted image assets.

**Important:** SQL and filesystem operations are not one distributed transaction. On interruption, ciphertext orphan files can remain; cleanup is idempotent. Data may persist in old Time Machine backups, APFS snapshots or SSD flash translation layers. Never claim secure forensic deletion.

## Backup and recovery

- User exports a \`.clipbackup\` file from settings with a 12+ character passphrase. BackupCrypto derives a separate encryption key with PBKDF2-HMAC-SHA256 and random salt, then AES-GCM seals a versioned JSON document.
- Backup archives are portable between Macs; the original device's Keychain key is not required to import.
- Restore validates records and merges into current history using keyed deduplication, preserving pinned items/collections. Transaction rollback handles SQL failure; orphaned encrypted assets are cleaned during maintenance.
- Backup maximum is 100 MiB of serialized plaintext, with a stricter 75 MiB content budget, and is currently processed in memory. Streaming backups and incremental restore are future scalability requirements.
- Damaged databases are **never reset automatically**. The user must explicitly quarantine the old Application Support/Clipboard folder in Application Support/Clipboard-Recovery, then start a fresh database. Old files remain available for forensic recovery; they are not decrypted by quarantine.

## macOS integration

- macOS 15 minimum deployment target, macOS 26 native Liquid Glass. AppKit floating NSPanel on the current pointer display and global Carbon ⌘⇧V shortcut.
- Automatic paste requires Accessibility permission and verifies target PID immediately before posting ⌘V. Events posted are not proof of successful paste in the destination.
- Menu Bar, settings access and optional Login Item via SMAppService. Unsigned app behavior may differ from Developer ID signed distribution.

## Remaining blockers

- Run one manually requested macOS CI build and address any compilation/test failures; verify encryption migration on a copied real legacy database.
- Performance/load test decryption, disk usage, async capture ordering and recovery with 5k+ realistic entries.
- Investigate rich-text HTML/RTF capture, index privacy versus search speed, full custom shortcut recorder, and paste into secure fields.
- VoiceOver, reduced motion and Persian localization; device tests with external monitors and full-screen apps.
- Reproducible signed/notarized release pipeline when Apple Developer ID becomes available.
