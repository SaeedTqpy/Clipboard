# macOS Accessibility/TCC signing — Clipboard local preview

## Root cause observed

The older GitHub Actions workflow built the Release bundle with
`CODE_SIGNING_ALLOWED=NO` and then distributed the unsigned .app. A visible
Clipboard toggle in Privacy & Security → Accessibility is **not evidence that
this exact binary is authorized**: `AXIsProcessTrusted()` queries the running
process. User-device diagnostics observed `E3 · AX=false EVENT=false` with the
toggle enabled. This is consistent with invalid or unmatched TCC identity,
though only on-device checks can fully confirm the cause.

Apple [TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
documents that unsigned code lacks a Designated Requirement. Ad-hoc signed
code has a requirement tied to that exact build hash, not a stable developer
identity. Apple recommends a stable Apple Development/Developer ID identity
for durable TCC permissions.

## What this project changes

The manual GitHub Actions workflow now:

1. Builds and tests the universal macOS app.
2. Creates and verifies the production icon.
3. Runs `codesign --force --sign - --identifier dev.clipboard.app` on the
   **complete Release app bundle**.
4. Verifies `codesign --verify --strict` and the signing identifier.
5. Checks for an ad-hoc signature and a designated code requirement.
6. Packages the exact signed app as `Clipboard-macOS-adhoc.zip` in the
   `Clipboard-macOS-adhoc` GitHub artifact.

**This is a version-specific local signature.** It does not provide
Developer ID distribution, notarization, or enduring TCC permission across
updates. There is no bypass of Accessibility, Input Monitoring or SIP.

## Required one-time steps for this new artifact

Do these in this exact order **after downloading the new signed build**.
Resetting TCC against the older unsigned version before installation will
not authorize the new signed binary.

1. Quit every running Clipboard process (Activity Monitor, including copies
   from Downloads) and remove any older app copy you use.
2. Extract the outer GitHub artifact ZIP and then the inner
   `Clipboard-macOS-adhoc.zip`. Move **Clipboard.app** into
   `/Applications/Clipboard.app`. Do not launch it from Downloads or directly
   from inside the ZIP. Do not re-sign or modify its contents.
3. Verify the installed bundle in Terminal (no sudo):

   `codesign --verify --strict --verbose=2 /Applications/Clipboard.app`

   `codesign -dv --verbose=4 /Applications/Clipboard.app 2>&1 | grep -E 'Identifier=|Signature=|CDHash='`

   The output should contain `Identifier=dev.clipboard.app`,
   `Signature=adhoc` and a valid signature.

4. Run **once, for this exact build**:

   `tccutil reset PostEvent dev.clipboard.app`

   This is scoped to Clipboard's keystroke-posting service. Reset Accessibility **only when AX is actually false and needed for a distinct AXUIElement feature**.
5. Launch **the new app** from /Applications. Under System Settings →
   Privacy & Security → Accessibility, remove the stale Clipboard entry if
   shown and add/select the new `/Applications/Clipboard.app`. Enable it.
   Approve macOS's permission request if shown.
6. Fully **Quit Clipboard and relaunch it** from /Applications (do not merely
   hide the shelf). In Settings → Paste Diagnostics press
   **Refresh TCC & Signing Status**. Confirm `Accessibility (AX): true`
   and `Event Posting (PostEvent): true`. The latter is the required grant for keyboard Paste.
7. Open Notes, place a text caret and invoke `Win+Shift+V` (mapped to
   Command+Shift+V), then click a clip. Verify a **single** insertion.

If permission still reports false, use `bash scripts/inspect-permission-identity.sh`
to check code identity, App Translocation, and duplicate process paths without
changing TCC. Copy Paste Diagnostics from the running app. Do not keep
switching the same toggle without examining these results.

## Important limitations

- **No Developer ID account:** The CI artifact can be ad-hoc signed but cannot
  provide stable trusted identity between versions. Grant approval again after
  each new artifact if macOS rejects the old TCC requirement.
- **Do not re-sign after authorization:** This changes the ad-hoc CDHash and
  invalidates the permission match. Avoid patching the contents of Clipboard.app.
- **No automatic authorization:** The app can request permission; the user
  must approve it. Do not edit TCC.db, disable SIP, or grant Full Disk Access
  just to solve this issue.
- **Event Posting is not Input Monitoring:** Posting Command-V does not need
  reading all keys. The diagnostics are separate preflight checks relevant to
  Accessibility and synthetic event delivery.
- **Privacy:** The read-only audit reports bundle ID, location category,
  signature category and permission booleans, but no clipboard text, tokens,
  images or raw filesystem paths.
- **Still requires device QA:** GitHub CI cannot approve macOS Accessibility
  for the user's desktop or verify text insertion into Notes.

## Sources

- [Apple TN3127 — Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
- [Apple AXIsProcessTrusted](https://developer.apple.com/documentation/applicationservices/1460720-axisprocesstrusted)
- [Apple AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)
- [Apple Creating distribution-signed code for macOS](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac)

## CI verification — 2026-11-13

[GitHub Actions run #43501819795](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795) passed **66/66 tests**, created the Universal `arm64/x86_64` release, ad-hoc signed the final app and verified its designated requirement. The uploaded `Clipboard-macOS-adhoc` artifact contains an inner ZIP with a working `_CodeSignature/CodeResources` and its matching SHA-256 checksum. No real-device TCC authorization has been asserted.

## macOS PostEvent service — independent of Accessibility

The real-device screenshot after installing the signed build reports **AX=true EVENT=false**. This is a separate `kTCCServicePostEvent` denial, not an Accessibility grant problem. Apple explicitly documents `PostEvent` as a TCC service for *sending keystrokes*. Both `CGPreflightPostEventAccess()` and `CGRequestPostEventAccess()` relate to this service. The Clipboard UI now requests the correct permission independently, and the keyboard paste guard requires PostEvent instead of incorrectly requiring both AXUIElement and PostEvent.

After installing this corrected build: quit every Clipboard process; run `tccutil reset PostEvent dev.clipboard.app` **without sudo**; open the same app from `/Applications`; use `Settings → Paste Diagnostics → Request Event Posting Access`; approve the native prompt; quit and relaunch once more. Then Refresh the diagnostic and confirm `Event Posting (PostEvent): true`. A reset of Accessibility alone will **not** clear a denied PostEvent decision. Do not change SIP or TCC.db.

Sources: [Apple reset documentation](https://developer.apple.com/documentation/xcode/resetting-access-to-protected-resources-in-macos) (PostEvent = sending keystrokes), [Apple CGRequestPostEventAccess](https://developer.apple.com/documentation/coregraphics/cgrequestposteventaccess()), [Apple TCC/PostEvent developer discussion](https://developer.apple.com/forums/thread/842985).

## New PostEvent permission artifact

[Build #43501819795](https://github.com/SaeedTqpy/Clipboard/actions/runs/43501819795) passes **66/66 tests** with Ad-hoc signing and a verified ZIP checksum. After installing this version, **quit Clipboard**, run `tccutil reset PostEvent dev.clipboard.app`, relaunch from `/Applications`, use **Request Event Posting Access** in Settings, approve, fully quit and relaunch again. In the audit, `Event Posting (PostEvent): true` is the gate for the CGEvent shortcut. This build is not proof of a real-world paste until tested on the user Mac.


## First-install UX (new)

The first launch checks `CGPreflightPostEventAccess()` and, if permission is
missing, presents a purpose-built Quick Paste setup sheet in the Manager.
The user clicks **Request Paste Access**, which calls the macOS
`CGRequestPostEventAccess()` API. Alternatively, the user can open Privacy
Settings, refresh the permission state, or continue with copy-only mode.
Right-clicking the Menu Bar icon exposes **Enable Quick Paste…** while
PostEvent is missing.

No app code can approve its own macOS TCC permission, silently run a TCC reset,
or make a new ad-hoc signature inherit approvals from the old app version.
The onboarding sheet addresses installation UX, **not** the identity change
across repeated CI artifacts. For reliable public updates, replace ad-hoc signing
with the same Apple-issued Developer ID Application identity on every release
and notarize the distribution; do not embed signing keys in source control.
