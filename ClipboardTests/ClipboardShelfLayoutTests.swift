import AppKit
import XCTest
@testable import Clipboard

final class ClipboardShelfLayoutTests: XCTestCase {
    func testShelfTouchesEntirePhysicalScreenBottom() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let safe = CGRect(x: 0, y: 80, width: 1440, height: 782)
        let frame = ClipboardShelfLayout.frame(in: display, visibleFrame: safe)
        XCTAssertEqual(frame.minY, display.minY)
        XCTAssertEqual(frame.minX, display.minX)
        XCTAssertEqual(frame.width, display.width)
        XCTAssertEqual(ClipboardShelfLayout.bottomContentInset(
            screenFrame: display, visibleFrame: safe
        ), 80)
        XCTAssertGreaterThanOrEqual(frame.height, 498 + 80)
        XCTAssertLessThanOrEqual(frame.maxY, display.maxY)
    }

    func testNegativeCoordinatesForSecondaryDisplay() {
        let screen = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let visible = CGRect(x: -1920, y: -146, width: 1920, height: 980)
        let frame = ClipboardShelfLayout.frame(in: screen, visibleFrame: visible)
        XCTAssertEqual(frame.minX, -1920)
        XCTAssertEqual(frame.minY, -200)
        XCTAssertEqual(frame.width, 1920)
        XCTAssertEqual(ClipboardShelfLayout.bottomContentInset(
            screenFrame: screen, visibleFrame: visible
        ), 54)
        let hidden = ClipboardShelfLayout.hiddenFrame(for: frame, displayFrame: screen)
        XCTAssertLessThan(hidden.maxY, screen.minY)
        XCTAssertEqual(hidden.width, frame.width)
        XCTAssertEqual(hidden.minX, screen.minX)
    }

    func testDockOnLeftDoesNotCreateFalseBottomGap() {
        let screen = CGRect(x: 0, y: 0, width: 1680, height: 1050)
        let safe = CGRect(x: 85, y: 0, width: 1595, height: 1010)
        let frame = ClipboardShelfLayout.frame(in: screen, visibleFrame: safe)
        XCTAssertEqual(frame.minX, 0)
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 1680)
        XCTAssertEqual(ClipboardShelfLayout.bottomContentInset(
            screenFrame: screen, visibleFrame: safe
        ), 0)
    }

    func testComfortableShelfHasSpaceForLargerCards() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let safe = CGRect(x: 0, y: 72, width: 1920, height: 968)
        let comfortable = ClipboardShelfLayout.frame(
            in: screen, visibleFrame: safe, density: .comfortable
        )
        let compact = ClipboardShelfLayout.frame(
            in: screen, visibleFrame: safe, density: .compact
        )
        XCTAssertGreaterThan(comfortable.height, compact.height)
        XCTAssertEqual(comfortable.minY, screen.minY)
        XCTAssertEqual(compact.minY, screen.minY)
        XCTAssertGreaterThan(ClipboardShelfDensity.comfortable.cardWidth, 300)
        XCTAssertGreaterThan(ClipboardShelfDensity.comfortable.cardHeight, 275)
    }

    func testCompactDisplayForcesCompactCards() {
        XCTAssertEqual(ClipboardShelfDensity.effective(
            preferred: .comfortable, screenHeight: 600
        ), .compact)
        XCTAssertEqual(ClipboardShelfDensity.effective(
            preferred: .comfortable, screenHeight: 900
        ), .comfortable)
    }

    func testCompactDisplayCannotExceedScreenBounds() {
        let screen = CGRect(x: 0, y: 0, width: 650, height: 500)
        let safe = CGRect(x: 0, y: 45, width: 650, height: 433)
        let frame = ClipboardShelfLayout.frame(in: screen, visibleFrame: safe)
        XCTAssertEqual(frame.minY, 0)
        XCTAssertLessThanOrEqual(frame.maxY, screen.maxY)
        XCTAssertGreaterThanOrEqual(frame.height, 260)
    }
    func testLargeDockIsCompensatedInsideShelfNotAsOuterGap() {
        let full = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let safe = CGRect(x: 0, y: 96, width: 1512, height: 845)
        let frame = ClipboardShelfLayout.frame(
            in: full, visibleFrame: safe, density: .comfortable
        )
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 1512)
        XCTAssertEqual(ClipboardShelfLayout.bottomContentInset(
            screenFrame: full, visibleFrame: safe
        ), 96)
        XCTAssertEqual(
            frame.height,
            ClipboardShelfDensity.comfortable.preferredShelfHeight + 96
        )
    }

    func testDockOnRightHasNoBottomInset() {
        let full = CGRect(x: 0, y: 0, width: 1600, height: 900)
        let safe = CGRect(x: 0, y: 0, width: 1520, height: 865)
        XCTAssertEqual(ClipboardShelfLayout.bottomContentInset(
            screenFrame: full, visibleFrame: safe
        ), 0)
    }

}
