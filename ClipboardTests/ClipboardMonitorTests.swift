import AppKit
import XCTest
@testable import Clipboard

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    func testCapturesNewTextButNotPreviousContent() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("old content", forType: .string)
        var captured: [String] = []
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            sourceInfo: { ("com.example.notes", "Notes") }
        ) { payload, _ in
            captured.append(payload.body ?? "")
        }

        monitor.pollOnce()
        XCTAssertTrue(captured.isEmpty)
        pasteboard.clearContents()
        pasteboard.setString("new content", forType: .string)
        monitor.pollOnce()
        XCTAssertEqual(captured, ["new content"])
    }

    func testPausedContentIsNeverImportedOnResume() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        var captured = 0
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            sourceInfo: { ("com.example.notes", "Notes") }
        ) { _, _ in captured += 1 }
        monitor.isPaused = true
        pasteboard.clearContents()
        pasteboard.setString("secret while paused", forType: .string)
        monitor.pollOnce()
        monitor.isPaused = false
        monitor.pollOnce()
        XCTAssertEqual(captured, 0)
        pasteboard.clearContents()
        pasteboard.setString("new", forType: .string)
        monitor.pollOnce()
        XCTAssertEqual(captured, 1)
    }

    func testExcludedApplicationIsNeverCaptured() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        var captured = 0
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            sourceInfo: { ("com.bitwarden.desktop", "Bitwarden") }
        ) { _, _ in captured += 1 }
        pasteboard.clearContents()
        pasteboard.setString("do-not-record", forType: .string)
        monitor.pollOnce()
        XCTAssertEqual(captured, 0)
    }
}
