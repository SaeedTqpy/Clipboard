# Architecture — macOS native

## Process

Clipboard is a menu-bar-only macOS application. It uses **SwiftUI** for the floating panel and **AppKit** for NSPanel, NSPasteboard, status bar menu, frontmost-app restoration and paste integration. **Carbon** registers the global Command+Shift+V hotkey. No Electron, browser runtime, backend or network calls are used.

## Data path

1. Poll NSPasteboard.changeCount every 650 ms on the main run loop.
2. Ignore paused state, concealed/transient pasteboard types and common password-manager bundle IDs.
3. Accept text, http/https URLs, PNG screenshots and file URLs; reject oversized payloads.
4. SHA-256 fingerprints deduplicate entries.
5. Persist metadata and text in local SQLite with FTS5; store PNG bytes in Application Support/Clipboard/Assets.
6. Retain 30 days and a maximum 1,000 unpinned records. Pinned clips are retained.
7. Show up to 500 clips in the horizontally scrolling panel.

## Security limitations and follow-ups

- **Clipboard content is sensitive**. SQLite and image assets are currently plaintext on disk: do not claim at-rest encryption. Add application-level encryption and configurable ignore lists before wide distribution.
- Password-manager bundle matching and pasteboard type checks are **best-effort**, not a guarantee that secrets are never captured. A user-configurable per-app blocklist and exclusion rules are required.
- Automatic paste requires macOS Accessibility permission. Copy-only does not.
- No telemetry, sync, clipboard content logging or network services.
- Never use the GitHub CI environment to upload actual user clipboard data.
- Unsigned CI artifacts are for personal testing; public distribution needs Developer ID signing and notarization.
- The app is not sandboxed yet because global shortcuts and synthetic paste integration need careful permission validation. Assess sandbox requirements separately for App Store distribution.

## Compatibility

- Deployment target: macOS 15.
- Genuine SwiftUI Liquid Glass modifiers used on macOS 26+; native material fallback on macOS 15–25.
- CI attempts a universal arm64/x86_64 unsigned artifact.
