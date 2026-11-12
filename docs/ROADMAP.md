# Clipboard production roadmap

## Implemented — functional foundation (code committed; final batch not yet CI-validated)

- SwiftUI/AppKit floating shelf, native Liquid Glass on macOS 26, fallback materials.
- Menu bar utility, first-launch discovery and fixed ⌘⇧V global shortcut.
- Text, links, images, single/multi-file clipboard history, deduplication.
- SQLite/FTS5 indexing, schema versioning, retention maintenance and pinned clips.
- Collections, kind filters, quick visible-card shortcuts, copy/paste actions.
- Sequential session-only Paste Stack and conservative destination PID check.
- Opt-in monitoring, image/file toggles, best-effort sensitive app/type exclusions and app exclusion UI.
- Manual-only GitHub Actions building unsigned universal Mac artifacts, unit tests.

## Next release blockers (must be implemented and verified)

1. **Security:** threat model, encrypted-at-rest content/index design, Keychain key lifecycle, secret exclusion edge cases, loss-of-device response, user privacy consent and security tests.
2. **Correctness:** complete UI/permission integration tests on macOS 15 and macOS 26, app-to-app paste reliability, clipboard rich data, HTML/RTF, file disappearance and multi-selection behavior.
3. **Performance:** move image decode and disk writes off main actor; decode thumbnails lazily; tune polling/energy use, memory footprint, disk quotas and massive-history search.
4. **UX:** reliable dismiss-on-click-outside, arrow-key selection, configurable shortcuts, drag-and-drop reordering, paste-as-plain-text commands, editing/searching collections, enhanced previews.
5. **Storage:** robust backup/restore/import/export with explicit disclosure, corruption recovery, transactional asset cleanup and safe disk caps.
6. **macOS integration:** launch at login, permission onboarding, app icons, explicit accessibility status, multiple displays/screen sizes, localization, VoiceOver and reduced motion.
7. **Release engineering:** reproducible toolchain pinning, UI test suites, signed Developer ID DMG, Apple notarization, versioned release notes and update strategy.

## No paid Apple Developer account today

Continue using unsigned local builds. Apple notarization and broadly distributable warning-free releases must wait until a Developer ID account and certificates are available.

## CI policy

\`.github/workflows/macos.yml\` only responds to \`workflow_dispatch\`. There are no automatic runs on push or pull requests; trigger a build only at a meaningful validation checkpoint.
