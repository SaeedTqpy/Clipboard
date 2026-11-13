import CommonCrypto
import CryptoKit
import Foundation
import Security

enum ClipboardBackupError: LocalizedError {
    case weakPassword
    case invalidFormat
    case incorrectPasswordOrCorrupt
    case tooLarge
    case randomFailure

    var errorDescription: String? {
        switch self {
        case .weakPassword: return "Use a backup password of at least 12 characters."
        case .invalidFormat: return "This is not a compatible Clipboard backup."
        case .incorrectPasswordOrCorrupt: return "Incorrect backup password or damaged backup file."
        case .tooLarge: return "Backup exceeds the 100 MiB in-memory safety limit."
        case .randomFailure: return "Secure random generation failed."
        }
    }
}

private struct ClipboardBackupEnvelope: Codable {
    let magic: String
    let version: Int
    let salt: Data
    let rounds: Int
    let encryptedPayload: Data
}

/// Password-based encryption for portable exports; no history leaves the Mac unless user exports it.
enum ClipboardBackupCrypto {
    private static let rounds = 310_000
    private static let maxBytes = 100 * 1024 * 1024
    private static let context = Data("Clipboard.PasswordBackup.v1".utf8)

    static func seal(_ payload: Data, password: String) throws -> Data {
        guard password.count >= 12 else { throw ClipboardBackupError.weakPassword }
        guard payload.count <= maxBytes else { throw ClipboardBackupError.tooLarge }
        var saltBytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes) == errSecSuccess
        else { throw ClipboardBackupError.randomFailure }
        let salt = Data(saltBytes)
        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        let sealed = try AES.GCM.seal(payload, using: key, authenticating: context)
        guard let combined = sealed.combined else { throw ClipboardBackupError.invalidFormat }
        let envelope = ClipboardBackupEnvelope(
            magic: "CLIPBOARD_ENCRYPTED_BACKUP",
            version: 1,
            salt: salt,
            rounds: rounds,
            encryptedPayload: combined
        )
        return try JSONEncoder().encode(envelope)
    }

    static func open(_ file: Data, password: String) throws -> Data {
        guard file.count <= maxBytes + 16_384 else { throw ClipboardBackupError.tooLarge }
        guard let envelope = try? JSONDecoder().decode(ClipboardBackupEnvelope.self, from: file),
              envelope.magic == "CLIPBOARD_ENCRYPTED_BACKUP",
              envelope.version == 1,
              envelope.salt.count == 32,
              (100_000...1_000_000).contains(envelope.rounds)
        else { throw ClipboardBackupError.invalidFormat }
        let key = try deriveKey(password: password, salt: envelope.salt, rounds: envelope.rounds)
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.encryptedPayload)
            let plain = try AES.GCM.open(box, using: key, authenticating: context)
            guard plain.count <= maxBytes else { throw ClipboardBackupError.tooLarge }
            return plain
        } catch {
            throw ClipboardBackupError.incorrectPasswordOrCorrupt
        }
    }

    private static func deriveKey(password: String, salt: Data, rounds: Int) throws -> SymmetricKey {
        var output = [UInt8](repeating: 0, count: 32)
        let status = password.withCString { passwordPointer in
            salt.withUnsafeBytes { saltPointer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPointer,
                    password.utf8.count,
                    saltPointer.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(rounds),
                    &output,
                    output.count
                )
            }
        }
        guard status == kCCSuccess else { throw ClipboardBackupError.invalidFormat }
        return SymmetricKey(data: Data(output))
    }
}
