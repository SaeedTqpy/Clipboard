import AppKit
import XCTest
@testable import Clipboard

final class ClipboardCarouselWheelTests: XCTestCase {
    func testMouseWheelDownAdvancesHorizontallyInPoints() {
        XCTAssertEqual(
            ClipboardCarouselWheelPolicy.displacement(deltaX: 0, deltaY: -2, precise: false),
            68
        )
        XCTAssertEqual(
            ClipboardCarouselWheelPolicy.displacement(deltaX: 0, deltaY: 1, precise: false),
            -34
        )
    }

    func testTrackpadPreservesFractionalPixelDeltaAndMomentum() {
        XCTAssertEqual(
            ClipboardCarouselWheelPolicy.displacement(deltaX: -4.25, deltaY: 0, precise: true),
            4.25
        )
        XCTAssertEqual(
            ClipboardCarouselWheelPolicy.displacement(deltaX: 0, deltaY: -0.75, precise: true),
            0.75
        )
        XCTAssertEqual(
            ClipboardCarouselWheelPolicy.displacement(deltaX: 0, deltaY: 0, precise: true),
            0
        )
    }

    func testUsesPredominantAxisNotSumForDiagonalGestures() {
        XCTAssertEqual(
            ClipboardCarouselWheelPolicy.displacement(deltaX: -7, deltaY: 2, precise: true),
            7
        )
        XCTAssertEqual(
            ClipboardCarouselWheelPolicy.displacement(deltaX: 1, deltaY: -9, precise: true),
            9
        )
    }

    func testOffsetsClampAtBothEdgesWithoutScrollChaining() {
        XCTAssertEqual(ClipboardCarouselWheelPolicy.offset(
            from: 995, by: 100, contentWidth: 1500, viewportWidth: 500
        ), 1000)
        XCTAssertEqual(ClipboardCarouselWheelPolicy.offset(
            from: 8, by: -30, contentWidth: 1500, viewportWidth: 500
        ), 0)
        XCTAssertEqual(ClipboardCarouselWheelPolicy.offset(
            from: 10, by: 30, contentWidth: 300, viewportWidth: 500
        ), 0)
    }

    func testDoesNotProduceInvalidOffsetsOnMalformedInput() {
        XCTAssertEqual(ClipboardCarouselWheelPolicy.displacement(
            deltaX: .nan, deltaY: -3, precise: true
        ), 0)
        XCTAssertEqual(ClipboardCarouselWheelPolicy.offset(
            from: .infinity, by: 5, contentWidth: 1000, viewportWidth: 500
        ), 0)
    }
}
