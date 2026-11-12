# Clipboard — native macOS clipboard manager

**SwiftUI + AppKit · Liquid Glass on macOS 26 · SQLite/FTS5 · Universal Mac build**

Clipboard is a menu-bar utility with an adaptive floating history shelf. This repository is under active development. It is **not yet ready for public production distribution**.

## Implemented

- **Global shortcut:** ⌘⇧V toggles a floating bottom shelf, including fullscreen/Spaces.
- **Capture:** text, HTTP(S) links, images (PNG assets), single and multi-file selections, with duplicate suppression.
- **History:** local SQLite, full-text search, time ordering, pinned items, kind filters, collections and per-card actions.
- **Quick paste:** ⌘1–9 for the visible cards, Copy and Paste buttons; pasting is gated on Accessibility permission and target-app focus.
- **Paste Stack:** queue up to 100 clips and paste sequentially; the queue is intentionally in-memory for now.
- **Privacy:** monitoring is **paused on first launch**, user-defined app exclusions, predefined sensitive/transient pasteboard exclusions, opt-out of image/file capture, clear all.
- **Retention:** user-configurable 1–365 days, 50–5,000 unpinned clips, pinned items exempt.
- **Settings:** access from the floating shelf or menu bar, with a picker for currently running apps and an Accessibility permission request button.
- **Local storage:** SQLite with WAL and FTS5 and a versioned schema migration; PNG files in Application Support.
- **Build:** GitHub Actions universal arm64/x86_64 unsigned development artifacts, without a paid Apple Developer account.

## Build without local Xcode or an Apple Developer account

**CI is manual-only to preserve GitHub Actions minutes.** Pushes and PRs do not trigger a build.

1. Open [GitHub Actions](https://github.com/SaeedTqpy/Clipboard/actions/workflows/macos.yml).
2. Choose **Run workflow** on the \`main\` branch.
3. Wait for the unit tests and universal Release build.
4. Download the \`Clipboard-macOS-unsigned\` artifact from the completed run. The nested ZIP includes the app and a SHA-256 checksum.

The unsigned build may be blocked by Gatekeeper. For a build you trust, use **System Settings → Privacy & Security → Open Anyway**. Developer ID signing and notarization are necessary for ordinary public distribution.

### Local build (optional)

\`\`\`bash
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild test -project Clipboard.xcodeproj -scheme Clipboard -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Clipboard.xcodeproj -scheme Clipboard -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
\`\`\`

## Privacy limitations

Copied data can include authentication tokens, passwords, private keys and personal records. **History is currently stored as plaintext on disk**, including text in the SQLite index and image assets. Password-manager exclusion and pasteboard type labels are **best effort**; some apps do not annotate secret copies, and a foreground-app heuristic can misattribute copies around focus changes. Never promise guaranteed credential protection. Monitoring starts paused until the user enables it.

There is **no network sync, no analytics, and no clipboard payload logging**. For strong security, application-level encryption, threat-model review, App Sandbox feasibility and handling secrets from uncooperative apps must be completed before broad release.

## Repository

- \`Clipboard/ClipboardApp.swift\` — AppKit panel, menu bar, global shortcut and paste target restoration
- \`Clipboard/ClipboardMonitor.swift\` — monitored NSPasteboard types and source exclusions
- \`Clipboard/ClipboardStore.swift\` — SQLite persistence, FTS search, migrations, retention and assets
- \`Clipboard/ClipboardPrivacy.swift\` — capture policy and preferences
- \`Clipboard/ClipboardModel.swift\` — state, collections, filters, Paste Stack and commands
- \`Clipboard/ClipboardPanelView.swift\` — macOS SwiftUI shelf, cards and settings
- \`ClipboardTests/\` — isolated store and policy unit tests
- \`docs/TEST_PLAN.md\` — hardware and usability test plan

## Compatibility

Minimum deployment target **macOS 15**. Native Liquid Glass effects are used on **macOS 26+**, with system materials as fallback on macOS 15–25. GitHub Actions uses \`macos-26\` to compile universal builds.

For unresolved release blockers, see [ROADMAP](docs/ROADMAP.md) and [ARCHITECTURE](docs/ARCHITECTURE.md).
