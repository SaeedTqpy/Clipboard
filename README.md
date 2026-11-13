# Clipboard

**A native, local-first clipboard history manager for macOS.**

Clipboard lives in the menu bar and lets you find, organize, and reuse copied text, links, rich text, images, and files in a floating horizontal shelf. It is built with **SwiftUI + AppKit**, with Apple's **Liquid Glass on macOS 26+** and system materials on macOS 15–25.

**[Experience the interactive 3D website](https://saeedtqpy.github.io/Clipboard/)** · **[فارسی](README.fa.md)** · [Download](#download--install) · [Usage](#getting-started) · [Screenshots](#screenshots) · [Report an issue](https://github.com/SaeedTqpy/Clipboard/issues)

> **Developer preview · v0.2.0.** The November 13, 2026 build passed **29/29 automated tests** and produced a universal app for Apple Silicon and Intel. Real-device Accessibility, auto-paste, multi-display and security acceptance tests are still pending. This is **not a production-certified release**.

## Screenshots

<!-- SCREENSHOTS:START -->
**Actual macOS screenshots have not yet been captured.** We don't present mockups as product screenshots. See the [screenshot instructions](docs/SCREENSHOTS.md) to capture the real shelf, search and settings windows safely without Xcode.
<!-- SCREENSHOTS:END -->

## Features

| Area | Capabilities |
| --- | --- |
| Clipboard history | Text, HTTP(S) links, HTML/RTF, images and single/multiple file references |
| Native shelf | Floating horizontal cards, search, quick copy and paste |
| Organization | Pinning, deletion, collections, and content-type filtering |
| Quick paste | **⌘⇧V** to open; **⌘1–9** for visible entries; Paste as Plain Text |
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

The latest verified CI build is [Clipboard macOS Actions run #43389410106](https://github.com/SaeedTqpy/Clipboard/actions/runs/43389410106) (November 13, 2026).

1. Open the successful run and download the **Clipboard-macOS-unsigned** artifact under **Artifacts**. You may need to sign in to GitHub. Artifacts currently expire after **14 days**.
2. Extract the downloaded outer ZIP, then the inner `Clipboard-macOS-unsigned.zip`.
3. Move `Clipboard.app` into **Applications** and launch it.
4. This is an **unsigned, unnotarized development build**. If Gatekeeper blocks it, only if you trust the origin, review **System Settings → Privacy & Security → Open Anyway**.
5. Use *synthetic, non-sensitive* sample content first. Monitoring is **paused by default** on first launch.

There is no official signed installer, notarized DMG, App Store release or automatic updater yet.

**Need a fresh build?** Open [Clipboard macOS workflow](https://github.com/SaeedTqpy/Clipboard/actions/workflows/macos.yml) and select **Run workflow**. CI is deliberately **manual-only**—commits and PRs do not automatically consume GitHub Actions minutes.

## Getting started

1. Start Clipboard and find its icon in the **menu bar**.
2. Press **⌘⇧V** (or select **Open Clipboard** from the menu) to reveal the shelf.
3. **Enable monitoring**. Copy a harmless phrase such as `Clipboard test 001` in Notes.
4. Search the shelf; click **Copy** to put an item back on the macOS pasteboard.
5. To **Paste** into the previously active app, grant Clipboard **Accessibility** permission in system settings. The app verifies the destination process before sending ⌘V, but compatibility depends on the destination app.
6. Use the card menu to pin, move to a collection, add to Paste Stack, delete, or paste supported text as plain text.

| Shortcut | Behavior |
| --- | --- |
| **⌘⇧V** | Show or hide the floating shelf |
| **⌘1 … ⌘9** | Paste one of the first nine currently visible clips if the panel receives the shortcut |
| **Esc** | Dismiss the shelf |

The global hotkey is currently fixed and may conflict with shortcuts in other applications.

## Privacy and data safety

Clipboard is **local-first**. The application has no cloud-sync service, telemetry, or clipboard-content upload endpoint.

- **Opt-in:** monitoring starts paused and does not import data copied while paused.
- **Encrypted at rest:** clip content (including previews, paths and app names) and stored image assets are sealed with AES-GCM; the master key lives in macOS Keychain.
- **Sensitive sources are best-effort exclusions:** password-manager identification, concealed/transient pasteboard annotations and user-selected app exclusions are **not a guarantee** against accidentally storing a secret.
- **What encryption does not cover:** the system clipboard, active app memory, screenshots, previous backups, APFS snapshots, and SSD remnants.
- **Backups:** `.clipbackup` files are independently encrypted with a user-supplied password. Forgetting that password makes the archive unrecoverable. Losing the device's Keychain key can make local history unreadable.
- **File references:** external file paths are recorded, **not the contents of those files**.
- **Distribution:** this preview is unsigned and not sandboxed.

**Avoid copying real passwords, private keys, recovery phrases and API secrets while monitoring is enabled.** See [SECURITY.md](SECURITY.md) and [Architecture](docs/ARCHITECTURE.md).

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

**Build evidence:** [29/29 tests passed; universal arm64/x86_64 Release generated](https://github.com/SaeedTqpy/Clipboard/actions/runs/43389410106). A warm-cache search over 500 synthetic entries averaged ~5 ms on that CI runner. Real-device and larger-history performance is not yet certified.

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md), [ROADMAP.md](docs/ROADMAP.md) and the [real-device acceptance checklist](docs/MAC_DEVICE_QA.md). Bug reports and focused contributions are welcome, but **never upload real clipboard contents, raw databases, secrets or unredacted logs to public issues**.

### License

**No software license has been chosen or published.** Public source visibility does not grant reuse, modification or redistribution rights. Licensing must be decided before describing Clipboard as open source.

---

Clipboard is an independent project and is not affiliated with Apple.
