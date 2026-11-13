# Clipboard — native macOS clipboard manager

**SwiftUI + AppKit · Liquid Glass on macOS 26 · Keychain + AES-GCM encrypted history · Universal Mac**

Clipboard is a local-first menu-bar application with a floating horizontal clipboard shelf. This repository is actively developed and **not yet approved for general production use**.

## Implemented

- Global ⌘⇧V shortcut, bottom floating shelf, first-launch onboarding, dismiss-on-outside-click, and menu bar controls.
- Capture of text, HTTP(S) links, images, one or multiple file URLs, and deduplication.
- Collections, pins, search, kind filters, card actions and an in-memory sequential Paste Stack.
- Keyboard quick actions ⌘1–9, Copy and Accessibility-gated Paste into the previously active application with focus validation.
- Monitoring **paused by default**, privacy exclusion by app bundle ID, protected/transient pasteboard type filtering, image/file recording toggles.
- Retention controls, 512 MiB combined budget for *unpinned* image assets, cleaning of unreferenced assets.
- Local SQLite with **AES-256-GCM sealed clipboard records** (content + source application + collection + file paths) and encrypted PNG assets. The encryption key is stored in this Mac's Keychain and is restricted to this device.
- HMAC-based content fingerprints; **no plaintext full-text SQLite index**. Search is performed over decrypted records in memory with a bounded cache.
- Migrates legacy plaintext history and PNG assets; creates a new encrypted storage layout and attempts to remove legacy plaintext data.
- Passphrase-encrypted portable backup export/import, using PBKDF2-HMAC-SHA256 (310,000 rounds) and AES-256-GCM. Archive payloads are limited to 100 MiB and currently processed in memory.
- Explicit storage recovery: a failed database can be moved intact to a quarantine directory before creating an empty one. Never silently deletes unreadable history.
- Optional Launch at Login via ServiceManagement; may require system approval and a properly signed app.
- On-demand encrypted image decryption, off-main thumbnail generation with ImageIO dimension limits, limited in-memory thumbnail cache.

## Build with GitHub Actions

**The workflow is manual-only to save macOS runner minutes.** A push or PR does not start a build.

1. Open [Clipboard macOS workflow](https://github.com/SaeedTqpy/Clipboard/actions/workflows/macos.yml).
2. Click **Run workflow** and choose the desired branch.
3. GitHub compiles, runs unit tests, builds an unsigned universal arm64/x86_64 app and uploads an Artifact.
4. Download the \`Clipboard-macOS-unsigned\` artifact and verify SHA-256.

No paid Apple Developer Account and no local Xcode are required for these *development builds*. Because they are unsigned/not notarized, macOS Gatekeeper can block launch. For your own trusted build, System Settings → Privacy & Security → Open Anyway may be necessary.

Local Xcode build is optional:

\`\`\`bash
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild test -project Clipboard.xcodeproj -scheme Clipboard -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
\`\`\`

## Privacy and limitations

1. **Clipboard source filtering is best-effort.** Some applications do not mark credentials as private and frontmost-app observation is not an authenticated copy origin. The app can still accidentally capture secrets. Disable monitoring whenever working with sensitive material.
2. AES-GCM protects Clipboard's stored content, **not** the system-wide macOS pasteboard, live process memory, macOS screenshots, backups taken before migration or historical SSD snapshots. Database migration and clearing cannot guarantee forensic erasure of old plaintext blocks.
3. A lost Keychain key prevents the recovery of device-bound encrypted history. Use a **password-protected portable backup** before reinstalling, changing Macs or resetting your login keychain.
4. The backup password is never saved; **forgetting it makes the backup unrecoverable**. Backup import merges records, and file URLs still refer to files on the source filesystem.
5. Strong security depends on code signing, permission behavior, tamper/restore tests and hardware verification. The **latest source commits have not been compiled in GitHub Actions yet**.
6. Encrypted search decrypts metadata into app memory. Performance and memory use on very large histories still need measurement and refinement.

## Repository

- \`Clipboard/ClipboardApp.swift\`: native panel, menu bar, hotkeys, app-focus-safe pasting
- \`Clipboard/ClipboardModel.swift\`: observable application state and commands
- \`Clipboard/ClipboardMonitor.swift\`: opt-in NSPasteboard capture
- \`Clipboard/ClipboardStore.swift\`: encrypted SQLite, schema migration, retention, encrypted archives
- \`Clipboard/ClipboardVault.swift\`: Keychain-backed AES-GCM and keyed fingerprints
- \`Clipboard/ClipboardBackupCrypto.swift\`: passphrase-derived portable backup encryption
- \`Clipboard/ClipboardThumbnailView.swift\`: off-main ImageIO thumbnails
- \`Clipboard/ClipboardImageNormalizer.swift\`: bounded image conversion
- \`Clipboard/ClipboardRecovery.swift\`: non-destructive history quarantine
- \`Clipboard/ClipboardPanelView.swift\`: native shelf, collection management, privacy, backup and login settings
- \`ClipboardTests/\`: policy, storage, migration, backup and vault tests
- \`docs/TEST_PLAN.md\`: physical Mac acceptance checklist

**Compatibility:** macOS 15+, true Liquid Glass on macOS 26+, fallback system materials on macOS 15–25. Signing and notarization for broad public distribution will require Apple Developer membership.
