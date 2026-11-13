import XCTest
@testable import Clipboard

final class ClipboardPastePermissionPolicyTests: XCTestCase {
    func testAxGrantedPostEventDeniedRequiresPostEventOnly() {
        XCTAssertEqual(
            ClipboardPastePermissionPolicy.missing(
                accessibility: true, postEvent: false
            ), .postEvent
        )
        let message = ClipboardPastePermissionPolicy.message(.postEvent)
        XCTAssertTrue(message.contains("tccutil reset PostEvent"))
        XCTAssertTrue(message.contains("Accessibility is ON"))
        XCTAssertFalse(message.contains("reset Accessibility"))
    }

    func testTwoIndependentPermissions() {
        XCTAssertEqual(
            ClipboardPastePermissionPolicy.missing(
                accessibility: true, postEvent: true
            ), .none
        )
        XCTAssertEqual(
            ClipboardPastePermissionPolicy.missing(
                accessibility: false, postEvent: true
            ), .accessibility
        )
        XCTAssertEqual(
            ClipboardPastePermissionPolicy.missing(
                accessibility: false, postEvent: false
            ), .both
        )
    }

    func testDiagnosticDistinguishesPostEventFromAccessibility() {
        XCTAssertTrue(
            ClipboardPastePermissionPolicy.diagnostics(.postEvent).hasPrefix("E3P")
        )
        XCTAssertTrue(
            ClipboardPastePermissionPolicy.diagnostics(.accessibility).hasPrefix("E3A")
        )
    }
}
