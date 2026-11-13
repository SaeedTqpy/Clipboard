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

   `tccutil reset Accessibility dev.clipboard.app`

   This is scoped to Clipboard and does not reset all app permissions.
5. Launch **the new app** from /Applications. Under System Settings →
   Privacy & Security → Accessibility, remove the stale Clipboard entry if
   shown and add/select the new `/Applications/Clipboard.app`. Enable it.
   Approve macOS's permission request if shown.
6. Fully **Quit Clipboard and relaunch it** from /Applications (do not merely
   hide the shelf). In Settings → Paste Diagnostics press
   **Refresh TCC & Signing Status**. Confirm `Accessibility (AX): true`
   and `Event Posting: true`.
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
