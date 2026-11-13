import AppKit

/// Shared sizing contract for the Quick Shelf; the management window keeps its
/// own independent layout. Density is persisted by the SwiftUI @AppStorage key.
enum ClipboardShelfDensity: String, CaseIterable, Identifiable {
    case comfortable
    case compact

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var cardWidth: CGFloat { self == .comfortable ? 316 : 268 }
    var cardHeight: CGFloat { self == .comfortable ? 266 : 232 }
    var previewHeight: CGFloat { self == .comfortable ? 119 : 87 }
    var cardSpacing: CGFloat { self == .comfortable ? 20 : 14 }
    var preferredShelfHeight: CGFloat { self == .comfortable ? 498 : 450 }

    /// Respect a user's preferred density except on a small display, where
    /// Comfortable cards would leave too little room for search and controls.
    static func effective(
        preferred: ClipboardShelfDensity, screenHeight: CGFloat
    ) -> ClipboardShelfDensity {
        screenHeight < 680 ? .compact : preferred
    }
}
