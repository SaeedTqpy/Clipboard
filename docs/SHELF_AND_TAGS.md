# Clipboard — bottom shelf and colored tags

## UX goal

The shelf behaves like an extension of the Dock rather than another floating window. Paste is a behavioral reference, not a pixel copy: Clipboard retains SwiftUI/AppKit, native materials, keyboard controls and privacy features.

## Window lifecycle

- `ClipboardShelfLayout.frame(in:)` computes a near-display-wide frame from `NSScreen.visibleFrame`; the Dock and menu bar are respected.
- `hiddenFrame(for:displayFrame:)` moves the panel below the physical screen edge. `NSAnimationContext` provides a 380ms eased entrance and a 220ms exit.
- The active display follows mouse position, even with negative screen coordinates.
- With `NSWorkspace.accessibilityDisplayShouldReduceMotion` enabled, show/hide is immediate.
- Normal dismissals slide down. A Paste action closes immediately so the destination app can regain key focus before Cmd+V. This focus protection is more important than a decorative exit animation.
- Device verification is necessary: successful CI does not prove focus restoration in Notes, Finder or third-party apps.

## Card color system

Each content kind has an identifiable colored ribbon and readable label/SF Symbol. Text=blue, Link=green, Rich Text=violet, Color=amber, Image=pink, File=teal.

## User-created colored tags

- A clip accepts up to five tags.
- Palette: Green, Turquoise, Blue, Violet, Pink, Coral, Amber and Gray.
- Create from `••• → Colored Tags → New Color Tag…`. Reuse an existing tag from another card's menu.
- Click a chip in the horizontal tag rail to filter; right-click the chip to edit its name/color globally.
- Tags appear as badges on cards; additional tags remain available in the card menu.
- Tag metadata is encrypted inside every clip's AES-GCM sealed record. There is **no plaintext tag catalog or tag search index**.
- The catalog is rebuilt from existing clips. A tag without any references disappears; no orphan plaintext metadata survives.
- Duplicate-copy dedup, text editing and portable encrypted backups preserve tag associations.
- Tag IDs use UUIDs; names and counts have strict bounds, and malformed backup tags are rejected before DB modification.
- The new field is optional in the archived record for backwards compatibility with previous versions.

## Test boundaries

Deterministic tests cover shelf geometry and encrypted tag lifecycle. Animation, Accessibility, Paste and two-screen UX require [real-Mac QA](MAC_DEVICE_QA.md).

There is no network interaction, telemetry or third-party service for the tag system.
