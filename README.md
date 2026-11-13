# Clipboard

**A native, local-first clipboard history manager for macOS.**

Clipboard lives in the menu bar with two distinct surfaces: a full-width Quick Shelf that rises from the physical bottom edge, and a separate native Clipboard Manager opened by clicking the menu bar icon. Both help you find, organize, and reuse copied text, links, images, files and snippets. It is built with **SwiftUI + AppKit**, with Apple's **Liquid Glass on macOS 26+** and system materials on macOS 15–25.

**[Experience the interactive 3D website](https://saeedtqpy.github.io/Clipboard/)** · **[فارسی](README.fa.md)** · [Download](#download--install) · [Usage](#getting-started) · [Screenshots](#screenshots) · [Report an issue](https://github.com/SaeedTqpy/Clipboard/issues)

> **Developer preview · v0.2.0.** The November 13, 2026 bottom-shelf and color-tags build passed **44/44 automated tests** and produced a universal app for Apple Silicon and Intel. Real-device Accessibility, auto-paste, multi-display and security acceptance tests are still pending. This is **not a production-certified release**.

## Screenshots

<!-- SCREENSHOTS:START -->
**Actual macOS screenshots have not yet been captured.** We don't present mockups as product screenshots. See the [screenshot instructions](docs/SCREENSHOTS.md) to capture the real shelf, search and settings windows safely without Xcode.
<!-- SCREENSHOTS:END -->

## Features

| Area | Capabilities |
| --- | --- |
| Clipboard history | Text, HTTP(S) links, HTML/RTF, images and single/multiple file references |
| Quick Shelf | Hotkey-only; fills the display width and rises directly from the physical bottom edge (no lower gap). Controls remain above the Dock; Reduce Motion honored |
| Clipboard Manager | Normal resizable macOS window; opens from left-clicking the menu bar icon, not from the hotkey |
| Organization | Pinning, editable titles, text editing, collections, app/date/kind filters and bulk recent cleanup |
| Color tags | Up to five encrypted tags per clip; custom palettes, global tag edits, search, filters and encrypted backup |
| Searchable images | Optional, **on-device Apple Vision OCR**; detected text is encrypted at rest |
| Reusable snippets | Create or convert text to pinned snippets; no system-wide auto-expansion |
| Quick paste | Configurable global shortcut, ↑↓ selection, Return paste, Option+Return plain, ⌘1–9 quick picks |
| Paste Stack | Queue clips and paste them sequentially during the current session |
| Privacy | Opt-in monitoring, application exclusions, image/file capture toggles |
| Storage | AES-256-GCM encrypted clips and image assets, Keychain-held device key |
| Backup & recovery | Password-encrypted portable backups and non-destructive database quarantine |
| Housekeeping | Adjustable history retention and disk budget for unpinned images |
| Integration | Menu bar, optional Launch at Login and native appearance |

## Requirements

- **macOS 15+**; native Liquid Glass styling is used on **macOS 26+**.
- **Apple Silicon (arm64)** or **Intel (x86_64)**.
- **No paid Apple Developer account or local Xcode needed to install** a prebuilt development artifact.
- **Accessibility permission is needed only for automatic paste**, not for viewing history or copying a clip.

## Download & install

The latest verified CI build is [Clipboard macOS Actions run #43398219188](https://github.com/SaeedTqpy/Clipboard/actions/runs/43417580697) (November 13, 2026).

1. Open the successful run and download the **Clipboard-macOS-unsigned** artifact under **Artifacts**. You may need to sign in to GitHub. Artifacts currently expire after **14 days**.
2. Extract the downloaded outer ZIP, then the inner `Clipboard-macOS-unsigned.zip`.
3. **Quit all existing Clipboard instances** from the menu bar or Activity Monitor (especially old copies in Downloads). Move the extracted `Clipboard.app` into **Applications**, replacing the earlier version, then launch only the new copy.
4. This is an **unsigned, unnotarized development build**. If Gatekeeper blocks it, only if you trust the origin, review **System Settings → Privacy & Security → Open Anyway**.
5. Use *synthetic, non-sensitive* sample content first. Monitoring is **paused by default** on first launch.

There is no official signed installer, notarized DMG, App Store release or automatic updater yet.

**Need a fresh build?** Open [Clipboard macOS workflow](https://github.com/SaeedTqpy/Clipboard/actions/workflows/macos.yml) and select **Run workflow**. CI is deliberately **manual-only**—commits and PRs do not automatically consume GitHub Actions minutes.

## Getting started

1. Start Clipboard and find its icon in the **menu bar**.
2. Press **⌃⇧V** (Control+Shift+V, the default on new installations) to reveal the bottom Quick Shelf. Click the **menu bar icon** to open the separate resizable Clipboard Manager. Right-click the menu bar icon for Pause, Settings and Quit.
3. **Enable monitoring**. Copy a harmless phrase such as `Clipboard test 001` in Notes.
4. Search the shelf; click **Copy** to put an item back on the macOS pasteboard.
5. To **Paste** into the previously active app, grant Clipboard **Accessibility** permission in system settings. The app verifies the destination process before sending ⌘V, but compatibility depends on the destination app.
6. Use the card menu to pin, move to a collection, **create or apply colored tags**, add to Paste Stack, delete, or paste supported text as plain text. Click a tag in the horizontal tag rail to filter, or right-click a tag to edit its name/color.

| Shortcut | Behavior |
| --- | --- |
| **⌃⇧V** (default) | Show or hide the bottom Quick Shelf; it never opens the manager |
| **⌘1 … ⌘9** | Paste one of the first nine currently visible clips if the panel receives the shortcut |
| **Esc** | Dismiss the shelf |
| **↑ / ↓** | Select earlier / later clip |
| **Return** | Paste selected clip |
| **Option + Return** | Paste selected clip without formatting (text types) |
| **⌘P** | Pin or unpin selected clip |
| **⌘Backspace** | Ask to delete selected clip |

The global hotkey can be changed in Settings to several preset combinations. Previously selected shortcuts are preserved during an app upgrade, so select **⌃⇧V** in Settings if the previous version had a different binding. A conflicting replacement is rejected without intentionally unbinding the existing shortcut.

## Privacy and data safety

Clipboard is **local-first**. The application has no cloud-sync service, telemetry, or clipboard-content upload endpoint.

- **Opt-in:** monitoring starts paused and does not import data copied while paused.
- **Encrypted at rest:** clip content (including previews, paths and app names) and stored image assets are sealed with AES-GCM; the master key lives in macOS Keychain.
- **Sensitive sources are best-effort exclusions:** password-manager identification, concealed/transient pasteboard annotations and user-selected app exclusions are **not a guarantee** against accidentally storing a secret.
- **What encryption does not cover:** the system clipboard, active app memory, screenshots, previous backups, APFS snapshots, and SSD remnants.
- **Backups:** `.clipbackup` files are independently encrypted with a user-supplied password. Forgetting that password makes the archive unrecoverable. Losing the device's Keychain key can make local history unreadable.
- **File references:** external file paths are recorded, **not the contents of those files**.
- **Distribution:** this preview is unsigned and not sandboxed.

**Avoid copying real passwords, private keys, recovery phrases and API secrets while monitoring is enabled.** OCR is opt-in and performed locally using Apple's Vision framework; its recognized text is encrypted in history. See [SECURITY.md](SECURITY.md) and [Architecture](docs/ARCHITECTURE.md).

### Storage location

`~/Library/Application Support/Clipboard/`

The directory contains the SQLite history and encrypted assets. A corrupt database is never silently discarded; recovery requires confirmation and preserves the previous folder separately.

## Build from source

Building locally requires a Mac with a suitable Xcode toolchain. The Xcode project is generated by [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild test -project Clipboard.xcodeproj -scheme Clipboard \
  -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Clipboard.xcodeproj -scheme Clipboard \
  -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
```

If Xcode is not installed locally, use the **manual GitHub Actions build** linked above.

### Project structure

```text
Clipboard/
├── Clipboard/          SwiftUI UI, AppKit integration, capture and encryption
├── ClipboardTests/     Automated unit, integration-seam and performance tests
├── docs/               Architecture, roadmap, macOS QA and screenshots
├── scripts/            Diagnostics and screenshot capture tools
├── project.yml         XcodeGen configuration
└── .github/workflows/  Manual macOS build and tests
```

**Build evidence:** [44/44 tests passed; universal arm64/x86_64 Release generated](https://github.com/SaeedTqpy/Clipboard/actions/runs/43417580697). A warm-cache search over 500 synthetic entries averaged ~5 ms on that CI runner. Real-device and larger-history performance is not yet certified.

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md), [competitive analysis](docs/COMPETITIVE_ANALYSIS.md), [ROADMAP.md](docs/ROADMAP.md) and the [real-device acceptance checklist](docs/MAC_DEVICE_QA.md). Bug reports and focused contributions are welcome, but **never upload real clipboard contents, raw databases, secrets or unredacted logs to public issues**.

### License

**No software license has been chosen or published.** Public source visibility does not grant reuse, modification or redistribution rights. Licensing must be decided before describing Clipboard as open source.

---

Clipboard is an independent project and is not affiliated with Apple.
