# Real Mac acceptance: what only the device owner can test

GitHub Actions can validate compilation and isolated XCTest code, but it cannot
validate the user's actual macOS session, hardware permissions or target-app input.

## Setup (without local Xcode)

1. In GitHub Actions, manually build and download the successful universal artifact.
2. Unzip the outer artifact archive, then the nested Clipboard-macOS-unsigned.zip.
3. Copy Clipboard.app to /Applications. For unsigned code, approve **your own trusted build** under System Settings → Privacy & Security if macOS blocks it.
4. Use the package diagnostic shell script in the repo:
   bash scripts/mac-smoke.sh /Applications/Clipboard.app
5. Start with **fake non-sensitive test strings only**, for example TEST-CLIP-001.

## On-device gates

- [ ] Start paused, then opt-in. Old clipboard entries must not backfill.
- [ ] Test ⌘⇧V with Notes and Finder frontmost; reveal/hide, switch Spaces, move cursor between monitors.
- [ ] Test copying and pasting a synthetic text item with and without Accessibility authorization.
- [ ] Paste into Notes, Finder, Safari, VS Code, and a Terminal. Verify correct target focus.
- [ ] Test HTML and RTF formatted copy plus Paste as Plain Text.
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
