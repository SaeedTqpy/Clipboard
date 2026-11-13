import Carbon
import XCTest
@testable import Clipboard

final class ClipboardHotkeyPresetTests: XCTestCase {
    func testPresetsHaveUniqueIDsAndValidModifiers() {
        let presets = ClipboardHotkeyPreset.allCases
        XCTAssertEqual(Set(presets.map(\.rawValue)).count, presets.count)
        for preset in presets {
            XCTAssertEqual(preset.keyCode, UInt32(kVK_ANSI_V))
            XCTAssertNotEqual(preset.carbonModifiers, 0)
            XCTAssertTrue(preset.displayName.hasSuffix("V"))
        }
    }

    func testHistoryPeriodProducesBoundedTimeWindow() {
        XCTAssertNil(ClipboardHistoryPeriod.all.startDate)
        for period in [
            ClipboardHistoryPeriod.today,
            ClipboardHistoryPeriod.week,
            ClipboardHistoryPeriod.month
        ] {
            guard let start = period.startDate else {
                XCTFail("Expected a bounded history period")
                continue
            }
            XCTAssertLessThanOrEqual(start, Date())
            XCTAssertGreaterThan(start, Date().addingTimeInterval(-40 * 86_400))
        }
    }
}
