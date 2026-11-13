import XCTest
@testable import Clipboard

final class ClipColorTests: XCTestCase {
    func testRecognizesCSSHexColors() {
        XCTAssertEqual(ClipText.kind(for: "#abc"), .color)
        XCTAssertEqual(ClipText.kind(for: "#aabbcc"), .color)
        XCTAssertEqual(ClipText.kind(for: "#AABBCCFF"), .color)
        XCTAssertEqual(ClipColor.hexValue("#000000")?.alpha, 1)
        XCTAssertEqual(ClipColor.hexValue("#ffffffff")?.alpha, 1)
        XCTAssertEqual(ClipColor.hexValue("#0000")?.alpha, 0)
    }

    func testRejectsNonColors() {
        for value in ["hello", "##ffeecc", "#12", "#xxyyzz", "#abcdxyz1", "color #fff"] {
            XCTAssertNil(ClipColor.hexValue(value))
        }
        XCTAssertEqual(ClipText.kind(for: "https://example.com"), .link)
    }
}
