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
            ), .none
        )
        XCTAssertEqual(
            ClipboardPastePermissionPolicy.missing(
                accessibility: false, postEvent: false
            ), .both
        )
    }

    func testAccessibilityDenialCannotBlockAuthorizedPostEvent() {
        // The app only posts keyboard events; it does not require the full
        // Accessibility client authorization for this operation.
        XCTAssertEqual(
            ClipboardPastePermissionPolicy.missing(
                accessibility: false, postEvent: true
            ), .none
        )
    }

    func testDiagnosticDistinguishesPostEventFromAccessibility() {
        XCTAssertTrue(
            ClipboardPastePermissionPolicy.diagnostics(.postEvent).hasPrefix("E3P")
        )
        XCTAssertTrue(
            ClipboardPastePermissionPolicy.diagnostics(.both).hasPrefix("E3B")
        )
    }
}
