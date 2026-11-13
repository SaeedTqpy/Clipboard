import Foundation
import XCTest
@testable import Clipboard

final class ClipboardVaultTests: XCTestCase {
    func testCiphertextAndContextAuthentication() throws {
        let vault = try ClipboardVault(testKey: Data(repeating: 0xAB, count: 32))
        let input = Data("secret copied text".utf8)
        let ciphertext = try vault.seal(input, context: "clip:abc")
        XCTAssertNotEqual(ciphertext, input)
        XCTAssertNil(ciphertext.range(of: Data("secret".utf8)))
        XCTAssertEqual(try vault.open(ciphertext, context: "clip:abc"), input)
        XCTAssertThrowsError(try vault.open(ciphertext, context: "clip:different"))
    }

    func testFingerprintIsKeyedAndStable() throws {
        let first = try ClipboardVault(testKey: Data(repeating: 1, count: 32))
        let second = try ClipboardVault(testKey: Data(repeating: 2, count: 32))
        XCTAssertEqual(first.fingerprint(for: "abc"), first.fingerprint(for: "abc"))
        XCTAssertNotEqual(first.fingerprint(for: "abc"), second.fingerprint(for: "abc"))
    }

    func testPortableBackupRoundTripAndWrongPassword() throws {
        let data = Data("archive".utf8)
        let encrypted = try ClipboardBackupCrypto.seal(data, password: "correct horse battery staple")
        XCTAssertFalse(encrypted.contains(Data("archive".utf8)))
        XCTAssertEqual(
            try ClipboardBackupCrypto.open(encrypted, password: "correct horse battery staple"), data
        )
        XCTAssertThrowsError(try ClipboardBackupCrypto.open(encrypted, password: "incorrect backup password"))
    }
}
