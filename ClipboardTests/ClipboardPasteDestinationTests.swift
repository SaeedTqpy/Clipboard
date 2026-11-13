import XCTest
@testable import Clipboard

final class ClipboardPasteDestinationTests: XCTestCase {
    func testRemembersLastExternalAppWhenShelfOwnsFocus() {
        XCTAssertEqual(ClipboardPasteDestination.choose(
            frontmostPID: 500, fallbackPID: 321, ownPID: 500
        ), 321)
    }

    func testUsesRealForegroundAppOverStaleFallback() {
        XCTAssertEqual(ClipboardPasteDestination.choose(
            frontmostPID: 45, fallbackPID: 321, ownPID: 500
        ), 45)
    }

    func testNeverTargetsClipboardOrNonexistentPID() {
        XCTAssertNil(ClipboardPasteDestination.choose(
            frontmostPID: 500, fallbackPID: nil, ownPID: 500
        ))
        XCTAssertNil(ClipboardPasteDestination.choose(
            frontmostPID: nil, fallbackPID: 0, ownPID: 500
        ))
        XCTAssertFalse(ClipboardPasteDestination.mayPost(
            targetPID: 500, frontmostPID: 500, ownPID: 500
        ))
    }

    func testOnlyPostsWhenRememberedTargetIsForeground() {
        XCTAssertTrue(ClipboardPasteDestination.mayPost(
            targetPID: 321, frontmostPID: 321, ownPID: 500
        ))
        XCTAssertFalse(ClipboardPasteDestination.mayPost(
            targetPID: 321, frontmostPID: 777, ownPID: 500
        ))
        XCTAssertFalse(ClipboardPasteDestination.mayPost(
            targetPID: 321, frontmostPID: nil, ownPID: 500
        ))
    }
}
