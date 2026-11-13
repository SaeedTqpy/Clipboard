# Clipboard — macOS manual acceptance and security test plan

The GitHub Actions runner cannot verify real user input, Accessibility authorization or native Mac clipboard integration. Do not mark any checklist item complete without evidence.

## Build gate

- [x] Trigger exactly one restricted milestone validation after fixing failures; restore manual-only CI after it starts.
- [x] All 29 unit/performance tests pass (privacy exclusions, migration, encryption, backup, recovery).
- [x] Universal arm64/x86_64 Release was produced; nested ZIP SHA-256 matched SHA256SUMS.txt.
- [ ] On a real Mac, run the package diagnostic and check macOS security prompts.
- [ ] Run the app on an actual macOS 26 Mac; check fallback on macOS 15–25.
- [ ] Verify Liquid Glass effect only on macOS 26; reduced transparency remains usable.

## Encryption and migration

- [ ] Fresh installation defaults to paused; copied data is not persisted until enabled.
- [ ] SQLite does not contain copied text, file paths or source names in readable form.
- [ ] Asset files contain authenticated ciphertext, not plaintext PNG data.
- [ ] Changing the Keychain key prevents decryption and fails closed without resetting history.
- [ ] Migrating legacy v2 DB retains pins, collections and image assets, removes legacy FTS.
- [ ] Interrupt a copied test migration midway; re-launch with no silent loss.
- [ ] Move a damaged DB to quarantine after explicit confirmation; verify original files remain intact.
- [ ] Check that data from old backups/APFS snapshots may persist despite VACUUM.

## Backup and restore

- [ ] Export with a 12+ character passphrase; source never leaves app as plaintext.
- [ ] Restore on a second Mac using only the backup file and passphrase.
- [ ] Wrong password or tampered backup does not change history.
- [ ] Preserve pins, collections, image previews and copyable text after restore.
- [ ] Restore duplicate records without creating duplicates; backup import stays atomic.
- [ ] Oversized backup yields an actionable error.
- [ ] Missing external file URL is handled without crashing; actual external file bytes are not in the backup.

## Capture and user interaction

- [ ] Capture Persian and English text, code, links, HTML/RTF rich text and images from multiple apps.
- [ ] Verify formatted Paste preserves rich text and Paste as Plain Text strips formatting.
- [ ] Copy multiple files in Finder, then paste into Finder with selection intact.
- [ ] Excluded bundle IDs and known concealed/transient annotations suppress capture.
- [ ] Toggle image and file capture; paused content is not imported on resume.
- [ ] Duplicate copies move the old item to top without losing pin/collection.
- [ ] Search, pin, collections, kind filters, clear and Paste Stack operate correctly.
- [ ] ⌘⇧V and ⌘1–9 work with keyboard focus, including text field and fullscreen apps.
- [ ] Clicking outside the panel closes it; panel appears on correct display.
- [ ] Direct Paste to Notes, Finder, Safari, browser inputs and VS Code; verify target focus.
- [ ] Clipboard doesn't synthesize keystrokes without Accessibility permission.
- [ ] Launch-at-login works, or provides actionable signed-build limitation.

## Competitive features QA

- [x] Updated macOS CI on competitive-feature batch: 37/37 automated tests successful, universal Release built in [run 43398219188](https://github.com/SaeedTqpy/Clipboard/actions/runs/43398219188).
- [ ] Navigate shelf with ↑↓, paste with Return and Option+Return; verify typing in Search still works.
- [ ] Test Cmd+P, Cmd+Delete confirmation and Cmd+1–9 with keyboard and multiple windows.
- [ ] Change global shortcut preset; verify conflict rejection leaves prior shortcut functional.
- [ ] Enable OCR, copy a known test screenshot and search for its recognized text, with no network requests.
- [ ] Disable OCR; verify no new recognition is performed.
- [ ] Create/edit a Snippet, leave pinned, restart app and check data remains searchable and encrypted.
- [ ] Verify renamed clips and OCR text survive portable encrypted backup/restore.
- [ ] Filter source app/date and clear last 5/15/60 minutes without deleting pins.
- [ ] Verify text edits update fingerprints and do not silently merge duplicate clips.

## Verified CI milestone — 2026-11-13

- [x] Compiled the latest animated bottom shelf and encrypted color tags on macOS 26.
- [x] **66/66 XCTest tests passed**, including geometry and tag lifecycle tests.
- [x] Release compiled for both x86_64 and arm64.
- [x] Artifact ZIP integrity and inner application archive SHA-256 verified.
- [x] Restored macOS CI to manual-only after batched validation.
- [ ] Real-device visual acceptance, Dock/Space transitions, Accessibility and Paste focus checks still required.

Evidence: [macOS Actions #43417580697](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795).

## Separate Quick Shelf and Clipboard Manager (new milestone)

- [ ] The Quick Shelf starts at the **physical screen bottom** with no gap, including when a Dock is visible.
- [ ] The lower shelf corners are square and no drop shadow makes it appear detached.
- [ ] **Win+Shift+V** (default Command+Shift+V on a Mac) opens only Quick Shelf. Verify migration of the old Control+Shift+V default and preservation of other customized shortcuts.
- [ ] Quick Shelf preview click copies, closes immediately, restores previous application focus, and pastes once. The Copy and menu buttons do not trigger the preview action.
- [ ] Manager preview click selects only. Without Accessibility or Event Posting permission, Shelf click copies, stays visible with an actionable error, and never injects Cmd+V.
- [ ] Left-click the menu bar icon: a normal, movable, resizable Clipboard Manager opens; Quick Shelf is hidden.
- [ ] Right-click the menu bar icon: context menu with Pause/Settings/Quit is displayed.
- [ ] Open the manager first then press the hotkey: only Quick Shelf remains. Open the shelf first then click the menu bar icon: only Manager remains.
- [ ] Run an old app version at the same time as the new build; verify that the new build requests graceful termination of the old same-bundle-id copy, and no two windows respond to one shortcut.
- [ ] Verify the Dock doesn't hide card buttons despite the outer shelf reaching the bottom edge.
- [ ] Check app focus and automatic Paste after transitioning from manager to shelf.
- [ ] Verify secondary-monitor physical screen coordinates and Reduce Motion.

## Bottom shelf and encrypted tags

- [ ] On macOS 15 and 26, show the shelf and confirm it slides up from beneath the physical screen edge, without presenting as a centered window.
- [ ] Verify the shelf anchors immediately above the Dock's visible area and spans almost all available display width.
- [ ] With two monitors of different positions/resolutions, invoke the hotkey with the pointer on each screen; no clipping or wrong-screen display.
- [ ] Press Escape or click outside; shelf slides downward and becomes non-interactive.
- [ ] Activate Paste from the shelf; panel releases focus immediately and sends Cmd+V only to the expected target application.
- [ ] Enable Reduce Motion; show/hide skips animations completely.
- [ ] Check light/dark modes, 125% zoom, VoiceOver and 650pt-wide window fallbacks.
- [ ] Capture text, links, images, file references and HEX color; confirm type ribbons have distinct colors.
- [ ] Create a custom tag, reuse it on a second clip, click tag to filter, rename/recolor via context menu, and remove it from one clip.
- [ ] Confirm five-tag limit, disappearance when removing the last reference, and search by encrypted tag name.
- [ ] Verify old encrypted history with missing tags field still opens with empty tags.
- [ ] Export encrypted backup and restore to isolated store; tag names/colors and associations survive.
- [ ] Inspect SQLite: sensitive tag names must not appear as plaintext.

## Performance and quality

- [ ] Fast scrolling of 500 clips with many images doesn't trigger large CPU spikes.
- [ ] Copying large images never blocks the main event loop.
- [ ] Energy use over 30 minutes of idle polling is acceptable.
- [ ] Search among 5,000 encrypted records remains responsive; cache stays bounded.
- [ ] Unpinned image assets are pruned at 512 MiB; pinned assets are exempt.
- [ ] App launches and stores history with locked/unlocked Keychain behavior understood.
- [ ] No clipboard contents are logged, uploaded or included in crash diagnostics.
- [ ] VoiceOver, high contrast, reduced motion and Persian UI are reviewed.

## Release gate

A successful compilation is **not** a production-release approval. Complete encryption, migration, security, device, usability and performance gates before a wider beta. Distributable signed/notarized versions require a suitable Apple Developer account.

## Win-key shortcut and one-click paste — verified CI, 2026-11-13

- [x] Mac CI: **66/66 XCTest cases successful** (includes shortcut migration and shelf-versus-manager card tap routing).
- [x] Universal Intel x86_64 / Apple Silicon arm64 unsigned Release built: [Actions #43424718936](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795).
- [x] Inner app ZIP SHA-256 matches the bundled checksum.
- [ ] Physical Windows-logo modifier keyboard mapping and focus-safe insertion into Notes/VS Code/Safari still require manual on-device QA.

## Custom app icon — validated 2026-11-13

- [x] Script draws ten PNG variants and macOS `iconutil` generates ICNS in XcodeGen pre-build phase.
- [x] App Info.plist includes `CFBundleIconFile=Clipboard.icns` (explicit plist generation).
- [x] CI extracts the bundled ICNS as an iconset; 1024px entry is present.
- [x] 66/66 tests passed; unsigned universal Release built [here](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795).
- [ ] Confirm actual Finder and Dock display and icon caching on a user's Mac.

## Click-to-Paste reliability — regression after user report

- [x] Decorative ClipCard border no longer participates in hit-testing.
- [x] Remember last active **regular** external app independently of a nonactivating key panel.
- [x] Run unit tests for foreground PID resolution, stale fallback, no-self-target, and no posting into unrelated processes.
- [x] Use PID-directed keyboard events instead of a global HID event stream; cancel pending paste if a new shelf session starts.
- [x] Gate Paste on both Accessibility and Quartz Event Posting access; show an actionable permission warning instead of closing silently.
- [ ] Observe the real macOS control path: focus text field in Notes → Cmd+Shift+V → click card preview → Shelf closes and text is inserted exactly once.
- [ ] Repeat after making Clipboard the foreground app, switching Spaces, and using a second display.
- [ ] With permission denied, ensure the Shelf remains visible, text is copied, and macOS requests access.
- [ ] Verify clipboard data remains intact when a destination rejects focus activation; user can paste manually.

### Verified automated results — 2026-11-13

[macOS Build #43501819795](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795): **66/66 XCTest cases passed**; Universal Release for x86_64 + arm64 built; bundled icon validation and packaging passed. Archive SHA-256 was independently matched against included SHA256SUMS. **This validates compilation and routing policy, not the physical result of a click-to-paste on the user's Mac.**


## Session-command paste and redacted diagnostics

- [x] Removed PID-directed shortcut delivery for the foreground application's Edit → Paste shortcut.
- [x] Use `CGEvent.post(tap: .cghidEventTap)` once, only after the remembered target is frontmost.
- [x] Bounded focus restoration retry, never resend the keystroke after dispatch.
- [x] In-memory diagnostic phases with no clipboard contents; settings can copy phase and permission flags.
- [ ] On a real Mac, confirm the target app receives exactly one Command-V in Notes, VS Code and Safari.
- [ ] If output is missing, collect redacted P/E stage before changing the event delivery again.

## Validated session Command-V build — 2026-11-13

- [x] [macOS Actions #43501819795](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795) passed **66/66 XCTest cases** and produced an unsigned universal `x86_64` + `arm64` app.
- [x] Custom bundled ICNS verified; inner `Clipboard-macOS-unsigned.zip` checksum matches included SHA256SUMS.
- [x] All production/test source files at main match the validated commit.
- [ ] User-device acceptance required: after clicking a card, confirm exactly one insertion into Notes/Safari/VS Code; use `Paste Diagnostics` and report stage code if not.


## Accessibility identity fix — macOS release validation

- [x] CI produces an ad-hoc **signed** (not fully unsigned) universal `Clipboard.app` before ZIP.
- [x] `codesign --verify --strict` succeeds on the exact app that is subsequently packaged.
- [x] `codesign -dv` reports `Identifier=dev.clipboard.app` and `Signature=adhoc`.
- [x] `codesign -d -r-` returns a designated requirement.
- [x] Automated tests validate signature classification and App Translocation / install path detection.
- [ ] On a real Mac, reset and regrant Accessibility to the **installed new build**; the app's own audit changes to AX=true and EVENT=true; then validate actual Paste.

### Verified TCC-identity packaging milestone

[GitHub Actions #43501819795](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795): **66/66 tests passed** and `Clipboard-macOS-adhoc` published with a verified `dev.clipboard.app` ad-hoc signature and designated requirement. **Pending:** reinstall/reauthorization and real paste on user's Mac.

## Independent PostEvent permission regression

- [ ] Apple-documented `PostEvent` denial is diagnosed independently from AXUIElement trust.
- [ ] `AX=true/PostEvent=false` shows `E3P` and requests the actual PostEvent service, without resetting AX.
- [ ] `AX=false/PostEvent=true` is allowed through the keyboard Paste permission gate (no AXUIElement APIs are used for the simulated shortcut).
- [ ] Settings exposes independent buttons for Request Event Posting Access and Request Accessibility Access.
- [ ] UI provides only `tccutil reset PostEvent dev.clipboard.app` as the scoped reset for this denial.
- [ ] After permission grant, fully quit/relaunch before relying on fresh preflight results.
- [ ] Test keyboard insertion exactly once in Notes after `PostEvent=true` on the user's device.

### PostEvent macOS build verified — 2026-11-13

- [x] [GitHub Actions #43501819795](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795) passed **66/66 XCTest cases** and produced a valid Ad-hoc signed Universal app (arm64+x86_64).
- [x] Verified inner ZIP SHA-256 matches published SHA256SUMS exactly.
- [x] Independent PostEvent denial diagnostic and permission request path are implemented and unit-tested.
- [ ] Device acceptance: reset only PostEvent for this exact build, request PostEvent, restart, verify preflight true and a single successful Paste in Notes.


## Native Liquid Glass redesign — visual acceptance

- [ ] macOS 26 glass shell and floating toolbar controls use system glass rather than an opaque black surface.
- [ ] macOS 15 fallback uses genuine system materials and remains readable.
- [ ] Comfortable cards are 322×283 pt; Compact 278×243 pt and changes Shelf height immediately.
- [ ] Dock bottom remains visible in front of the Shelf; window touches physical bottom, content is padded above Dock.
- [ ] Dock on left/right does not create a false bottom gap. Secondary screens and negative origins work.
- [ ] User search, filters, tags, metadata and error messages stay readable in dark and light themes.
- [ ] Card hover respects Reduce Motion. No nested card buttons and no click interception by decorations.
- [ ] Paste and manager navigation behavior from existing validated tests remain intact.
