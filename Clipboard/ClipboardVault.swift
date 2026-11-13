import CryptoKit
import Foundation
import Security

enum ClipboardVaultError: LocalizedError {
    case keychain(OSStatus)
    case missingKey
    case invalidKey
    case invalidCiphertext

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return "Clipboard cannot access its Keychain encryption key (OSStatus \(status)). Unlock your Mac and retry."
        case .missingKey:
            return "The encryption key for existing Clipboard history is missing. The encrypted data has not been deleted."
        case .invalidKey:
            return "The Clipboard encryption key is invalid."
        case .invalidCiphertext:
            return "Clipboard content could not be decrypted. No data has been overwritten."
        }
    }
}

/// The Keychain-held 256-bit master key never leaves this device.
/// Test instances use an explicitly injected key instead of touching the user's Keychain.
struct ClipboardVault: Sendable {
    private let master: SymmetricKey
    private static let service = "dev.clipboard.app.local-history.v1"
    private static let account = "aes-gcm-master-key"

    init(testKey: Data) throws {
        guard testKey.count == 32 else { throw ClipboardVaultError.invalidKey }
        master = SymmetricKey(data: testKey)
    }

    static func open(allowNewKey: Bool) throws -> ClipboardVault {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data else { throw ClipboardVaultError.invalidKey }
            return try ClipboardVault(testKey: data)
        }
        guard status == errSecItemNotFound else { throw ClipboardVaultError.keychain(status) }
        guard allowNewKey else { throw ClipboardVaultError.missingKey }

        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else {
            throw ClipboardVaultError.keychain(randomStatus)
        }
        let keyData = Data(bytes)
        let insertQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let inserted = SecItemAdd(insertQuery as CFDictionary, nil)
        if inserted == errSecDuplicateItem {
            return try open(allowNewKey: false)
        }
        guard inserted == errSecSuccess else { throw ClipboardVaultError.keychain(inserted) }
        return try ClipboardVault(testKey: keyData)
    }

    func seal(_ data: Data, context: String) throws -> Data {
        let sealed = try AES.GCM.seal(
            data, using: master, authenticating: Data(context.utf8)
        )
        guard let combined = sealed.combined else {
            throw ClipboardVaultError.invalidCiphertext
        }
        return combined
    }

    func open(_ data: Data, context: String) throws -> Data {
        do {
            let sealed = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(
                sealed, using: master, authenticating: Data(context.utf8)
            )
        } catch {
            throw ClipboardVaultError.invalidCiphertext
        }
    }

    /// A keyed identifier prevents offline dictionary attacks on ordinary SHA-256 fingerprints.
    func fingerprint(for contentFingerprint: String) -> String {
        let code = HMAC<SHA256>.authenticationCode(
            for: Data(contentFingerprint.utf8), using: master
        )
        return code.map { String(format: "%02x", $0) }.joined()
    }
}
