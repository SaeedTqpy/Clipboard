import AppKit
import XCTest
@testable import Clipboard

final class ClipboardShelfLayoutTests: XCTestCase {
    func testBottomShelfUsesNearlyFullAvailableWidth() {
        let visible = CGRect(x: 0, y: 77, width: 1440, height: 790)
        let frame = ClipboardShelfLayout.frame(in: visible)
        XCTAssertEqual(frame.width, 1406)
        XCTAssertEqual(frame.minX, 17)
        XCTAssertEqual(frame.minY, 89)
        XCTAssertLessThan(frame.height, visible.height / 2)
        XCTAssertLessThanOrEqual(frame.maxY, visible.maxY)
    }

    func testSecondaryDisplayAndDockOffset() {
        let display = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: -1920, y: 52, width: 1920, height: 1000)
        let frame = ClipboardShelfLayout.frame(in: visible)
        XCTAssertEqual(frame.minX, -1903)
        XCTAssertEqual(frame.minY, 64)
        let hidden = ClipboardShelfLayout.hiddenFrame(for: frame, displayFrame: display)
        XCTAssertLessThan(hidden.maxY, display.minY)
        XCTAssertEqual(hidden.width, frame.width)
    }

    func testSmallScreenStaysWithinVisibleHeight() {
        let visible = CGRect(x: 0, y: 0, width: 650, height: 500)
        let frame = ClipboardShelfLayout.frame(in: visible)
        XCTAssertGreaterThan(frame.height, 0)
        XCTAssertLessThanOrEqual(frame.maxY, visible.maxY)
    }
}
