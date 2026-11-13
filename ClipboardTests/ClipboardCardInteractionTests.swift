import XCTest
@testable import Clipboard

final class ClipboardCardInteractionTests: XCTestCase {
    func testQuickShelfCardClickPastes() {
        XCTAssertEqual(
            ClipboardPanelPresentation.shelf.cardTapBehavior,
            .pasteToPreviousApp
        )
    }

    func testManagementCardClickOnlySelects() {
        XCTAssertEqual(
            ClipboardPanelPresentation.management.cardTapBehavior,
            .selectForManagement
        )
    }
}
