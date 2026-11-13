import AppKit

/// Bottom-attached Quick Shelf. This transient surface temporarily covers the
/// Dock rather than making the user change Dock preferences or moving controls
/// above the Dock. The menu bar / system alerts remain under macOS control.
enum ClipboardShelfLayout {
    /// A transient pop-up sits above the Dock's window level. Unlike
    /// screenSaver, it does not unnecessarily cover high-priority OS UI.
    static let windowLevel: NSWindow.Level = .popUpMenu

    static func frame(
        in screenFrame: CGRect, visibleFrame: CGRect,
        density: ClipboardShelfDensity = .comfortable
    ) -> CGRect {
        let effectiveDensity = ClipboardShelfDensity.effective(
            preferred: density, screenHeight: screenFrame.height
        )
        // Use visibleFrame only to reserve the menu-bar/top safe area.
        // The Dock at the bottom is covered, not added to the shelf height.
        let topReserved = max(44, screenFrame.maxY - visibleFrame.maxY)
        let maxAvailable = max(200, screenFrame.height - topReserved)
        let height = min(
            screenFrame.height,
            max(200, min(maxAvailable, effectiveDensity.preferredShelfHeight))
        )
        return CGRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: height
        )
    }

    /// The entire shelf begins below the physical display before sliding up.
    static func hiddenFrame(for target: CGRect, displayFrame: CGRect) -> CGRect {
        CGRect(
            x: target.minX,
            y: displayFrame.minY - target.height - 4,
            width: target.width,
            height: target.height
        )
    }
}
