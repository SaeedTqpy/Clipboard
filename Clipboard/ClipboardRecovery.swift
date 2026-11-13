import Foundation

enum ClipboardRecoveryError: LocalizedError {
    case nothingToRecover

    var errorDescription: String? {
        switch self {
        case .nothingToRecover: return "No existing Clipboard storage was found."
        }
    }
}

/// Never removes damaged history: atomically moves it to a separate directory.
enum ClipboardRecovery {
    @discardableResult
    static func quarantine(baseDirectory: URL? = nil) throws -> URL {
        let root: URL
        if let baseDirectory {
            root = baseDirectory
        } else {
            guard let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first else { throw ClipboardStoreError.missingSupportDirectory }
            root = applicationSupport
        }

        let original = root.appendingPathComponent("Clipboard", isDirectory: true)
        guard FileManager.default.fileExists(atPath: original.path) else {
            throw ClipboardRecoveryError.nothingToRecover
        }
        let recoveryRoot = root.appendingPathComponent(
            "Clipboard-Recovery", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: recoveryRoot, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let destination = recoveryRoot.appendingPathComponent(
            "History-\(timestamp)-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.moveItem(at: original, to: destination)
        return destination
    }
}
