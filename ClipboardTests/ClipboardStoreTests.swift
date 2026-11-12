import Foundation
import XCTest
@testable import Clipboard

final class ClipboardStoreTests: XCTestCase {
    private func temporaryStore() throws -> (ClipboardStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try ClipboardStore(directoryOverride: directory), directory)
    }

    func testTextSavedAndSearchedWithoutTouchingRealHistory() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.save(ClipPayload(kind: .text, preview: "Engineering handbook", body: "Swift and SQLite"), sourceApp: "Xcode")
        XCTAssertEqual(try store.items(search: "").count, 1)
        XCTAssertEqual(try store.items(search: "Swift").count, 1)
        XCTAssertTrue(try store.items(search: "unknown").isEmpty)
    }

    func testIdenticalClipboardEntriesAreDeduplicated() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = ClipPayload(kind: .text, preview: "hello", body: "hello")
        try store.save(payload, sourceApp: "Notes")
        try store.save(payload, sourceApp: "Safari")
        let results = try store.items(search: "")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].sourceApp, "Safari")
    }

    func testRemovingImageCleansUpAsset() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let pngData = Data([0x89, 0x50, 0x4E, 0x47]) // Test asset bytes only.
        try store.save(ClipPayload(kind: .image, preview: "Image", imagePNG: pngData), sourceApp: "Preview")
        let items = try store.items(search: "")
        XCTAssertEqual(items.count, 1)
        guard let url = store.assetURL(for: items[0]) else {
            XCTFail("Expected image asset")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try store.delete(id: items[0].id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testCollectionsPersistAndFilter() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.save(ClipPayload(kind: .text, preview: "Alpha", body: "Alpha"), sourceApp: "Notes")
        try store.save(ClipPayload(kind: .text, preview: "Beta", body: "Beta"), sourceApp: "Notes")
        let all = try store.items(search: "")
        XCTAssertEqual(all.count, 2)
        guard let alpha = all.first(where: { $0.preview == "Alpha" }) else {
            XCTFail("Missing Alpha")
            return
        }
        try store.setCollection("Work", id: alpha.id)
        XCTAssertEqual(try store.collectionNames(), ["Work"])
        XCTAssertEqual(try store.items(search: "", collection: "Work").map(\.preview), ["Alpha"])
        try store.setCollection(nil, id: alpha.id)
        XCTAssertTrue(try store.collectionNames().isEmpty)
    }

    func testFilterByContentKind() throws {
        let (store, root) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.save(ClipPayload(kind: .text, preview: "plain", body: "plain"), sourceApp: "Notes")
        try store.save(ClipPayload(kind: .link, preview: "https://example.com", body: "https://example.com"), sourceApp: "Safari")
        XCTAssertEqual(try store.items(search: "", kind: .link).count, 1)
        XCTAssertEqual(try store.items(search: "", kind: .text).count, 1)
        XCTAssertEqual(try store.items(search: "example", kind: .text).count, 0)
    }
}
