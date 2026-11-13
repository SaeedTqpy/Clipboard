# Clipboard

**A native, local-first clipboard history manager for macOS.**

Clipboard lives in the menu bar with two distinct surfaces: a full-width Quick Shelf that rises from the physical bottom edge, and a separate native Clipboard Manager opened by clicking the menu bar icon. Both help you find, organize, and reuse copied text, links, images, files and snippets. It is built with **SwiftUI + AppKit**, with Apple's **Liquid Glass on macOS 26+** and system materials on macOS 15–25.

**[Experience the interactive 3D website](https://saeedtqpy.github.io/Clipboard/)** · **[فارسی](README.fa.md)** · [Download](#download--install) · [Usage](#getting-started) · [Screenshots](#screenshots) · [Report an issue](https://github.com/SaeedTqpy/Clipboard/issues)

> **Developer preview · v0.2.0.** The November 13, 2026 ad-hoc signed TCC-identity build passed **62/62 automated tests** and produced a universal app for Apple Silicon and Intel. Real-device Accessibility, auto-paste, multi-display and security acceptance tests are still pending. This is **not a production-certified release**.


**App icon:** the app includes an original, resolution-independent glass clipboard icon (see [icon implementation](docs/APP_ICON.md)).

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
- **No paid Apple Developer account or local Xcode needed to install** a prebuilt ad-hoc signed development artifact. A Developer ID is required for persistent trusted distribution.
- **Accessibility permission is needed only for automatic paste**, not for viewing history or copying a clip.

## Download & install

The latest verified ad-hoc signed CI build is [Clipboard macOS Actions run #43498945781](https://github.com/SaeedTqpy/Clipboard/actions/runs/43498945781) (November 13, 2026).

1. Open the successful run and download the **Clipboard-macOS-adhoc** artifact under **Artifacts**. You may need to sign in to GitHub. Artifacts currently expire after **14 days**.
2. Extract the downloaded outer ZIP, then the inner `Clipboard-macOS-adhoc.zip`.
3. **Quit all existing Clipboard instances** from the menu bar or Activity Monitor (especially old copies in Downloads). Move the extracted `Clipboard.app` into **Applications**, replacing the earlier version, then launch only the new copy.
4. This is an **ad-hoc signed, unnotarized development build**. The signature is tied to this exact build, not a stable Developer ID. If Gatekeeper blocks it, only if you trust the origin, review **System Settings → Privacy & Security → Open Anyway**.
5. Use *synthetic, non-sensitive* sample content first. Monitoring is **paused by default** on first launch.

There is no **Developer ID-signed**, notarized DMG, App Store release or automatic updater yet. The CI app is ad-hoc signed specifically so macOS can identify this build during local Accessibility authorization. **TCC permission does not reliably survive upgrades to another ad-hoc build.** See [TCC and signing troubleshooting](docs/TCC_SIGNING.md).

**Need a fresh build?** Open [Clipboard macOS workflow](https://github.com/SaeedTqpy/Clipboard/actions/workflows/macos.yml) and select **Run workflow**. CI is deliberately **manual-only**—commits and PRs do not automatically consume GitHub Actions minutes.

## Getting started

1. Start Clipboard and find its icon in the **menu bar**.
2. Press **⌘⇧V** (Command+Shift+V; the **Win + Shift + V** keys on a standard Windows keyboard attached to a Mac) to reveal the bottom Quick Shelf. Click the **menu bar icon** to open the resizable Clipboard Manager. Right-click it for Pause, Settings, and Quit.
3. **Enable monitoring**. Copy a harmless phrase such as `Clipboard test 001` in Notes.
4. Search the Quick Shelf and **click a card's header/preview** to copy the item, close the Shelf, restore the previously active app, and paste there. The **Copy** button only copies; **•••** opens more actions without pasting.
5. To **Paste** into the previously active app, grant Clipboard **Accessibility** permission in system settings. The app verifies the destination process before sending ⌘V, but compatibility depends on the destination app.
6. Use the card menu to pin, move to a collection, **create or apply colored tags**, add to Paste Stack, delete, or paste supported text as plain text. Click a tag in the horizontal tag rail to filter, or right-click a tag to edit its name/color.

| Shortcut | Behavior |
| --- | --- |
| **⌘⇧V** (default) | Show or hide the bottom Quick Shelf; with a standard external Windows keyboard this is **Win + Shift + V** |
| **⌘1 … ⌘9** | Paste one of the first nine currently visible clips if the panel receives the shortcut |
| **Esc** | Dismiss the shelf |
| **↑ / ↓** | Select earlier / later clip |
| **Return** | Paste selected clip |
| **Option + Return** | Paste selected clip without formatting (text types) |
| **⌘P** | Pin or unpin selected clip |
| **⌘Backspace** | Ask to delete selected clip |

The global hotkey can be changed in Settings to several presets. Upgrading from the old default **Ctrl+Shift+V** migrates once to **Command+Shift+V**; unrelated custom presets remain unchanged. If your external keyboard has remapped modifiers, check **System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys** to confirm that Win is mapped to Command. A shortcut already occupied by another app cannot be registered. **Accessibility** is required for automatic paste; without permission, clicking the preview copies and closes the Shelf without sending Cmd+V.

## Privacy and data safety

Clipboard is **local-first**. The application has no cloud-sync service, telemetry, or clipboard-content upload endpoint.

- **Opt-in:** monitoring starts paused and does not import data copied while paused.
- **Encrypted at rest:** clip content (including previews, paths and app names) and stored image assets are sealed with AES-GCM; the master key lives in macOS Keychain.
- **Sensitive sources are best-effort exclusions:** password-manager identification, concealed/transient pasteboard annotations and user-selected app exclusions are **not a guarantee** against accidentally storing a secret.
- **What encryption does not cover:** the system clipboard, active app memory, screenshots, previous backups, APFS snapshots, and SSD remnants.
- **Backups:** `.clipbackup` files are independently encrypted with a user-supplied password. Forgetting that password makes the archive unrecoverable. Losing the device's Keychain key can make local history unreadable.
- **File references:** external file paths are recorded, **not the contents of those files**.
- **Distribution:** this preview is ad-hoc signed per build, not Developer ID-signed or notarized, and is not sandboxed.

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

**Build evidence:** [62/62 tests passed; universal arm64/x86_64 Release generated](https://github.com/SaeedTqpy/Clipboard/actions/runs/43498945781). A warm-cache search over 500 synthetic entries averaged ~5 ms on that CI runner. Real-device and larger-history performance is not yet certified.

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md), [competitive analysis](docs/COMPETITIVE_ANALYSIS.md), [ROADMAP.md](docs/ROADMAP.md) and the [real-device acceptance checklist](docs/MAC_DEVICE_QA.md). Bug reports and focused contributions are welcome, but **never upload real clipboard contents, raw databases, secrets or unredacted logs to public issues**.

### License

**No software license has been chosen or published.** Public source visibility does not grant reuse, modification or redistribution rights. Licensing must be decided before describing Clipboard as open source.

---

Clipboard is an independent project and is not affiliated with Apple.


### If clicking a card copies but does not paste

On a Mac, **automatic insertion requires two permissions**: Accessibility and permission for posting keyboard events. Clipboard now checks both when you click a Quick Shelf card and prompts for access if either is missing. Keep only the newest Clipboard app in **Applications**, quit older copies, then enable Clipboard under **System Settings → Privacy & Security → Accessibility** and restart it. Clicking the preview pastes; clicking **Copy** deliberately does not. If focus cannot be restored to the previous app, Clipboard does not inject keyboard events into a different app; your clip is already copied and can be pasted manually with ⌘V. See [real-device QA](docs/MAC_DEVICE_QA.md).


### Diagnosing a failed paste (no clipboard contents collected)

The Quick Shelf now sends a **session-level Command-V** after checking the remembered destination is foreground. The prior PID-directed event path could fail to invoke application menu shortcuts. On a click, Clipboard records an in-memory diagnostic stage. Reopen the Shelf or visit **Settings → Paste Diagnostics** to see it, and use **Copy Paste Diagnostics** to share the result without disclosing copied content. Interpret the stages: `P1` click received, `P2` clipboard updated, `P3` focus restoration, `P4` Command-V dispatched (not proof of insertion), `E2` missing destination, `E3` missing Accessibility/event-posting permission, `E5` focus timeout, `E6` event creation failure. **Do not use an automated second keypress fallback:** macOS provides no reliable insertion acknowledgment, and blind retries can paste duplicate text.


## Accessibility and code identity (important)

Prior GitHub builds disabled signing completely, making `AXIsProcessTrusted()` and `CGPreflightPostEventAccess()` report `false` even though a Clipboard row appeared enabled in System Settings. CI now **ad-hoc signs the complete application after building it**, verifies its designated requirement and publishes `Clipboard-macOS-adhoc.zip`. Follow the **[exact post-install reauthorization steps](docs/TCC_SIGNING.md)** for this new build. Do not re-sign or change the app after granting access: that invalidates its version-specific code identity. The app's **Settings → Paste Diagnostics → Refresh TCC & Signing Status** displays the currently running bundle's code-signing mode, installation location and actual permission responses. This does not guarantee automatic insertion without a real-device Paste test.


**Latest signing evidence (2026-11-13):** [macOS Actions #43498945781](https://github.com/SaeedTqpy/Clipboard/actions/runs/43498945781) passed 62/62 tests and produced `Clipboard-macOS-adhoc` (Intel + Apple Silicon). CI verified `codesign --verify --strict`, `Signature=adhoc`, `Identifier=dev.clipboard.app` and a designated requirement. Real Mac Accessibility reauthorization and actual Notes paste remain to be tested on-device.
