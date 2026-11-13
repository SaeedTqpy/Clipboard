import XCTest
@testable import Clipboard

final class ClipboardEntryRoutingTests: XCTestCase {
    func testHotkeyOnlyRoutesToBottomShelf() {
        XCTAssertEqual(
            ClipboardEntrySource.keyboardShortcut.presentation,
            .shelf
        )
    }

    func testMenuBarClickOnlyRoutesToManagement() {
        XCTAssertEqual(
            ClipboardEntrySource.menuBarClick.presentation,
            .management
        )
    }
}
