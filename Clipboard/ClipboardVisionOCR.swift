import Foundation
import ImageIO
import Vision

/// All recognition happens on the local Mac. This module has no network dependency.
enum ClipboardVisionOCR {
    static func recognize(_ pngData: Data) -> String? {
        guard !pngData.isEmpty, pngData.count <= 12 * 1024 * 1024 else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(data: pngData, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        return text.isEmpty ? nil : String(text.prefix(25_000))
    }
}
