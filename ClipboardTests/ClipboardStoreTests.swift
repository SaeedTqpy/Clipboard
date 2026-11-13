import Foundation
import XCTest
import SQLite3
@testable import Clipboard

final class ClipboardStoreTests: XCTestCase {
    private var temporaryRoots: [URL] = []

    override func tearDownWithError() throws {
        // All local stores are released when the test method returns; never
        // unlink SQLite WAL/SHM files while their connection is still open.
        for root in temporaryRoots {
            try? FileManager.default.removeItem(at: root)
        }
        temporaryRoots.removeAll()
        try super.tearDownWithError()
    }

    private func temporaryStore() throws -> (ClipboardStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryRoots.append(directory)
        return (try ClipboardStore(directoryOverride: directory, testKey: Data(repeating: 0x42, count: 32)), directory)
    }

    func testTextSavedAndSearchedWithoutTouchingRealHistory() throws {
        let (store, root) = try temporaryStore()
        try store.save(ClipPayload(kind: .text, preview: "Engineering handbook", body: "Swift and SQLite"), sourceApp: "Xcode")
        XCTAssertEqual(try store.items(search: "").count, 1)
        XCTAssertEqual(try store.items(search: "Swift").count, 1)
        XCTAssertTrue(try store.items(search: "unknown").isEmpty)
    }

    func testIdenticalClipboardEntriesAreDeduplicated() throws {
        let (store, root) = try temporaryStore()
        let payload = ClipPayload(kind: .text, preview: "hello", body: "hello")
        try store.save(payload, sourceApp: "Notes")
        try store.save(payload, sourceApp: "Safari")
        let results = try store.items(search: "")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].sourceApp, "Safari")
    }

    func testRemovingImageCleansUpAsset() throws {
        let (store, root) = try temporaryStore()
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
        try store.save(ClipPayload(kind: .text, preview: "plain", body: "plain"), sourceApp: "Notes")
        try store.save(ClipPayload(kind: .link, preview: "https://example.com", body: "https://example.com"), sourceApp: "Safari")
        XCTAssertEqual(try store.items(search: "", kind: .link).count, 1)
        XCTAssertEqual(try store.items(search: "", kind: .text).count, 1)
        XCTAssertEqual(try store.items(search: "example", kind: .text).count, 0)
    }

    func testImageBudgetPrunesUnpinnedImageAssets() throws {
        let (store, root) = try temporaryStore()
        try store.save(ClipPayload(
            kind: .image, preview: "Test Image",
            imagePNG: Data([0x89, 0x50, 0x4e, 0x47])
        ), sourceApp: "Preview")
        XCTAssertEqual(try store.items(search: "").count, 1)
        try store.prune(maxUnpinnedImageBytes: 1)
        XCTAssertTrue(try store.items(search: "").isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(
            at: store.assetsDirectory, includingPropertiesForKeys: nil
        ).isEmpty)
    }

    func testEncryptedStoreDoesNotPersistTextInDatabaseFile() throws {
        let (store, root) = try temporaryStore()
        let secret = "SUPER-SENSITIVE-CLIPBOARD-TOKEN-4250"
        try store.save(ClipPayload(kind: .text, preview: secret, body: secret), sourceApp: "Notes")
        XCTAssertEqual(try store.items(search: "SENSITIVE").count, 1)
        let databaseURL = root.appendingPathComponent("Clipboard/history.sqlite3")
        let databaseBytes = try Data(contentsOf: databaseURL)
        XCTAssertNil(databaseBytes.range(of: Data(secret.utf8)))
        XCTAssertEqual(try store.items(search: "4250").count, 1)
    }

    func testPortableEncryptedBackupRestoresCollectionsAndPins() throws {
        let (source, sourceRoot) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        try source.save(ClipPayload(kind: .text, preview: "Archive", body: "Very private"), sourceApp: "Notes")
        let original = try XCTUnwrap(source.items(search: "").first)
        try source.setPinned(true, id: original.id)
        try source.setCollection("Work", id: original.id)
        let archive = try source.exportBackup(password: "strong back up password")

        let (target, targetRoot) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: targetRoot) }
        try target.importBackup(archive, password: "strong back up password")
        let restored = try XCTUnwrap(target.items(search: "").first)
        XCTAssertEqual(restored.body, "Very private")
        XCTAssertTrue(restored.pinned)
        XCTAssertEqual(restored.collection, "Work")
        XCTAssertThrowsError(
            try target.importBackup(archive, password: "incorrect password")
        )
        XCTAssertEqual(try target.items(search: "").count, 1)
    }

    func testLegacySQLiteAndPNGAreMigratedToEncryptedHistory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardLegacy-\(UUID().uuidString)")
        temporaryRoots.append(root)
        let appFolder = root.appendingPathComponent("Clipboard")
        let assetFolder = appFolder.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(
            at: assetFolder, withIntermediateDirectories: true
        )
        let oldFingerprint = String(repeating: "a", count: 64)
        let filename = oldFingerprint + ".png"
        let originalImage = Data([0x89, 0x50, 0x4e, 0x47])
        try originalImage.write(to: assetFolder.appendingPathComponent(filename))
        let dbFile = appFolder.appendingPathComponent("history.sqlite3")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbFile.path, &handle), SQLITE_OK)
        defer { if let handle { sqlite3_close(handle) } }
        let statements = """
            CREATE TABLE clips (
                id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL,
                preview TEXT NOT NULL, body TEXT, asset_filename TEXT,
                file_path TEXT, source_app TEXT NOT NULL,
                created_at REAL NOT NULL, pinned INTEGER NOT NULL DEFAULT 0,
                fingerprint TEXT NOT NULL UNIQUE, collection TEXT
            );
            INSERT INTO clips VALUES (
                'legacy-01', 'image', 'PRIVATE-LEGACY-IMAGE-2026', NULL,
                '\(filename)', NULL, 'Preview', 1000000000.0, 1,
                '\(oldFingerprint)', 'Archive'
            );
            PRAGMA user_version=2;
            """
        XCTAssertEqual(sqlite3_exec(handle, statements, nil, nil, nil), SQLITE_OK)
        sqlite3_close(handle)
        handle = nil

        let store = try ClipboardStore(
            directoryOverride: root, testKey: Data(repeating: 0x42, count: 32)
        )
        let migrated = try XCTUnwrap(store.items(search: "LEGACY").first)
        XCTAssertTrue(migrated.pinned)
        XCTAssertEqual(migrated.collection, "Archive")
        XCTAssertEqual(try store.imageData(for: migrated), originalImage)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: assetFolder.appendingPathComponent(filename).path
        ))
        XCTAssertNil(try Data(contentsOf: dbFile).range(
            of: Data("PRIVATE-LEGACY-IMAGE-2026".utf8)
        ))
    }

    func testRecoveryQuarantinesFilesInsteadOfDeletingThem() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardRecovery-\(UUID().uuidString)")
        temporaryRoots.append(root)
        let key = Data(repeating: 0x42, count: 32)
        do {
            let store = try ClipboardStore(directoryOverride: root, testKey: key)
            try store.save(ClipPayload(kind: .text, preview: "preserve", body: "preserve"), sourceApp: "Notes")
        }
        let quarantine = try ClipboardRecovery.quarantine(baseDirectory: root)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: quarantine.appendingPathComponent("history.sqlite3").path
        ))
        let restarted = try ClipboardStore(directoryOverride: root, testKey: key)
        XCTAssertTrue(try restarted.items(search: "").isEmpty)
    }
    func testCorruptDatabaseFailsClosedWithoutDeletingUserFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardCorrupt-\(UUID().uuidString)")
        temporaryRoots.append(root)
        let folder = root.appendingPathComponent("Clipboard", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true
        )
        let database = folder.appendingPathComponent("history.sqlite3")
        let original = Data("THIS IS NOT A SQLITE DATABASE".utf8)
        try original.write(to: database)
        XCTAssertThrowsError(try ClipboardStore(
            directoryOverride: root,
            testKey: Data(repeating: 0x42, count: 32)
        ))
        XCTAssertEqual(try Data(contentsOf: database), original)
    }

    func testOCRTextIsEncryptedSearchableAndRestoredWithImage() throws {
        let (store, _) = try temporaryStore()
        let image = Data([0x89, 0x50, 0x4e, 0x47])
        let hiddenOCR = "BANK-INVOICE-REFERENCE-4821"
        try store.save(
            ClipPayload(kind: .image, preview: "Image", imagePNG: image,
                        recognizedText: hiddenOCR),
            sourceApp: "Preview"
        )
        let match = try XCTUnwrap(store.items(search: "INVOICE").first)
        XCTAssertEqual(match.recognizedText, hiddenOCR)
        XCTAssertEqual(try store.imageData(for: match), image)
        let archive = try store.exportBackup(password: "correct horse battery staple")

        let (restored, _) = try temporaryStore()
        try restored.importBackup(archive, password: "correct horse battery staple")
        let found = try XCTUnwrap(restored.items(search: "4821").first)
        XCTAssertEqual(found.recognizedText, hiddenOCR)
        XCTAssertEqual(try restored.imageData(for: found), image)
    }

    func testSnippetSurvivesRetentionAndSupportsEditing() throws {
        let (store, _) = try temporaryStore()
        try store.createSnippet(title: "Daily Status", body: "Original daily status")
        let original = try XCTUnwrap(store.items(search: "Original").first)
        XCTAssertEqual(original.collection, "Snippets")
        XCTAssertEqual(original.displayName, "Daily Status")
        XCTAssertTrue(original.pinned)

        try store.updateClip(
            id: original.id, title: "Daily Report",
            text: "Updated daily status", asSnippet: true
        )
        let edited = try XCTUnwrap(store.items(search: "Daily Report").first)
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.body, "Updated daily status")
        XCTAssertTrue(edited.pinned)
        XCTAssertEqual(edited.collection, "Snippets")
        XCTAssertTrue(try store.items(search: "Original daily status").isEmpty)

        try store.prune(maxUnpinnedImageBytes: 0)
        XCTAssertNotNil(try store.items(search: "Updated").first)

        let archive = try store.exportBackup(password: "correct horse battery staple")
        let (restored, _) = try temporaryStore()
        try restored.importBackup(archive, password: "correct horse battery staple")
        let result = try XCTUnwrap(restored.items(search: "Report").first)
        XCTAssertTrue(result.pinned)
        XCTAssertEqual(result.displayName, "Daily Report")
        XCTAssertEqual(result.collection, "Snippets")
    }

    func testEditedFingerprintDeduplicatesCorrectlyAndRejectsCollision() throws {
        let (store, _) = try temporaryStore()
        try store.save(
            ClipPayload(kind: .text, preview: "one", body: "one"), sourceApp: "Notes"
        )
        try store.save(
            ClipPayload(kind: .text, preview: "two", body: "two"), sourceApp: "Notes"
        )
        let first = try XCTUnwrap(store.items(search: "one").first)
        let second = try XCTUnwrap(store.items(search: "two").first)
        XCTAssertThrowsError(try store.editText(id: first.id, newText: "two"))
        XCTAssertEqual(try store.items(search: "").count, 2)

        try store.editText(id: first.id, newText: "three")
        XCTAssertTrue(try store.items(search: "one").isEmpty)
        XCTAssertEqual(try store.items(search: "three").count, 1)
        try store.save(
            ClipPayload(kind: .text, preview: "three", body: "three"), sourceApp: "Safari"
        )
        XCTAssertEqual(try store.items(search: "").count, 2)
        XCTAssertEqual(
            try XCTUnwrap(store.items(search: "three").first).sourceApp, "Safari"
        )
        XCTAssertNotNil(try store.items(search: "two").first)
        XCTAssertEqual(second.body, "two")
    }

    func testAppDateFiltersAndRecentClearKeepPinnedClips() throws {
        let (store, _) = try temporaryStore()
        try store.save(
            ClipPayload(kind: .text, preview: "bank work", body: "bank work"),
            sourceApp: "Xcode"
        )
        try store.save(
            ClipPayload(kind: .text, preview: "browser link", body: "browser link"),
            sourceApp: "Safari"
        )
        XCTAssertEqual(try store.sourceApplicationNames(), ["Safari", "Xcode"])
        XCTAssertEqual(try store.items(search: "", sourceApp: "Xcode").count, 1)
        XCTAssertTrue(try store.items(
            search: "", since: Date().addingTimeInterval(3600)
        ).isEmpty)

        let bank = try XCTUnwrap(store.items(search: "bank").first)
        try store.setPinned(true, id: bank.id)
        try store.deleteRecent(minutes: 5)
        XCTAssertEqual(try store.items(search: "").count, 1)
        XCTAssertEqual(try store.items(search: "").first?.id, bank.id)
    }

    func testColorTagsPersistFilterSearchAndBackup() throws {
        let (store, _) = try temporaryStore()
        try store.save(
            ClipPayload(kind: .text, preview: "first", body: "first"),
            sourceApp: "Notes"
        )
        try store.save(
            ClipPayload(kind: .text, preview: "second", body: "second"),
            sourceApp: "Safari"
        )
        let original = try XCTUnwrap(store.items(search: "first").first)
        let other = try XCTUnwrap(store.items(search: "second").first)
        let work = ClipTag(name: "Project Work", color: .violet)
        try store.addTag(work, to: original.id)
        try store.addTag(work, to: other.id)
        XCTAssertEqual(try store.tagCatalog().count, 1)
        XCTAssertEqual(try store.items(search: "Project Work").count, 2)
        XCTAssertEqual(try store.items(search: "", tagID: work.id).count, 2)

        try store.editTag(work.id, name: "Client Work", color: .turquoise)
        XCTAssertEqual(try store.items(search: "Project Work").count, 0)
        XCTAssertEqual(try store.items(search: "Client Work").count, 2)
        let edited = try XCTUnwrap(store.tagCatalog().first)
        XCTAssertEqual(edited.color, .turquoise)
        XCTAssertEqual(edited.name, "Client Work")

        let archive = try store.exportBackup(password: "color tag backup password")
        let (restored, _) = try temporaryStore()
        try restored.importBackup(archive, password: "color tag backup password")
        XCTAssertEqual(try restored.tagCatalog(), [edited])
        XCTAssertEqual(try restored.items(search: "", tagID: edited.id).count, 2)
    }

    func testTagsRemainOnDeduplicatedCopyAndEditedClip() throws {
        let (store, _) = try temporaryStore()
        let payload = ClipPayload(kind: .text, preview: "kept", body: "kept")
        try store.save(payload, sourceApp: "Notes")
        let original = try XCTUnwrap(store.items(search: "kept").first)
        let tag = ClipTag(name: "Important", color: .coral)
        try store.addTag(tag, to: original.id)
        try store.save(payload, sourceApp: "Safari")
        let copiedAgain = try XCTUnwrap(store.items(search: "kept").first)
        XCTAssertEqual(copiedAgain.id, original.id)
        XCTAssertEqual(copiedAgain.tags, [tag])

        try store.editText(id: original.id, newText: "kept and edited")
        let afterEdit = try XCTUnwrap(store.items(search: "edited").first)
        XCTAssertEqual(afterEdit.tags, [tag])
        try store.removeTag(tag.id, from: original.id)
        XCTAssertTrue(try store.tagCatalog().isEmpty)
        XCTAssertTrue(try store.items(search: "", tagID: tag.id).isEmpty)
    }

    func testTagsValidateAndLimitFivePerClip() throws {
        let (store, _) = try temporaryStore()
        try store.save(
            ClipPayload(kind: .text, preview: "many tags", body: "many tags"),
            sourceApp: "Notes"
        )
        let item = try XCTUnwrap(store.items(search: "").first)
        XCTAssertThrowsError(
            try store.addTag(ClipTag(name: " ", color: .green), to: item.id)
        )
        for number in 1...7 {
            try store.addTag(
                ClipTag(name: "Tag \(number)", color: .amber), to: item.id
            )
        }
        XCTAssertEqual(try store.items(search: "").first?.tags.count, 5)
    }

    func testOldEncryptedRecordWithoutTagFieldCanStillBeOpened() throws {
        // Existing encrypted records were written without a tag field; the
        // optional Codable property must decode safely as an empty UI list.
        let (store, _) = try temporaryStore()
        try store.save(
            ClipPayload(kind: .text, preview: "legacy copy", body: "legacy copy"),
            sourceApp: "Notes"
        )
        let reopened = try XCTUnwrap(store.items(search: "").first)
        XCTAssertTrue(reopened.tags.isEmpty)
    }

}
