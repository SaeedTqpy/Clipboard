# Competitive landscape — Clipboard for macOS

**Research date:** 2026-11-13  
**Scope:** macOS clipboard products and first-party macOS 26 clipboard history.  
**Status:** feature positioning only; no benchmark or superiority claim without repeatable tests.

## What the market already provides

| Product | Notable confirmed features | Source |
| --- | --- | --- |
| **macOS 26 Spotlight** | Native searchable clipboard history with 30 minutes, 8 hours or 7 days retention; basic copy/reuse | [Apple Support](https://support.apple.com/en-ie/guide/mac-help/mchl54d95e8a/27/mac/27) |
| **Paste** | Bottom visual shelf, rename/edit, OCR search, filters, pinboards, Paste Stack, multiple-item paste, iCloud sync, local intelligent suggestions | [Paste on Mac help](https://pasteapp.io/help/paste-on-mac), [Paste updates](https://pasteapp.io/updates) |
| **Raycast Clipboard History** | Keyboard-first, image OCR, Paste as original/plain/HTML/RTF, rename/edit, snippets, QR detection, sequential paste, bulk-delete | [Raycast manual](https://manual.raycast.com/clipboard-history) |
| **Maccy** | Lightweight native history, fast text search, keyboard-first interaction, privacy exclusions | [Maccy official](https://maccy.app/) |
| **Alfred Powerpack** | Clipboard history, rich snippets, automatic text expansion, customizable hotkey, ignore list, clipboard merge | [Alfred clipboard](https://www.alfredapp.com/help/features/clipboard/) and [Alfred snippets](https://www.alfredapp.com/help/features/snippets/) |

**Implication:** history alone is no longer a sufficient feature, particularly since macOS 26 has its own basic solution. Differentiation must come from **speed, confident privacy controls, excellent keyboard use, polished native visual previews, and reusable workflows**.

## Comparison against our own app

| Capability | Prior Clipboard (verified source) | Current Clipboard source | Verification |
| --- | --- | --- | --- |
| Native macOS floating shelf | Implemented | Maintained | Prior macOS CI; new UI requires QA |
| Keyboard-first select/paste | Partial (⌘1–9) | ↑↓, Return, Option+Return, Cmd+P, quick paste, Cmd+Delete | Unverified on real Mac |
| Configurable global shortcut | Fixed ⌘⇧V | Presets: ⌘⇧V, ⌘⌥V, ⌃⌥V, ⌃⇧V, ⌥⇧V | Needs compilation and shortcut-conflict test |
| Images searchable by their text | Not available | Opt-in local Vision OCR stored in encrypted records | Needs CI and image recognition QA |
| Rename/edit clip | Not available | Encrypted display title and text editing, dedup integrity | Unit tests added |
| Reusable snippets | No dedicated action | Pinned Snippets collection, new/edit/save commands | Unit tests added; no background text expansion |
| Advanced filters | Kind/collection/pins | Also source app and Today/7/30-day filtering | Unit tests added |
| Bulk clear by time | Clear All | Selective last 5m/15m/1h/24h, retaining pinned clips | Unit tests added |
| Local encryption | AES-GCM with Keychain | Preserved; OCR and titles encrypted | Unit tests added |
| Portable backup | Password-encrypted archive | Preserves new title and OCR fields | Unit tests added |
| Online sync | None | Intentionally none | Privacy trade-off |
| Screenshot view or sharing | Not tested | Not promised | Real-device QA gate |

### Current milestone — implemented in code

1. **Keyboard-first navigation** with visible selected card and scrolling to the selected item.
2. **User-selectable shortcut presets**, with replacement registration attempted before the previous shortcut is removed.
3. **On-device image OCR** using Apple's Vision framework, opt-in so large images do not unexpectedly consume CPU. Recognition output is encrypted in the local clip record.
4. **Editable encrypted clip content**, human titles, duplicate checks and Search.
5. **Persistent Snippets**, implemented by pinned entries in a reserved collection (not auto-expansion).
6. **Source/date filters**, per-item image text extraction, and selective recent-history deletion with confirmation.
7. **Isolated tests** for editing, fingerprint deduplication, image OCR indexing, encrypted backup, safe recent-history deletion, time filters and hotkey preset data.

**CI status:** the competitive-feature batch compiled and passed **37/37 tests** in [macOS Actions run 43398219188](https://github.com/SaeedTqpy/Clipboard/actions/runs/43398219188), with an unsigned universal Release artifact. Hands-on usability/privacy acceptance is still required.

## Positioning: deliberate trade-offs

**Do not add cloud sync as a reflex.** A sync server (or even iCloud sync) changes the threat model, Keychain lifecycle, conflict resolution, privacy policy, incident response and user trust. Keep Clipboard local-first until encrypted cross-device designs are reviewed.

**Do not promise perfect password detection.** Most password managers provide markers, but application identity and pasteboard content markers are not secure provenance. Keep monitoring opt-in and private-content exclusions best-effort.

**Do not prioritize a heavier 3D app UI.** The landing site uses Three.js as a marketing experience; the desktop app should remain lightweight, instantly searchable, and native.

**No automatic typing/snippet expansion by default.** System-wide text expansion could require elevated Accessibility behavior and might insert snippets into password, terminal or privileged contexts. A separately audited opt-in expansion mode can be considered later.

## Production acceptance gates

- [ ] Latest macOS Actions build compiles, all automated tests pass, universal app archived.
- [ ] Verify keyboard navigation from actual focused text field on macOS 15 and 26.
- [ ] Validate shortcut registration conflicts, switching presets while shelf is visible, and startup with invalid preferences.
- [ ] On-device OCR benchmark for images, multilingual text, time spent on the main actor, thermal cost, and false positives.
- [ ] Test backup of encrypted OCR labels and snippet titles across Macs with different Keychain keys.
- [ ] Measure search latency at 1k, 5k and 10k records and RAM usage after long uptime.
- [ ] Validate paid/unpaid comparison based on actual desktop usage, not claims based on code size.
- [ ] Test screen sharing and system privacy behavior; avoid capturing real secrets during QA.

## Sources and change monitoring

Competitor features and prices evolve. Recheck official docs before publishing a comparison on the marketing site or making an explicit superiority claim.
