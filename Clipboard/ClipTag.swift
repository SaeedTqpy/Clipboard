import Foundation

/// Human-facing tags live only inside AES-GCM sealed clip records.
/// No plaintext tag catalog or search index is created on disk.
enum ClipTagColor: String, CaseIterable, Codable, Identifiable {
    case green, turquoise, blue, violet, pink, coral, amber, gray
    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct ClipTag: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var color: ClipTagColor

    init(id: String = UUID().uuidString, name: String, color: ClipTagColor) {
        self.id = id
        self.name = name
        self.color = color
    }

    var isValid: Bool {
        UUID(uuidString: id) != nil &&
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            name.count <= 28 &&
            name.utf8.count <= 112
    }
}
