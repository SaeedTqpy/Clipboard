import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Normalizes images on a utility task and rejects decompression bombs.
enum ClipboardImageNormalizer {
    static func pngData(from input: Data, sourceType: String) -> Data? {
        guard !input.isEmpty, input.count <= 24 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(input as CFData, nil),
              CGImageSourceGetCount(source) >= 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else { return nil }

        let w = width.int64Value
        let h = height.int64Value
        guard w > 0, h > 0, w <= 16_384, h <= 16_384,
              w <= 40_000_000 / h else { return nil }

        if sourceType == "public.png", input.count <= 12 * 1024 * 1024 {
            return input
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination),
              output.length <= 12 * 1024 * 1024 else { return nil }
        return output as Data
    }
}
