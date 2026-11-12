import Foundation
import CryptoKit

enum ClipKind: String, CaseIterable {
    case text
    case link
    case image
    case file

    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    var title: String { rawValue.capitalized }
}

struct ClipItem: Identifiable, Equatable {
    let id: String
    let kind: ClipKind
    let preview: String
    let body: String?
    let assetFilename: String?
    let filePath: String?
    let sourceApp: String
    let createdAt: Date
    let pinned: Bool
    let fingerprint: String
}

struct ClipPayload {
    let kind: ClipKind
    let preview: String
    let body: String?
    let imagePNG: Data?
    let filePath: String?
    let fingerprint: String

    init(kind: ClipKind, preview: String, body: String? = nil, imagePNG: Data? = nil, filePath: String? = nil) {
        self.kind = kind
        self.preview = preview
        self.body = body
        self.imagePNG = imagePNG
        self.filePath = filePath
        var data = Data(kind.rawValue.utf8)
        if let body { data.append(contentsOf: body.utf8) }
        if let filePath { data.append(contentsOf: filePath.utf8) }
        if let imagePNG { data.append(imagePNG) }
        self.fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum ClipText {
    static func preview(_ text: String, limit: Int = 180) -> String {
        let compact = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(compact.prefix(limit))
    }

    static func kind(for text: String) -> ClipKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["https", "http"].contains(scheme), url.host != nil {
            return .link
        }
        return .text
    }
}
