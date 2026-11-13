# Real Mac acceptance: what only the device owner can test

GitHub Actions can validate compilation and isolated XCTest code, but it cannot
validate the user's actual macOS session, hardware permissions or target-app input.

## Setup (without local Xcode)

1. Download the [validated universal artifact](https://github.com/SaeedTqpy/Clipboard/actions/runs/43424718936) from the successful run (57/57 tests; 2026-11-13). Do not trigger another build for this version.
2. Unzip the outer artifact archive, then the nested Clipboard-macOS-adhoc.zip.
3. Copy Clipboard.app to /Applications. For ad-hoc signed preview, approve **your own trusted build** under System Settings → Privacy & Security if macOS blocks it.
4. Use the package diagnostic shell script in the repo:
   bash scripts/mac-smoke.sh /Applications/Clipboard.app
5. Start with **fake non-sensitive test strings only**, for example TEST-CLIP-001.

## On-device gates

- [ ] Start paused, then opt-in. Old clipboard entries must not backfill.
- [ ] Test **Win+Shift+V** on an external Windows keyboard (Command+Shift+V on Mac): only the full-width Shelf appears, flush with the physical bottom edge. Check display, Spaces, and shortcut conflicts.
- [ ] Left-click the Menu Bar icon to open a distinct **Clipboard Manager** window; right-click for Settings/Quit. Check manager and shelf never remain visible together.
- [ ] Quit older installed Clipboard instances before opening the new app; otherwise their hotkey registrations can interfere.
- [ ] Check Reduce Motion: animation disabled, shelf still usable.
- [ ] Create and apply colored tags on two synthetic clips, filter by a tag, edit it, and confirm encrypted backup restores it.
- [ ] Test copying and pasting a synthetic text item with and without Accessibility authorization.
- [ ] Click the **card preview** in Quick Shelf: copy, immediately close, restore Notes/Safari/VS Code focus, and insert the copied content once.
- [ ] Click **Copy** and the **••• menu** independently: they must not trigger automatic paste.
- [ ] Click a card in Manager: only select the clip, never auto-paste.
- [ ] Revoke Accessibility: preview click copies the clip, keeps the Shelf visible with an actionable permission warning, and triggers the macOS Accessibility/event-posting permission request. It must not send keyboard events.
- [ ] Paste into Notes, Finder, Safari, VS Code, and a Terminal. Verify correct target focus.
- [ ] Test HTML and RTF formatted copy plus Paste as Plain Text.
- [ ] Enable optional on-device OCR, copy a demo image, and search recognized text.
- [ ] Create, rename, edit and restore Snippets through encrypted backup.
- [ ] Verify keyboard navigation (↑↓, Return, ⌥Return, ⌘P) and shortcut preset changes.
- [ ] Verify hex color swatches for #RGB, #RRGGBB, #RRGGBBAA.
- [ ] Test images, multi-file selections and persistence after app relaunch.
- [ ] Test wrong/changed backup password, then portable backup on another Mac.
- [ ] Test app exclusions using a synthetic document and custom ignored bundle ID.
- [ ] Test launch at login after approving macOS Login Items prompts.
- [ ] Test VoiceOver, keyboard focus, zoom, Reduce Transparency, light/dark, and Retina displays.
- [ ] Test battery/CPU impact with 30 minutes of idle clipboard monitoring.
- [ ] Verify app never writes copied payloads to logs, telemetry or outbound requests.

**Do not test with real secrets until the release security review is complete.**

If one step fails, record: macOS version, chip (Intel/Apple Silicon),
clipboard item type, app used, steps to reproduce, screenshot with no secrets,
and a redacted Console excerpt. Hardware observations require user-provided evidence.


## Click-to-Paste reproducible acceptance test

1. Quit every older Clipboard app process, replace the app in Applications and relaunch. Inspect Accessibility permission for the newly installed app.
2. Open Notes, click the exact typing caret in a normal note, type `BEFORE-`, and keep Notes active.
3. Copy a harmless unique `TEST-PASTE-123` string in another app. Return to the Notes typing caret.
4. Press Command+Shift+V, then single-click the **preview body**, not Copy. Expected: Clipboard closes and `TEST-PASTE-123` is inserted *once* at the caret.
5. Reopen the Shelf. If the insertion did not happen, inspect the `P1/P2/P3/P4/E2/E3/E5/E6` stage; copy diagnostics from Settings. This is essential because permission approval alone cannot prove the target received the event.
6. Repeat in Safari text fields and VS Code, including an ordinary editable field rather than a protected password field.
7. Verify pressing Copy has no insertion side effect and menu actions do not invoke the main card Paste action.
8. Revoke Accessibility or Event Posting and confirm `E3` is shown **without closing** the Shelf; then restore permissions and relaunch.
9. Change to another app before the deferred dispatch and verify the destination guard prevents posting into the wrong app; no blind second attempts permitted.


## TCC signing regression gate

- [ ] Check `codesign --verify --strict /Applications/Clipboard.app` succeeds and `codesign -dv --verbose=4 /Applications/Clipboard.app` reports `Signature=adhoc` and `Identifier=dev.clipboard.app`.
- [ ] Ensure only one Clipboard process is running, and the actual bundle is `/Applications/Clipboard.app`, not an AppTranslocation path.
- [ ] After replacing an old unsigned/ad-hoc binary, explicitly reset only the Clipboard Accessibility grant with `tccutil reset Accessibility dev.clipboard.app`; reauthorize the **new** binary and quit/relaunch it.
- [ ] Settings → Paste Diagnostics → Refresh TCC & Signing Status reports `Accessibility (AX): true` and `Event Posting: true` before testing paste into Notes.
- [ ] Validate that a later ad-hoc build gets a new code identity and that a previous TCC grant is *not* assumed to work across versions.
- [ ] Never bypass TCC or disable SIP; distribution-quality persistence requires a stable Apple code signing identity.
