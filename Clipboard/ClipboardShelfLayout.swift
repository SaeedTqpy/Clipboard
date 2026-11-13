import AppKit

/// Full-width shelf physically flush with the screen edge.
/// The visible screen rectangle protects controls from the Dock, but does not
/// determine the shelf's bottom position.
enum ClipboardShelfLayout {
    static func frame(in screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let safeBottom = bottomContentInset(
            screenFrame: screenFrame, visibleFrame: visibleFrame
        )
        let height = max(
            260,
            min(screenFrame.height - 60, 375 + safeBottom)
        )
        return CGRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: height
        )
    }

    /// Amount of UI padding inside the shelf to avoid the bottom Dock.
    static func bottomContentInset(screenFrame: CGRect, visibleFrame: CGRect) -> CGFloat {
        max(0, min(160, visibleFrame.minY - screenFrame.minY))
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
