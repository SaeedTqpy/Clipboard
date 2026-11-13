import Foundation
import CryptoKit

enum ClipKind: String, CaseIterable {
    case text
    case link
    case richText
    case color
    case image
    case file

    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .richText: return "doc.richtext"
        case .color: return "paintpalette.fill"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    var title: String {
        self == .richText ? "Rich Text" : rawValue.capitalized
    }
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
    let collection: String?
    var richData: Data? = nil
    var richType: String? = nil
    var displayName: String? = nil
    var recognizedText: String? = nil
    var tags: [ClipTag] = []
}

struct ClipPayload {
    let kind: ClipKind
    let preview: String
    let body: String?
    let imagePNG: Data?
    let filePath: String?
    let richData: Data?
    let richType: String?
    let recognizedText: String?
    let fingerprint: String

    init(
        kind: ClipKind, preview: String, body: String? = nil,
        imagePNG: Data? = nil, filePath: String? = nil,
        richData: Data? = nil, richType: String? = nil,
        recognizedText: String? = nil
    ) {
        self.kind = kind
        self.preview = preview
        self.body = body
        self.imagePNG = imagePNG
        self.filePath = filePath
        self.richData = richData
        self.richType = richType
        self.recognizedText = recognizedText
        var data = Data(kind.rawValue.utf8)
        if let body { data.append(contentsOf: body.utf8) }
        if let filePath { data.append(contentsOf: filePath.utf8) }
        if let imagePNG { data.append(imagePNG) }
        if let richType { data.append(contentsOf: richType.utf8) }
        if let richData { data.append(richData) }
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
        if ClipColor.hexValue(trimmed) != nil {
            return .color
        }
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["https", "http"].contains(scheme), url.host != nil {
            return .link
        }
        return .text
    }
}
