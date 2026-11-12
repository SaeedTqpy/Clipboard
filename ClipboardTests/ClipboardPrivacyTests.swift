import XCTest
@testable import Clipboard

final class ClipboardPrivacyTests: XCTestCase {
    func testSensitivePasteboardAnnotationsAreBlocked() {
        for type in ClipboardPrivacy.excludedTypes {
            XCTAssertTrue(ClipboardPrivacy.shouldIgnore(
                bundleID: "com.example.Editor",
                typeNames: ["public.utf8-plain-text", type],
                customBundleIDs: []
            ))
        }
    }

    func testKnownPasswordManagersAreBlocked() {
        XCTAssertTrue(ClipboardPrivacy.shouldIgnore(
            bundleID: "com.1password.1password",
            typeNames: [],
            customBundleIDs: []
        ))
        XCTAssertTrue(ClipboardPrivacy.shouldIgnore(
            bundleID: "com.bitwarden.desktop",
            typeNames: [],
            customBundleIDs: []
        ))
    }

    func testCustomBundleIdentifierExclusions() {
        let ids = ClipboardPrivacy.normalizedBundleIDs(from:
            " COM.EXAMPLE.BANK\ncom.example.Editor\ncom.example.editor\ninvalid name"
        )
        XCTAssertEqual(ids, ["com.example.bank", "com.example.editor"])
        XCTAssertTrue(ClipboardPrivacy.shouldIgnore(
            bundleID: "com.example.Bank", typeNames: [], customBundleIDs: ids
        ))
        XCTAssertFalse(ClipboardPrivacy.shouldIgnore(
            bundleID: "com.example.Mail", typeNames: [], customBundleIDs: ids
        ))
    }

    func testDefaultPreferencesWithoutUserConfiguration() {
        XCTAssertEqual(ClipboardPrivacy.normalizedBundleIDs(from: ""), [])
    }
}
