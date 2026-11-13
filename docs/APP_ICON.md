# Clipboard app icon

Clipboard uses a blue-violet glass clipboard mark with three layered memory cards.
The initial image-generation concept was redrawn as a deterministic, resolution-independent AppKit graphic for the actual application.
**The build-time vector redraw is not pixel-identical to the image-generation master.**

## Build integration

- XcodeGen runs `scripts/render-app-icon.swift` as a pre-build script.
- AppKit renders 10 iconset PNG variants, from 16 to 1024 px.
- Built-in `iconutil` assembles `Clipboard.icns` in app Contents/Resources.
- Info.plist uses `CFBundleIconFile=Clipboard.icns`.
- Xcode declares script input and ICNS output for incremental dependency analysis.
- No Apple Developer account, network, CocoaPods or Homebrew is required.

## Verification

Check both artifacts in the built bundle:

```bash
test -s Clipboard.app/Contents/Resources/Clipboard.icns
plutil -extract CFBundleIconFile raw Clipboard.app/Contents/Info.plist
```

The icon appears in Finder, Get Info and the Dock when the app is pinned.
Clipboard runs as an LSUIElement menu bar utility, so it does not normally show a Dock tile.
The menu bar button remains monochrome by design, following macOS menu bar conventions.

## Bundle metadata

XcodeGen writes `.generated/Clipboard-Info.plist` with a real `CFBundleIconFile` key and sets `GENERATE_INFOPLIST_FILE=NO` for the application target. The earlier `INFOPLIST_KEY_CFBundleIconFile` build setting was insufficient with the generated plist in the macOS runner; this explicit metadata prevents silently shipping a generic app icon.
