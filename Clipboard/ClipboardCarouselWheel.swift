import AppKit
import SwiftUI

/// One horizontal scroll surface shared by the Quick Shelf's entire carousel:
/// cards, their spacing, and the empty viewport. Does not monitor global input
/// or generate synthetic events and never changes the frontmost application.
enum ClipboardCarouselWheelPolicy {
    static let pointsPerWheelLine: CGFloat = 34

    /// NSEvent's sign is opposite the logical document offset. Preserve
    /// Trackpad pixel precision and momentum; do not sum diagonal axes.
    static func displacement(deltaX: CGFloat, deltaY: CGFloat, precise: Bool) -> CGFloat {
        guard deltaX.isFinite, deltaY.isFinite else { return 0 }
        let major = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
        return -major * (precise ? 1 : pointsPerWheelLine)
    }

    static func offset(
        from current: CGFloat,
        by displacement: CGFloat,
        contentWidth: CGFloat,
        viewportWidth: CGFloat
    ) -> CGFloat {
        guard current.isFinite, displacement.isFinite,
              contentWidth.isFinite, viewportWidth.isFinite else { return 0 }
        let maximum = max(0, contentWidth - max(0, viewportWidth))
        return min(max(0, current + displacement), maximum)
    }
}

/// AppKit event routing is scoped to this NSPanel and only its carousel rect.
/// NSView coordinate conversion keeps multi-monitor, animations and resize
/// correct. Unlike a transparent overlay, the probe never takes mouse clicks.
@MainActor
final class ClipboardCarouselWheelRouter {
    weak var viewport: NSView?
    var onScroll: ((CGFloat) -> Void)?

    func route(_ event: NSEvent, in panel: NSPanel) -> Bool {
        guard event.type == .scrollWheel,
              panel.attachedSheet == nil,
              let viewport, viewport.window === panel else { return false }
        let location = viewport.convert(event.locationInWindow, from: nil)
        guard viewport.bounds.contains(location) else { return false }

        let displacement = ClipboardCarouselWheelPolicy.displacement(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            precise: event.hasPreciseScrollingDeltas
        )
        if displacement != 0 { onScroll?(displacement) }
        // Consume *all* wheel phases, including zero-delta end/momentum and
        // the boundary where there are no more clips to reveal. Never scroll
        // the app underneath the floating nonactivating Shelf.
        return true
    }
}

private final class ClipboardWheelProbeView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// SwiftUI's ScrollView keeps its native card and gesture hit testing.
/// This passive native probe tracks the *viewport* (not each LazyHStack item),
/// so blank gaps route to the same horizontal content as the cards.
struct ClipboardCarouselWheelProbe: NSViewRepresentable {
    let router: ClipboardCarouselWheelRouter?

    func makeNSView(context: Context) -> NSView {
        let view = ClipboardWheelProbeView(frame: .zero)
        router?.viewport = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        router?.viewport = nsView
    }
}

/// Pure geometry snapshot from SwiftUI's real scrolling offset. Keep an
/// in-flight requested offset so bursts of wheel events do not lose deltas.
struct ClipboardCarouselScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentWidth: CGFloat = 0
    var viewportWidth: CGFloat = 0
}
