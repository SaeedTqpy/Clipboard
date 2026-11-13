# Clipboard — Glass Shelf Design System

## Product behavior

Two purpose-built surfaces exist, and they must remain separate.

- **Quick Shelf:** invoked by **Win/Command+Shift+V**. A single click
  on a card's preview must still copy, dismiss the shelf immediately, restore
  the previously active app, and send only one authorized Command-V.
- **Clipboard Manager:** left-click on the Menu Bar icon. A separate, normal
  resizable AppKit window. Clicking a preview here only selects the clip.
- **Clean Quick Shelf:** the bottom shortcut hints, clip count, technical paste
  diagnostics, and orange error banners are not rendered in the shelf.
  Diagnostics and detailed errors remain available in Manager and Settings →
  Paste Diagnostics. When an operation needs attention, a small warning icon
  in the top toolbar opens Settings. Paste Stack controls are retained in a
  top-toolbar menu when the stack has entries.
- The Shelf is **physically attached to the lower screen edge** and uses a
  transient `NSWindow.Level.popUpMenu` so it renders above the Dock.
  The Dock is visually **covered only while the Shelf is open**, not killed,
  hidden via system preferences, or reconfigured. Dock clearance is **not**
  added to Shelf height. The glass canvas has an adaptive opaque foundation
  to keep Dock icons from showing through the background.
  `NSScreen.visibleFrame` is used to reserve the top menu-bar safe area.
- The active screen follows the pointer. Negative coordinates on secondary
  displays, left/right/bottom Dock positions and Reduce Motion are supported.
- Normal dismissals animate down. **Actual Paste dismisses immediately** to
  avoid a delayed focus release.

## Glass, light and material

- **macOS 26+**: the shell uses native SwiftUI
  `.glassEffect(.regular.tint(...), in:...)` with a subtle cyan tint
  and a restrained directional highlight. Action buttons are combined using
  `GlassEffectContainer` to reduce redundant glass sampling.
- **macOS 15**: fallback to system
  `.ultraThinMaterial` and `.thinMaterial`. No fake Gaussian blur images.
- Light and Dark mode adapt via system material and color scheme. Contrast is
  maintained by keeping text previews on readable translucent *cards* rather
  than stacking many glass layers.
- Shelf shape has rounded **top corners only**, with no detached shadow at
  the physical screen bottom. Content layers never intercept click events.
- Apple recommends that Liquid Glass be used selectively on prominent
  floating controls, not indiscriminately over all content.

## Spacing and density contract

| Component | Comfortable | Compact |
| --- | --- | --- |
| Card width | 322 pt | 278 pt |
| Card height | 283 pt | 243 pt |
| Preview target height | 120 pt | 83 pt |
| Card gap | 20 pt | 14 pt |
| Shelf base height | 500 pt | 460 pt |

The bottom Dock size does not change the Shelf height. Height is clamped to
the physical display minus the top menu-bar safe area. Displays shorter than
680 pt force
Compact even when the user previously chose Comfortable. Displays below
660 pt omit the optional tag rail; the footer is always absent from the shelf.
This preserves room for the toolbar and clip previews.
Search width also adapts below 850 pt.

Density selection is persisted under
`clipboard.shelfDensity` and can be changed live through the
**Comfortable / Compact** menu inside the filter rail. AppKit animates
the Shelf height, unless Reduce Motion is enabled.

## Card hierarchy

1. **Type ribbon**: subtle kind-specific tint, type icon and visible
   PINNED/RECENT status. Its color is not the only type indicator.
2. **Preview**: significantly more room and typography. Link cards show host,
   images show a large constrained thumbnail and OCR indication, color clips
   show a swatch, code-like content uses a readable monospaced font.
3. **Organization**: user-colored tags or collection context.
4. **Metadata**: source application and relative age.
5. **Actions**: Copy, Paste and a separate More menu. These buttons are
   siblings of the preview button, not nested controls.

Hover raises the card a few points with a restrained shadow and slight
scaling. Reduced Motion disables that translation and scaling.
Selection has a high-contrast type-colored outline, with a visible hover
state and accessible button labels. Horizontal virtualization remains a
`LazyHStack` for large histories; no eager image thumbnail grid.

## Design acceptance and release gates

- [ ] Mac 26: verify native reflections, mouse hover, floating controls,
  screenshot in light and dark mode.
- [ ] Mac 15: confirm readability and fallback material.
- [ ] Dock bottom and Dock left/right; Shelf stays on top while visible,
  Dock icons do not show through the translucent backdrop, and no Dock height
  is added to the Shelf. Dismissing the Shelf reveals an unchanged Dock.
- [ ] Displays 650 pt, 900 pt and 1080 pt high; two screens with negative
  origins; compact mode when constrained.
- [ ] Comfortable and Compact change card dimensions **and panel height**.
- [ ] Pressing Win/Command+Shift+V opens only Shelf; Menu Bar icon opens only
  Manager. No double window.
- [ ] Clicking a card preview in Shelf pastes once and dismisses. Copy and
  More never dispatch accidental paste. Manager card click selects only.
- [ ] Accessibility and PostEvent failures remain actionable via the top
  attention indicator and Settings → Paste Diagnostics without an intrusive
  bottom banner in the shelf.
- [ ] Keyboard selection and Enter, Cmd+1…9, Escape, search focus still work.
- [ ] NSWorkspace Reduce Motion removes translations; VoiceOver controls have
  meaningful names.
- [ ] Inspect the signed Universal app from GitHub Actions. Automated build
  does **not** prove actual animation or Paste on the user's Mac.

## References

- Apple — [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- Apple — [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- Apple — [Build an AppKit app with the new design (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/310/)
- Apple — [NSScreen.visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe)


## Verified CI milestone

[GitHub Actions #43508693436](https://github.com/SaeedTqpy/Clipboard/actions/runs/43508693436) completed with **70 passing tests**, a native macOS 26 build, verified app icon, arm64/x86_64 release, and valid ad-hoc signature. The artifact inner app ZIP has the published matching SHA-256. **Automation did not measure actual Dock z-order, liquid-reflection quality or application focus on a user's Mac**; use the acceptance checklist above.
