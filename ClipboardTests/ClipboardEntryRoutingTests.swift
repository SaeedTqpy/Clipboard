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

    func testQuickShelfNeverShowsBottomStatus() {
        XCTAssertFalse(ClipboardPanelPresentation.shelf.displaysBottomStatus)
        XCTAssertTrue(ClipboardPanelPresentation.management.displaysBottomStatus)
    }

    func testPermissionOnboardingOnlyOnFirstLaunchWhenNeeded() {
        XCTAssertTrue(ClipboardQuickPasteSetupPolicy.shouldPresentOnFirstLaunch(
            hasOpenedBefore: false, canPostEvents: false
        ))
        XCTAssertFalse(ClipboardQuickPasteSetupPolicy.shouldPresentOnFirstLaunch(
            hasOpenedBefore: false, canPostEvents: true
        ))
        XCTAssertFalse(ClipboardQuickPasteSetupPolicy.shouldPresentOnFirstLaunch(
            hasOpenedBefore: true, canPostEvents: false
        ))
    }
}
