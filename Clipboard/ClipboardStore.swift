import Foundation
import SQLite3

enum ClipboardStoreError: LocalizedError {
    case database(String)
    case missingSupportDirectory
    case missingAsset(String)
    case invalidArchive
    case excessivePayload

    var errorDescription: String? {
        switch self {
        case .database(let detail): return "Clipboard database: \(detail)"
        case .missingSupportDirectory: return "Application Support directory is unavailable."
        case .missingAsset(let path): return "An image asset is missing: \(path). Existing history was not migrated."
        case .invalidArchive: return "Backup contents are malformed or exceed supported limits."
        case .excessivePayload: return "The copied item exceeds supported size limits."
        }
    }
}

private struct SealedClipContent: Codable {
    var kind: String
    var preview: String
    var body: String?
    var assetFilename: String?
    var filePath: String?
    var sourceApp: String
    var collection: String?
    var richData: Data? = nil
    var richType: String? = nil
}

private struct ClipboardBackupDocument: Codable {
    struct Entry: Codable {
        let content: SealedClipContent
        let createdAt: Double
        let pinned: Bool
        let imageData: Data?
    }
    let format: String
    let entries: [Entry]
}

/// Database stores ONLY keyed fingerprints, timestamps, pinned flags and AEAD ciphertext.
/// Content, filenames, source applications and collections are encrypted in the record.
final class ClipboardStore {
    private let database: OpaquePointer
    private let vault: ClipboardVault
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private var writesSinceMaintenance = 0
    private var lastMaintenanceTime = Date.distantPast
    private var decryptedCache: [(item: ClipItem, record: SealedClipContent)]?
    let assetsDirectory: URL

    /// Inject testKey and an isolated directory for tests; production uses the login Keychain.
    init(directoryOverride: URL? = nil, testKey: Data? = nil) throws {
        let root: URL
        if let directoryOverride {
            root = directoryOverride
        } else {
            guard let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first else { throw ClipboardStoreError.missingSupportDirectory }
            root = base
        }
        let directory = root.appendingPathComponent("Clipboard", isDirectory: true)
        assetsDirectory = directory.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(
            at: assetsDirectory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        for path in [directory.path, assetsDirectory.path] {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path)
        }

        let url = directory.appendingPathComponent("history.sqlite3")
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(
            url.path, &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil
        )
        guard result == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            throw ClipboardStoreError.database("Unable to open SQLite (code \(result))")
        }
        let key: ClipboardVault
        do {
            if let testKey {
                key = try ClipboardVault(testKey: testKey)
            } else {
                key = try ClipboardVault.open(
                    allowNewKey: !Self.databaseContainsEncryptedRows(handle)
                )
            }
        } catch {
            sqlite3_close(handle)
            throw error
        }
        database = handle
        vault = key
        do {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path
        )
        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA busy_timeout=5000;")
        try execute("PRAGMA secure_delete=ON;")
        try verifyIntegrity()
        try execute("""
            CREATE TABLE IF NOT EXISTS secure_clips (
                id TEXT PRIMARY KEY NOT NULL,
                fingerprint TEXT NOT NULL UNIQUE,
                created_at REAL NOT NULL,
                pinned INTEGER NOT NULL DEFAULT 0,
                sealed BLOB NOT NULL
            );
            """)
        try execute("CREATE INDEX IF NOT EXISTS secure_clips_recent ON secure_clips(pinned DESC, created_at DESC);")
        try migrateLegacyIfNeeded()
        try prune()
        } catch {
            // A failed initializer has no deinit; close the opened SQLite handle.
            sqlite3_close(handle)
            throw error
        }
    }

    deinit { sqlite3_close(database) }

    private static func databaseContainsEncryptedRows(_ connection: OpaquePointer) throws -> Bool {
        var stmt: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='secure_clips'"
        guard sqlite3_prepare_v2(connection, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt else { throw ClipboardStoreError.database("Cannot inspect existing database") }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return false }

        var rows: OpaquePointer?
        guard sqlite3_prepare_v2(connection, "SELECT 1 FROM secure_clips LIMIT 1", -1, &rows, nil) == SQLITE_OK,
              let rows else { throw ClipboardStoreError.database("Cannot inspect encrypted data") }
        defer { sqlite3_finalize(rows) }
        return sqlite3_step(rows) == SQLITE_ROW
    }

    private func hasLegacyTable() throws -> Bool {
        let stmt = try prepare(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='clips';"
        )
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private struct LegacyRow {
        let id: String
        let record: SealedClipContent
        let fingerprint: String
        let date: Double
        let pinned: Bool
    }

    private func migrateLegacyIfNeeded() throws {
        guard try hasLegacyTable() else {
            try execute("PRAGMA user_version=3;")
            // Complete cleanup if a previous launch migrated SQLite but was
            // interrupted before deleting legacy plaintext assets.
            try removeLegacyPNGAssets()
            return
        }

        let legacyHasCollection = try columnExists("collection", in: "clips")
        let column = legacyHasCollection ? "collection" : "NULL"
        var rows: [LegacyRow] = []
        do {
            let stmt = try prepare("""
                SELECT id,kind,preview,body,asset_filename,file_path,
                       source_app,created_at,pinned,fingerprint,\(column) FROM clips;
                """)
            defer { sqlite3_finalize(stmt) }
            while true {
                let status = sqlite3_step(stmt)
                if status == SQLITE_DONE { break }
                guard status == SQLITE_ROW else { throw sqliteError() }
                guard let id = text(stmt, 0), let kind = text(stmt, 1),
                      let preview = text(stmt, 2), let source = text(stmt, 6),
                      let fingerprint = text(stmt, 9) else {
                    throw ClipboardStoreError.database("Legacy record contains invalid values")
                }
                rows.append(LegacyRow(
                    id: id,
                    record: SealedClipContent(
                        kind: kind, preview: preview, body: text(stmt, 3),
                        assetFilename: text(stmt, 4), filePath: text(stmt, 5),
                        sourceApp: source, collection: text(stmt, 10)
                    ),
                    fingerprint: fingerprint,
                    date: sqlite3_column_double(stmt, 7),
                    pinned: sqlite3_column_int(stmt, 8) != 0
                ))
            }
        }

        try execute("BEGIN IMMEDIATE;")
        do {
            for row in rows {
                let keyed = vault.fingerprint(for: row.fingerprint)
                var record = row.record
                if let filename = row.record.assetFilename {
                    guard filename.range(
                        of: #"^[a-f0-9]{64}\.png$"#, options: .regularExpression
                    ) != nil else { throw ClipboardStoreError.invalidArchive }
                    let oldURL = assetsDirectory.appendingPathComponent(filename)
                    guard FileManager.default.fileExists(atPath: oldURL.path) else {
                        throw ClipboardStoreError.missingAsset(filename)
                    }
                    let oldData = try Data(contentsOf: oldURL)
                    record.assetFilename = try storeImage(oldData, fingerprint: keyed)
                }
                let blob = try seal(record, id: row.id)
                let stmt = try prepare("""
                    INSERT OR IGNORE INTO secure_clips (id,fingerprint,created_at,pinned,sealed)
                    VALUES (?,?,?,?,?);
                    """)
                bind(row.id, to: 1, in: stmt)
                bind(keyed, to: 2, in: stmt)
                sqlite3_bind_double(stmt, 3, row.date)
                sqlite3_bind_int(stmt, 4, row.pinned ? 1 : 0)
                bind(blob, to: 5, in: stmt)
                do { try stepDone(stmt) } catch { sqlite3_finalize(stmt); throw error }
                sqlite3_finalize(stmt)
            }
            try execute("DROP TRIGGER IF EXISTS clips_insert;")
            try execute("DROP TRIGGER IF EXISTS clips_delete;")
            try execute("DROP TRIGGER IF EXISTS clips_update;")
            try execute("DROP TABLE IF EXISTS clips_fts;")
            try execute("DROP TABLE clips;")
            try execute("DROP INDEX IF EXISTS clips_recent;")
            try execute("DROP INDEX IF EXISTS clips_collection;")
            try execute("DROP INDEX IF EXISTS clips_kind;")
            try execute("PRAGMA user_version=3;")
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }

        // After the transaction succeeds, old plaintext pages and old PNG assets are
        // cleared on a best-effort basis. Filesystem snapshots/backups may retain data.
        try execute("PRAGMA wal_checkpoint(TRUNCATE);")
        try execute("VACUUM;")
        try execute("PRAGMA wal_checkpoint(TRUNCATE);")
        try removeLegacyPNGAssets()
    }

    private func removeLegacyPNGAssets() throws {
        let urls = try FileManager.default.contentsOfDirectory(
            at: assetsDirectory, includingPropertiesForKeys: nil
        )
        for url in urls where url.pathExtension.lowercased() == "png" {
            try FileManager.default.removeItem(at: url)
        }
    }

    func save(_ payload: ClipPayload, sourceApp: String) throws {
        try saveInternal(payload, sourceApp: sourceApp, createdAt: Date().timeIntervalSince1970)
        writesSinceMaintenance += 1
        // Batch directory scans and cleanup to reduce per-copy main-thread work.
        if writesSinceMaintenance >= 50
            || Date().timeIntervalSince(lastMaintenanceTime) >= 300 {
            try prune()
            writesSinceMaintenance = 0
            lastMaintenanceTime = Date()
        }
    }

    private func saveInternal(
        _ payload: ClipPayload,
        sourceApp: String,
        createdAt: Double,
        importedPin: Bool = false,
        importedCollection: String? = nil
    ) throws {
        guard payload.preview.utf8.count <= 2 * 1024 * 1024,
              (payload.body?.utf8.count ?? 0) <= 2 * 1024 * 1024,
              (payload.imagePNG?.count ?? 0) <= 12 * 1024 * 1024,
              (payload.richData?.count ?? 0) <= 2 * 1024 * 1024,
              (payload.filePath?.utf8.count ?? 0) <= 100_000 else {
            throw ClipboardStoreError.excessivePayload
        }
        let fingerprint = vault.fingerprint(for: payload.fingerprint)
        let existing = try rowForFingerprint(fingerprint)
        let id = existing?.item.id ?? UUID().uuidString
        let imageFilename: String?
        if let image = payload.imagePNG {
            imageFilename = try storeImage(image, fingerprint: fingerprint)
        } else {
            imageFilename = nil
        }
        let record = SealedClipContent(
            kind: payload.kind.rawValue,
            preview: payload.preview,
            body: payload.body,
            assetFilename: imageFilename,
            filePath: payload.filePath,
            sourceApp: sourceApp,
            collection: existing?.item.collection ?? importedCollection,
            richData: payload.richData,
            richType: payload.richType
        )
        let sealed = try seal(record, id: id)
        if let existing {
            let stmt = try prepare("""
                UPDATE secure_clips SET sealed=?, created_at=?, pinned=? WHERE id=?;
                """)
            defer { sqlite3_finalize(stmt) }
            bind(sealed, to: 1, in: stmt)
            sqlite3_bind_double(stmt, 2, max(existing.item.createdAt.timeIntervalSince1970, createdAt))
            sqlite3_bind_int(stmt, 3, (existing.item.pinned || importedPin) ? 1 : 0)
            bind(id, to: 4, in: stmt)
            try stepDone(stmt)
        } else {
            let stmt = try prepare("""
                INSERT INTO secure_clips (id,fingerprint,created_at,pinned,sealed)
                VALUES (?,?,?,?,?);
                """)
            defer { sqlite3_finalize(stmt) }
            bind(id, to: 1, in: stmt)
            bind(fingerprint, to: 2, in: stmt)
            sqlite3_bind_double(stmt, 3, createdAt)
            sqlite3_bind_int(stmt, 4, importedPin ? 1 : 0)
            bind(sealed, to: 5, in: stmt)
            try stepDone(stmt)
        }
        decryptedCache = nil
    }

    private func storeImage(_ bytes: Data, fingerprint: String) throws -> String {
        guard bytes.count <= 12 * 1024 * 1024 else { throw ClipboardStoreError.excessivePayload }
        let filename = "\(fingerprint).bin"
        let path = assetsDirectory.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: path.path) {
            let encrypted = try vault.seal(bytes, context: "asset:\(fingerprint)")
            try encrypted.write(to: path, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: path.path
            )
        }
        return filename
    }

    private func seal(_ record: SealedClipContent, id: String) throws -> Data {
        try vault.seal(JSONEncoder().encode(record), context: "clip:\(id)")
    }

    private func open(_ data: Data, id: String) throws -> SealedClipContent {
        let plaintext = try vault.open(data, context: "clip:\(id)")
        return try JSONDecoder().decode(SealedClipContent.self, from: plaintext)
    }

    private func rowForFingerprint(_ fingerprint: String) throws -> (item: ClipItem, record: SealedClipContent)? {
        let stmt = try prepare("""
            SELECT id,fingerprint,created_at,pinned,sealed FROM secure_clips WHERE fingerprint=?;
            """)
        defer { sqlite3_finalize(stmt) }
        bind(fingerprint, to: 1, in: stmt)
        let status = sqlite3_step(stmt)
        if status == SQLITE_DONE { return nil }
        guard status == SQLITE_ROW else { throw sqliteError() }
        return try unpackRow(stmt)
    }

    private func unpackRow(_ stmt: OpaquePointer) throws -> (item: ClipItem, record: SealedClipContent) {
        guard let id = text(stmt, 0),
              let fingerprint = text(stmt, 1),
              let sealed = blob(stmt, 4) else {
            throw ClipboardStoreError.database("Encrypted row is incomplete")
        }
        let decoded = try open(sealed, id: id)
        guard let kind = ClipKind(rawValue: decoded.kind) else {
            throw ClipboardStoreError.database("Unrecognized clipboard record type")
        }
        return (
            ClipItem(
                id: id,
                kind: kind,
                preview: decoded.preview,
                body: decoded.body,
                assetFilename: decoded.assetFilename,
                filePath: decoded.filePath,
                sourceApp: decoded.sourceApp,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                pinned: sqlite3_column_int(stmt, 3) != 0,
                fingerprint: fingerprint,
                collection: decoded.collection,
                richData: decoded.richData,
                richType: decoded.richType
            ),
            decoded
        )
    }

    private func allRows() throws -> [(item: ClipItem, record: SealedClipContent)] {
        if let cached = decryptedCache { return cached }
        let stmt = try prepare("""
            SELECT id,fingerprint,created_at,pinned,sealed FROM secure_clips
            ORDER BY pinned DESC, created_at DESC;
            """)
        defer { sqlite3_finalize(stmt) }
        var rows: [(item: ClipItem, record: SealedClipContent)] = []
        while true {
            let status = sqlite3_step(stmt)
            if status == SQLITE_DONE {
                // Keep small-to-medium decoded histories hot; limit memory retained by the UI.
                let footprint = rows.reduce(0) { total, value in
                    total + value.item.preview.utf8.count
                        + (value.item.body?.utf8.count ?? 0)
                        + (value.item.filePath?.utf8.count ?? 0)
                        + (value.item.richData?.count ?? 0)
                }
                if footprint <= 32 * 1024 * 1024 {
                    decryptedCache = rows
                }
                return rows
            }
            guard status == SQLITE_ROW else { throw sqliteError() }
            rows.append(try unpackRow(stmt))
        }
    }

    func items(
        search: String, pinnedOnly: Bool = false,
        collection: String? = nil, kind: ClipKind? = nil
    ) throws -> [ClipItem] {
        // Deliberately avoid a plaintext FTS index. Search occurs over decrypted
        // in-memory records, which must be profiled on large clip histories.
        let terms = search.split(whereSeparator: \.isWhitespace).prefix(8).map(String.init)
        var result: [ClipItem] = []
        for row in try allRows() {
            let item = row.item
            if pinnedOnly && !item.pinned { continue }
            if let collection, item.collection != collection { continue }
            if let kind, item.kind != kind { continue }
            if !terms.allSatisfy({
                item.preview.localizedStandardContains($0)
                || (item.body?.localizedStandardContains($0) ?? false)
            }) { continue }
            result.append(item)
            if result.count >= 500 { break }
        }
        return result
    }

    func collectionNames() throws -> [String] {
        Array(Set(try allRows().compactMap { $0.item.collection })).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    func setCollection(_ name: String?, id: String) throws {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed?.count ?? 0) <= 60 else {
            throw ClipboardStoreError.database("Collection name must be 60 characters or fewer")
        }
        try updateRecord(id: id) { record in
            record.collection = trimmed?.isEmpty == true ? nil : trimmed
        }
    }

    private func updateRecord(id: String, change: (inout SealedClipContent) -> Void) throws {
        let stmt = try prepare("""
            SELECT id,fingerprint,created_at,pinned,sealed FROM secure_clips WHERE id=?;
            """)
        bind(id, to: 1, in: stmt)
        let status = sqlite3_step(stmt)
        guard status == SQLITE_ROW else {
            sqlite3_finalize(stmt)
            if status == SQLITE_DONE { return }
            throw sqliteError()
        }
        var record: SealedClipContent
        do { record = try unpackRow(stmt).record }
        catch { sqlite3_finalize(stmt); throw error }
        sqlite3_finalize(stmt)
        change(&record)
        let update = try prepare("UPDATE secure_clips SET sealed=? WHERE id=?;")
        defer { sqlite3_finalize(update) }
        bind(try seal(record, id: id), to: 1, in: update)
        bind(id, to: 2, in: update)
        try stepDone(update)
        decryptedCache = nil
    }

    func setPinned(_ pinned: Bool, id: String) throws {
        let stmt = try prepare("UPDATE secure_clips SET pinned=? WHERE id=?;")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, pinned ? 1 : 0)
        bind(id, to: 2, in: stmt)
        try stepDone(stmt)
        decryptedCache = nil
    }

    func delete(id: String) throws {
        let stmt = try prepare("DELETE FROM secure_clips WHERE id=?;")
        defer { sqlite3_finalize(stmt) }
        bind(id, to: 1, in: stmt)
        try stepDone(stmt)
        decryptedCache = nil
        try removeUnreferencedAssets()
    }

    func clearAll() throws {
        try execute("DELETE FROM secure_clips;")
        decryptedCache = nil
        try removeUnreferencedAssets()
        try execute("VACUUM;")
        try execute("PRAGMA wal_checkpoint(TRUNCATE);")
    }

    func assetURL(for item: ClipItem) -> URL? {
        guard let filename = item.assetFilename,
              filename.range(of: #"^[a-f0-9]{64}\.bin$"#, options: .regularExpression) != nil
        else { return nil }
        return assetsDirectory.appendingPathComponent(filename)
    }

    func thumbnailSource(for item: ClipItem) -> ClipboardThumbnailSource? {
        guard let url = assetURL(for: item) else { return nil }
        return ClipboardThumbnailSource(
            url: url, fingerprint: item.fingerprint, vault: vault
        )
    }

    func imageData(for item: ClipItem) throws -> Data? {
        guard let url = assetURL(for: item) else { return nil }
        let data = try Data(contentsOf: url)
        return try vault.open(data, context: "asset:\(item.fingerprint)")
    }

    func prune(maxUnpinnedImageBytes: Int64 = 512 * 1024 * 1024) throws {
        decryptedCache = nil
        lastMaintenanceTime = Date()
        let expiry = Date().addingTimeInterval(
            -Double(ClipboardPreferences.retentionDays) * 86_400
        ).timeIntervalSince1970
        let expired = try prepare("DELETE FROM secure_clips WHERE pinned=0 AND created_at < ?;")
        sqlite3_bind_double(expired, 1, expiry)
        do { try stepDone(expired) } catch { sqlite3_finalize(expired); throw error }
        sqlite3_finalize(expired)

        let capped = try prepare("""
            DELETE FROM secure_clips WHERE pinned=0 AND id NOT IN (
                SELECT id FROM secure_clips WHERE pinned=0 ORDER BY created_at DESC LIMIT ?
            );
            """)
        sqlite3_bind_int(capped, 1, Int32(ClipboardPreferences.retentionCount))
        do { try stepDone(capped) } catch { sqlite3_finalize(capped); throw error }
        sqlite3_finalize(capped)

        // Do not perform expensive image conversions during pruning.
        let unpinnedImages = try allRows()
            .filter { !$0.item.pinned && $0.item.assetFilename != nil }
            .sorted { $0.item.createdAt < $1.item.createdAt }
        var budget: Int64 = 0
        var sizes: [(id: String, size: Int64)] = []
        for entry in unpinnedImages {
            guard let url = assetURL(for: entry.item) else { continue }
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            budget += size
            sizes.append((id: entry.item.id, size: size))
        }
        if budget > maxUnpinnedImageBytes {
            let stmt = try prepare("DELETE FROM secure_clips WHERE id=? AND pinned=0;")
            defer { sqlite3_finalize(stmt) }
            for entry in sizes where budget > maxUnpinnedImageBytes {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
                bind(entry.id, to: 1, in: stmt)
                try stepDone(stmt)
                budget -= entry.size
            }
        }
        // Row deletes above invalidate the decoded cache used by items() and GC.
        decryptedCache = nil
        try removeUnreferencedAssets()
    }

    private func removeUnreferencedAssets() throws {
        let active = Set(try allRows().compactMap { $0.item.assetFilename })
        let urls = try FileManager.default.contentsOfDirectory(
            at: assetsDirectory, includingPropertiesForKeys: nil
        )
        for url in urls where url.pathExtension == "bin" && !active.contains(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func exportBackup(password: String) throws -> Data {
        var entries: [ClipboardBackupDocument.Entry] = []
        var bytes = 0
        for row in try allRows() {
            let image = try imageData(for: row.item)
            bytes += row.item.preview.utf8.count
                + (row.item.body?.utf8.count ?? 0)
                + (row.item.richData?.count ?? 0)
                + (image?.count ?? 0)
            guard bytes <= 75 * 1024 * 1024 else { throw ClipboardBackupError.tooLarge }
            entries.append(ClipboardBackupDocument.Entry(
                content: row.record,
                createdAt: row.item.createdAt.timeIntervalSince1970,
                pinned: row.item.pinned,
                imageData: image
            ))
        }
        let document = ClipboardBackupDocument(format: "CLIPBOARD_EXPORT_V1", entries: entries)
        return try ClipboardBackupCrypto.seal(JSONEncoder().encode(document), password: password)
    }

    func importBackup(_ file: Data, password: String) throws {
        let raw = try ClipboardBackupCrypto.open(file, password: password)
        let doc = try JSONDecoder().decode(ClipboardBackupDocument.self, from: raw)
        guard doc.format == "CLIPBOARD_EXPORT_V1", doc.entries.count <= 10_000 else {
            throw ClipboardStoreError.invalidArchive
        }
        var total = 0
        for entry in doc.entries {
            total += entry.content.preview.utf8.count
                + (entry.content.body?.utf8.count ?? 0)
                + (entry.content.richData?.count ?? 0)
                + (entry.imageData?.count ?? 0)
            guard total <= 75 * 1024 * 1024,
                  entry.content.preview.utf8.count <= 2 * 1024 * 1024,
                  (entry.content.body?.utf8.count ?? 0) <= 2 * 1024 * 1024,
                  (entry.content.richData?.count ?? 0) <= 2 * 1024 * 1024,
                  (entry.imageData?.count ?? 0) <= 12 * 1024 * 1024,
                  (entry.content.filePath?.utf8.count ?? 0) <= 100_000,
                  (entry.content.collection?.count ?? 0) <= 60,
                  ClipKind(rawValue: entry.content.kind) != nil,
                  (entry.content.kind != ClipKind.image.rawValue || entry.imageData != nil),
                  (entry.content.kind != ClipKind.richText.rawValue ||
                       (entry.content.richData != nil && entry.content.richType != nil)),
                  entry.createdAt.isFinite else {
                throw ClipboardStoreError.invalidArchive
            }
        }
        try execute("BEGIN IMMEDIATE;")
        do {
            decryptedCache = nil
            for entry in doc.entries {
                guard let kind = ClipKind(rawValue: entry.content.kind) else {
                    throw ClipboardStoreError.invalidArchive
                }
                let payload = ClipPayload(
                    kind: kind, preview: entry.content.preview,
                    body: entry.content.body, imagePNG: entry.imageData,
                    filePath: entry.content.filePath,
                    richData: entry.content.richData, richType: entry.content.richType
                )
                try saveInternal(
                    payload,
                    sourceApp: entry.content.sourceApp,
                    createdAt: entry.createdAt,
                    importedPin: entry.pinned,
                    importedCollection: entry.content.collection
                )
            }
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            // Any partially written encrypted assets are deleted on the next prune.
            throw error
        }
        try prune()
    }

    private func verifyIntegrity() throws {
        let stmt = try prepare("PRAGMA quick_check(1);")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              text(stmt, 0) == "ok" else {
            throw ClipboardStoreError.database("SQLite integrity check failed. Use Storage Recovery in settings.")
        }
    }

    private func columnExists(_ name: String, in table: String) throws -> Bool {
        let stmt = try prepare("PRAGMA table_info(\(table));")
        defer { sqlite3_finalize(stmt) }
        while true {
            let status = sqlite3_step(stmt)
            if status == SQLITE_DONE { return false }
            guard status == SQLITE_ROW else { throw sqliteError() }
            if text(stmt, 1) == name { return true }
        }
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorPointer)
            throw ClipboardStoreError.database(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt else { throw sqliteError() }
        return stmt
    }

    private func bind(_ value: String?, to index: Int32, in stmt: OpaquePointer) {
        guard let value else {
            sqlite3_bind_null(stmt, index)
            return
        }
        sqlite3_bind_text(stmt, index, value, -1, transient)
    }

    private func bind(_ value: Data, to index: Int32, in stmt: OpaquePointer) {
        value.withUnsafeBytes { raw in
            _ = sqlite3_bind_blob(stmt, index, raw.baseAddress, Int32(raw.count), transient)
        }
    }

    private func text(_ stmt: OpaquePointer, _ index: Int32) -> String? {
        guard let raw = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: UnsafeRawPointer(raw).assumingMemoryBound(to: CChar.self))
    }

    private func blob(_ stmt: OpaquePointer, _ index: Int32) -> Data? {
        guard let ptr = sqlite3_column_blob(stmt, index) else { return nil }
        return Data(bytes: ptr, count: Int(sqlite3_column_bytes(stmt, index)))
    }

    private func stepDone(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError() }
    }

    private func sqliteError() -> ClipboardStoreError {
        ClipboardStoreError.database(String(cString: sqlite3_errmsg(database)))
    }
}
