# Clipboard

Native macOS clipboard manager built with **SwiftUI + AppKit** and a macOS GitHub Actions build pipeline. No Apple Developer membership is required for unsigned local testing.

> Work in progress: source code and unsigned CI builds are for personal testing; they are not notarized releases.

## Privacy baseline

Clipboard history is stored locally. No analytics or network sync is built in. Concealed/transient pasteboard content and known password-manager sources must not be recorded. Users can pause monitoring and clear history.

## Development

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). CI builds an unsigned `.app` and uploads a ZIP artifact.
