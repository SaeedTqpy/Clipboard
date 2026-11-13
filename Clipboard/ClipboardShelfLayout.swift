import AppKit

/// A bottom-attached shelf rather than a free-floating dialog.
/// Geometry uses the chosen display's visibleFrame so it stays above the Dock.
enum ClipboardShelfLayout {
    static func frame(in available: CGRect) -> CGRect {
        let horizontalInset: CGFloat = available.width < 650 ? 9 : 17
        let bottomInset: CGFloat = available.height < 600 ? 6 : 12
        let height = min(380, min(available.height - bottomInset - 6,
                                  max(290, available.height * 0.43)))
        return CGRect(
            x: available.minX + horizontalInset,
            y: available.minY + bottomInset,
            width: max(300, available.width - 2 * horizontalInset),
            height: max(230, height)
        )
    }

    /// Initial frame is below the physical screen—not merely behind the Dock.
    static func hiddenFrame(for target: CGRect, displayFrame: CGRect) -> CGRect {
        CGRect(
            x: target.minX,
            y: displayFrame.minY - target.height - 28,
            width: target.width,
            height: target.height
        )
    }
}
