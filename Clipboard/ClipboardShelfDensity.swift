import AppKit

/// Shared sizing contract for the Quick Shelf; the management window keeps its
/// own independent layout. Density is persisted by the SwiftUI @AppStorage key.
enum ClipboardShelfDensity: String, CaseIterable, Identifiable {
    case comfortable
    case compact

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var cardWidth: CGFloat { self == .comfortable ? 322 : 278 }
    var cardHeight: CGFloat { self == .comfortable ? 283 : 243 }
    var previewHeight: CGFloat { self == .comfortable ? 120 : 83 }
    var cardSpacing: CGFloat { self == .comfortable ? 20 : 14 }
    var preferredShelfHeight: CGFloat { self == .comfortable ? 500 : 460 }

    /// Respect a user's preferred density except on a small display, where
    /// Comfortable cards would leave too little room for search and controls.
    static func effective(
        preferred: ClipboardShelfDensity, screenHeight: CGFloat
    ) -> ClipboardShelfDensity {
        screenHeight < 680 ? .compact : preferred
    }
}
