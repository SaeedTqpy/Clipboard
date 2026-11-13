import Foundation
import XCTest
@testable import Clipboard

final class ClipboardPerformanceTests: XCTestCase {
    func testEncryptedSearchAtFiveHundredItems() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardPerf-\(UUID().uuidString)", isDirectory: true)
        do {
        let store = try ClipboardStore(
            directoryOverride: root,
            testKey: Data(repeating: 0x77, count: 32)
        )

        for index in 0..<500 {
            let text = "Synthetic entry \(index) - private search token \(index)"
            try store.save(
                ClipPayload(kind: .text, preview: text, body: text),
                sourceApp: "Synthetic Test"
            )
        }
        XCTAssertEqual(try store.items(search: "").count, 500)
        XCTAssertEqual(try store.items(search: "entry 499").count, 1)
        measure(metrics: [XCTClockMetric()]) {
            _ = try? store.items(search: "entry 350")
        }
        } // Release the SQLite connection before removing its backing files.
        try FileManager.default.removeItem(at: root)
    }
}
