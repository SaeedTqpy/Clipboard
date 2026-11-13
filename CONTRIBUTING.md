# Contributing to Clipboard

Thanks for helping improve Clipboard, a native SwiftUI + AppKit macOS clipboard manager.

## Before you begin

- Read the [README](README.md), [security guidelines](SECURITY.md), [architecture](docs/ARCHITECTURE.md), and [roadmap](docs/ROADMAP.md).
- Clipboard is currently a **developer preview**, not a production release.
- The repository **does not yet have a software license**. Before incorporating project code into another project or redistributing a derivative, obtain permission from the rights holder.
- **Never commit real clipboard contents, secrets, local SQLite databases, Keychain data, or screenshots of confidential information.**

## Reporting issues

When filing a bug report, provide the macOS version, processor type, app version/commit, steps to reproduce, expected versus actual behavior, and sanitized logs. Use synthetic example text such as `CLIPBOARD-TEST-001`. For suspected vulnerabilities, follow [SECURITY.md](SECURITY.md) instead of filing a public proof-of-concept.

## Development workflow

1. Start from `main` and use a descriptive topic branch for your change.
2. Keep platform integration in AppKit/Carbon, UI in SwiftUI, and storage/security in the corresponding core files.
3. Add or update isolated XCTest cases for correctness changes, especially retention, migration, backup, privacy, and clipboard monitoring.
4. Run XcodeGen and local tests when you have the macOS toolchain:

   ```sh
   brew install xcodegen
   xcodegen generate --spec project.yml
   xcodebuild test -project Clipboard.xcodeproj -scheme Clipboard \
     -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
   ```

5. If you do not have Xcode, GitHub Actions can compile the project; the [workflow](https://github.com/SaeedTqpy/Clipboard/actions/workflows/macos.yml) runs **only on manual request** to conserve hosted macOS minutes.
6. Do **not** re-enable push/PR-triggered Actions without the maintainer's express consent.
7. Verify that any UI or clipboard behavior change has an updated device test item in [MAC_DEVICE_QA.md](docs/MAC_DEVICE_QA.md).

## Technical guidelines

- Keep local-first behavior; no clipboard telemetry, network upload or logging of copied content.
- Treat app/source exclusion rules as **best-effort**. Never claim they can infallibly detect secrets.
- Preserve Keychain/AES-GCM boundaries and never add a plaintext search index or debug payload dump.
- Migration must be non-destructive on failure and tested against a copy of older schemas.
- Avoid synchronous image decoding and unbounded allocations on the main actor.
- Provide accessibility labels, keyboard navigation and usable reduced-transparency fallback when modifying views.
- All new screenshots should be real, show **synthetic data**, and come from a Mac running the actual app; see [SCREENSHOTS.md](docs/SCREENSHOTS.md).
- Do not submit signed certificates, provisioning secrets or developer-account credentials.

## Scope of a good pull request

Keep a focused description of the motivation, the code changes, tests run, screenshots (if UI changed), compatibility risks and any remaining manual verification.

**User-session testing is a release gate.** A successful GitHub Actions run does not prove that auto-paste, Accessibility authorization, or multi-display focus behavior works on a physical Mac.
