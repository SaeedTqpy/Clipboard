import AppKit
import XCTest
@testable import Clipboard

final class ClipboardShelfLayoutTests: XCTestCase {
    func testQuickShelfUsesWindowLevelAboveDock() {
        XCTAssertEqual(ClipboardShelfLayout.windowLevel, .popUpMenu)
        XCTAssertGreaterThan(
            ClipboardShelfLayout.windowLevel.rawValue,
            NSWindow.Level.statusBar.rawValue
        )
    }

    func testShelfTouchesPhysicalBottomWithoutDockHeightInflation() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let dockVisible = CGRect(x: 0, y: 80, width: 1440, height: 782)
        let dockHidden = CGRect(x: 0, y: 0, width: 1440, height: 862)
        let withDock = ClipboardShelfLayout.frame(in: display, visibleFrame: dockVisible)
        let withoutDock = ClipboardShelfLayout.frame(in: display, visibleFrame: dockHidden)
        XCTAssertEqual(withDock.minY, display.minY)
        XCTAssertEqual(withDock.minX, display.minX)
        XCTAssertEqual(withDock.width, display.width)
        XCTAssertEqual(withDock.height, ClipboardShelfDensity.comfortable.preferredShelfHeight)
        XCTAssertEqual(withDock, withoutDock)
        XCTAssertLessThanOrEqual(withDock.maxY, display.maxY)
    }

    func testNegativeCoordinatesAndHiddenFrameOnSecondaryDisplay() {
        let screen = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let visible = CGRect(x: -1920, y: -146, width: 1920, height: 980)
        let frame = ClipboardShelfLayout.frame(in: screen, visibleFrame: visible)
        XCTAssertEqual(frame.minX, -1920)
        XCTAssertEqual(frame.minY, -200)
        XCTAssertEqual(frame.width, 1920)
        XCTAssertEqual(frame.height, ClipboardShelfDensity.comfortable.preferredShelfHeight)
        let hidden = ClipboardShelfLayout.hiddenFrame(for: frame, displayFrame: screen)
        XCTAssertLessThan(hidden.maxY, screen.minY)
        XCTAssertEqual(hidden.width, frame.width)
        XCTAssertEqual(hidden.minX, screen.minX)
    }

    func testLeftAndRightDockNeverAffectShelfHeight() {
        let screen = CGRect(x: 0, y: 0, width: 1680, height: 1050)
        let dockLeft = CGRect(x: 85, y: 0, width: 1595, height: 1010)
        let dockRight = CGRect(x: 0, y: 0, width: 1595, height: 1010)
        let left = ClipboardShelfLayout.frame(in: screen, visibleFrame: dockLeft)
        let right = ClipboardShelfLayout.frame(in: screen, visibleFrame: dockRight)
        XCTAssertEqual(left, right)
        XCTAssertEqual(left.minX, screen.minX)
        XCTAssertEqual(left.minY, screen.minY)
    }

    func testComfortableShelfHasLargerCardsAndHeightThanCompact() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let safe = CGRect(x: 0, y: 72, width: 1920, height: 968)
        let comfortable = ClipboardShelfLayout.frame(
            in: screen, visibleFrame: safe, density: .comfortable
        )
        let compact = ClipboardShelfLayout.frame(
            in: screen, visibleFrame: safe, density: .compact
        )
        XCTAssertGreaterThan(comfortable.height, compact.height)
        XCTAssertEqual(comfortable.height, ClipboardShelfDensity.comfortable.preferredShelfHeight)
        XCTAssertEqual(compact.height, ClipboardShelfDensity.compact.preferredShelfHeight)
        XCTAssertGreaterThan(ClipboardShelfDensity.comfortable.cardWidth, 300)
        XCTAssertGreaterThan(ClipboardShelfDensity.comfortable.cardHeight, 275)
    }

    func testCompactDisplayForcesCompactDensity() {
        XCTAssertEqual(ClipboardShelfDensity.effective(
            preferred: .comfortable, screenHeight: 600
        ), .compact)
        XCTAssertEqual(ClipboardShelfDensity.effective(
            preferred: .comfortable, screenHeight: 900
        ), .comfortable)
    }

    func testSmallDisplayReservesMenuBarWithoutAddingDockSpace() {
        let screen = CGRect(x: 0, y: 0, width: 650, height: 500)
        let withDock = CGRect(x: 0, y: 45, width: 650, height: 433)
        let withoutDock = CGRect(x: 0, y: 0, width: 650, height: 478)
        let a = ClipboardShelfLayout.frame(in: screen, visibleFrame: withDock)
        let b = ClipboardShelfLayout.frame(in: screen, visibleFrame: withoutDock)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.minY, 0)
        XCTAssertLessThanOrEqual(a.maxY, screen.maxY - 44)
        XCTAssertGreaterThanOrEqual(a.height, 260)
    }

    func testLargeBottomDockDoesNotExpandShelf() {
        let full = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let safe = CGRect(x: 0, y: 96, width: 1512, height: 845)
        let frame = ClipboardShelfLayout.frame(
            in: full, visibleFrame: safe, density: .comfortable
        )
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 1512)
        XCTAssertEqual(frame.height, ClipboardShelfDensity.comfortable.preferredShelfHeight)
    }
}
