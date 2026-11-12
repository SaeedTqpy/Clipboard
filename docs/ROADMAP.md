# Production roadmap

## Phase 1 — functional native foundation (in repository)

- Native menu-bar agent, floating NSPanel, Liquid Glass toolbar on macOS 26.
- Command+Shift+V global hotkey.
- Text, links, images and file URL capture.
- Local SQLite history, deduplication, FTS5 search, pin/delete/clear.
- Copy and accessibility-gated direct paste.
- Pausing, basic private-source exclusions, retention policy.
- Unsigned GitHub Actions builds + unit tests.

## Phase 2 — hardening (required before general release)

- Build and verify on macOS 26 runner and on real Apple Silicon + Intel hardware.
- Focus and keyboard navigation, reliable close-on-click-outside behavior.
- Search focus when panel opens; Cmd+1..9, arrow navigation, quick actions.
- Image lazy thumbnails, image-memory and database latency profiling.
- Per-app ignore rules, private mode, content-type filters, adjustable retention.
- Safe metadata migration strategy, SQLite integrity/backup/recovery, database corruption UX.
- Secure-at-rest data strategy, threat model and secret-leakage tests.
- Accessibility permission onboarding; test paste in browsers, terminals, password fields and fullscreen apps.
- Localization, VoiceOver, high contrast, reduced motion, multiple displays.
- Crash diagnostic opt-in only; no clipboard payload collection.
- Automated UI tests and performance regression suite.

## Phase 3 — Paste-class capabilities

- Collections, favorites, custom tags and pinned workspaces.
- Paste Stack, plain-text paste, copy/paste transforms.
- Preview of HTML, rich text and multi-file records.
- App-specific shortcuts, import/export with explicit privacy controls.
- Optional encrypted device sync only if explicitly requested.

## Distribution

Unsigned local artifacts do not need Apple Developer membership. Public no-warning downloads will later need code signing and Apple notarization.
