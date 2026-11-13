import Foundation

/// Lightweight, side-effect-free CSS hexadecimal color recognition.
enum ClipColor {
    struct RGBA: Equatable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    static func hexValue(_ source: String) -> RGBA? {
        let input = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.first == "#" else { return nil }
        let hex = String(input.dropFirst())
        guard [3, 4, 6, 8].contains(hex.count),
              hex.utf8.allSatisfy({ byte in
                  (48...57).contains(byte) ||
                  (65...70).contains(byte) ||
                  (97...102).contains(byte)
              }) else { return nil }

        let bytes: [Int]
        if hex.count <= 4 {
            bytes = hex.map { Int(String(repeating: String($0), count: 2), radix: 16) ?? 0 }
        } else {
            let characters = Array(hex)
            bytes = stride(from: 0, to: characters.count, by: 2).map { offset in
                Int(String(characters[offset...offset+1]), radix: 16) ?? 0
            }
        }
        guard bytes.count >= 3 else { return nil }
        return RGBA(
            red: Double(bytes[0]) / 255,
            green: Double(bytes[1]) / 255,
            blue: Double(bytes[2]) / 255,
            alpha: bytes.count == 4 ? Double(bytes[3]) / 255 : 1
        )
    }
}
