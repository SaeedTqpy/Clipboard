import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Small, immutable descriptor that can be safely used by detached work.
struct ClipboardThumbnailSource: Sendable {
    let url: URL
    let fingerprint: String
    let vault: ClipboardVault

    var cacheKey: String { fingerprint }

    func thumbnailPNG() throws -> Data {
        let encrypted = try Data(contentsOf: url, options: .mappedIfSafe)
        let original = try vault.open(encrypted, context: "asset:\(fingerprint)")
        guard let source = CGImageSourceCreateWithData(original as CFData, nil) else { return original }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 480,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return original }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        ) else { return original }
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else { return original }
        return output as Data
    }
}

@MainActor
private final class ClipboardThumbnailCache {
    static let shared = ClipboardThumbnailCache()
    let images = NSCache<NSString, NSImage>()

    private init() {
        images.countLimit = 160
        images.totalCostLimit = 96 * 1024 * 1024
    }
}

struct ClipboardThumbnailView: View {
    let source: ClipboardThumbnailSource?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Copied image preview")
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Image preview unavailable")
            }
        }
        .task(id: source?.cacheKey) {
            image = nil
            guard let source else { return }
            if let cached = ClipboardThumbnailCache.shared.images.object(
                forKey: source.cacheKey as NSString
            ) {
                image = cached
                return
            }
            do {
                let bytes = try await Task.detached(priority: .utility) {
                    try source.thumbnailPNG()
                }.value
                guard !Task.isCancelled, let next = NSImage(data: bytes) else { return }
                ClipboardThumbnailCache.shared.images.setObject(
                    next, forKey: source.cacheKey as NSString,
                    cost: min(bytes.count * 3, 4 * 1024 * 1024)
                )
                image = next
            } catch {
                // Corrupted or missing assets display the neutral placeholder.
            }
        }
    }
}
