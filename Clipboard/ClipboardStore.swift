import Foundation
import SQLite3

enum ClipboardStoreError: LocalizedError {
    case database(String)
    case missingSupportDirectory

    var errorDescription: String? {
        switch self {
        case .database(let message): return "Clipboard database: " + message
        case .missingSupportDirectory: return "Application Support directory unavailable."
        }
    }
}

final class ClipboardStore {
    private let database: OpaquePointer
    let assetsDirectory: URL

    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private var writesSinceMaintenance = 0

    /// Tests provide an isolated temporary root; production uses Application Support.
    init(directoryOverride: URL? = nil) throws {
        let root: URL
        if let directoryOverride {
            root = directoryOverride
        } else {
            guard let defaultRoot = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first else { throw ClipboardStoreError.missingSupportDirectory }
            root = defaultRoot
        }

        let folder = root.appendingPathComponent("Clipboard", isDirectory: true)
        assetsDirectory = folder.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(
            at: assetsDirectory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // Protect against a directory created by a previous application version.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: folder.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: assetsDirectory.path
        )

        let dbURL = folder.appendingPathComponent("history.sqlite3")
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(
            dbURL.path, &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil
        )
        guard result == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            throw ClipboardStoreError.database("Unable to open history database (code \(result))")
        }
        database = handle
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: dbURL.path
        )

        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA busy_timeout=3000;")
        try execute("PRAGMA secure_delete=ON;")
        try execute("""
            CREATE TABLE IF NOT EXISTS clips (
                id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                preview TEXT NOT NULL,
                body TEXT,
                asset_filename TEXT,
                file_path TEXT,
                source_app TEXT NOT NULL,
                created_at REAL NOT NULL,
                pinned INTEGER NOT NULL DEFAULT 0,
                fingerprint TEXT NOT NULL UNIQUE,
                collection TEXT
            );
            """)
        try execute("CREATE INDEX IF NOT EXISTS clips_recent ON clips(pinned DESC, created_at DESC);")
        try execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS clips_fts
            USING fts5(preview, body, content='clips', content_rowid='rowid');
            """)
        try execute("""
            CREATE TRIGGER IF NOT EXISTS clips_insert AFTER INSERT ON clips BEGIN
                INSERT INTO clips_fts(rowid, preview, body)
                VALUES(new.rowid, new.preview, new.body);
            END;
            """)
        try execute("""
            CREATE TRIGGER IF NOT EXISTS clips_delete AFTER DELETE ON clips BEGIN
                INSERT INTO clips_fts(clips_fts, rowid, preview, body)
                VALUES('delete', old.rowid, old.preview, old.body);
            END;
            """)
        try execute("""
            CREATE TRIGGER IF NOT EXISTS clips_update AFTER UPDATE ON clips BEGIN
                INSERT INTO clips_fts(clips_fts, rowid, preview, body)
                VALUES('delete', old.rowid, old.preview, old.body);
                INSERT INTO clips_fts(rowid, preview, body)
                VALUES(new.rowid, new.preview, new.body);
            END;
            """)
        // Versioning also repairs the FTS index of databases created before triggers.
        if try schemaVersion() == 0 {
            try execute("INSERT INTO clips_fts(clips_fts) VALUES('rebuild');")
            try execute("PRAGMA user_version=1;")
        }
        if try !hasColumn(named: "collection", in: "clips") {
            try execute("ALTER TABLE clips ADD COLUMN collection TEXT;")
        }
        try execute("CREATE INDEX IF NOT EXISTS clips_collection ON clips(collection, created_at DESC);")
        try execute("CREATE INDEX IF NOT EXISTS clips_kind ON clips(kind, created_at DESC);")
        try execute("PRAGMA user_version=2;")
        try prune()
    }

    deinit { sqlite3_close(database) }

    func save(_ payload: ClipPayload, sourceApp: String) throws {
        let filename = payload.imagePNG == nil ? nil : payload.fingerprint + ".png"
        if let data = payload.imagePNG, let filename {
            let fileURL = assetsDirectory.appendingPathComponent(filename)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
            )
        }

        let sql = """
            INSERT INTO clips (
                id, kind, preview, body, asset_filename, file_path,
                source_app, created_at, pinned, fingerprint
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
            ON CONFLICT(fingerprint) DO UPDATE SET
                created_at=excluded.created_at,
                source_app=excluded.source_app;
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(UUID().uuidString, to: 1, in: stmt)
        bind(payload.kind.rawValue, to: 2, in: stmt)
        bind(payload.preview, to: 3, in: stmt)
        bind(payload.body, to: 4, in: stmt)
        bind(filename, to: 5, in: stmt)
        bind(payload.filePath, to: 6, in: stmt)
        bind(sourceApp, to: 7, in: stmt)
        sqlite3_bind_double(stmt, 8, Date().timeIntervalSince1970)
        bind(payload.fingerprint, to: 9, in: stmt)
        try stepDone(stmt)
        writesSinceMaintenance += 1
        // A full asset directory scan on every copied item scales poorly.
        if writesSinceMaintenance >= 20 {
            try prune()
            writesSinceMaintenance = 0
        }
    }

    func items(
        search: String,
        pinnedOnly: Bool = false,
        collection: String? = nil,
        kind: ClipKind? = nil
    ) throws -> [ClipItem] {
        var sql = """
            SELECT id, kind, preview, body, asset_filename, file_path,
                   source_app, created_at, pinned, fingerprint, collection
            FROM clips WHERE 1=1
            """
        let terms = search.split(whereSeparator: { $0.isWhitespace }).prefix(8)
        let query = terms.map {
            "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"*"
        }.joined(separator: " AND ")
        var arguments: [String] = []
        if !query.isEmpty {
            sql += " AND rowid IN (SELECT rowid FROM clips_fts WHERE clips_fts MATCH ?)"
            arguments.append(query)
        }
        if pinnedOnly { sql += " AND pinned=1" }
        if let collection {
            sql += " AND collection=?"
            arguments.append(collection)
        }
        if let kind {
            sql += " AND kind=?"
            arguments.append(kind.rawValue)
        }
        sql += " ORDER BY pinned DESC, created_at DESC LIMIT 500;"

        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (index, value) in arguments.enumerated() {
            bind(value, to: Int32(index + 1), in: stmt)
        }

        var found: [ClipItem] = []
        while true {
            let status = sqlite3_step(stmt)
            if status == SQLITE_DONE { break }
            guard status == SQLITE_ROW else {
                throw ClipboardStoreError.database(String(cString: sqlite3_errmsg(database)))
            }
            guard let id = columnText(stmt, 0),
                  let rawKind = columnText(stmt, 1),
                  let kind = ClipKind(rawValue: rawKind),
                  let preview = columnText(stmt, 2),
                  let source = columnText(stmt, 6),
                  let fingerprint = columnText(stmt, 9)
            else { continue }
            found.append(ClipItem(
                id: id,
                kind: kind,
                preview: preview,
                body: columnText(stmt, 3),
                assetFilename: columnText(stmt, 4),
                filePath: columnText(stmt, 5),
                sourceApp: source,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7)),
                pinned: sqlite3_column_int(stmt, 8) != 0,
                fingerprint: fingerprint,
                collection: columnText(stmt, 10)
            ))
        }
        return found
    }

    func collectionNames() throws -> [String] {
        let stmt = try prepare("""
            SELECT DISTINCT collection FROM clips
            WHERE collection IS NOT NULL AND length(trim(collection)) > 0
            ORDER BY collection COLLATE NOCASE;
            """)
        defer { sqlite3_finalize(stmt) }
        var names: [String] = []
        while true {
            let status = sqlite3_step(stmt)
            if status == SQLITE_DONE { return names }
            guard status == SQLITE_ROW else {
                throw ClipboardStoreError.database(String(cString: sqlite3_errmsg(database)))
            }
            if let name = columnText(stmt, 0) { names.append(name) }
        }
    }

    func setCollection(_ name: String?, id: String) throws {
        let cleaned = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (cleaned?.count ?? 0) <= 60 else {
            throw ClipboardStoreError.database("Collection name must be 60 characters or fewer.")
        }
        let stmt = try prepare("UPDATE clips SET collection=? WHERE id=?;")
        defer { sqlite3_finalize(stmt) }
        bind(cleaned?.isEmpty == true ? nil : cleaned, to: 1, in: stmt)
        bind(id, to: 2, in: stmt)
        try stepDone(stmt)
    }

    func setPinned(_ pinned: Bool, id: String) throws {
        let stmt = try prepare("UPDATE clips SET pinned=? WHERE id=?;")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, pinned ? 1 : 0)
        bind(id, to: 2, in: stmt)
        try stepDone(stmt)
    }

    func delete(id: String) throws {
        let stmt = try prepare("DELETE FROM clips WHERE id=?;")
        defer { sqlite3_finalize(stmt) }
        bind(id, to: 1, in: stmt)
        try stepDone(stmt)
        try removeUnreferencedAssets()
    }

    func clearAll() throws {
        try execute("DELETE FROM clips;")
        try removeUnreferencedAssets()
        // Reclaim freed SQLite pages and rotate/truncate the current WAL.
        // SSD wear leveling, system snapshots and backups are outside our control.
        try execute("VACUUM;")
        try execute("PRAGMA wal_checkpoint(TRUNCATE);")
    }

    func assetURL(for item: ClipItem) -> URL? {
        guard let filename = item.assetFilename,
              filename.range(of: #"^[a-f0-9]{64}\.png$"#, options: .regularExpression) != nil
        else { return nil }
        return assetsDirectory.appendingPathComponent(filename)
    }

    func prune(maxUnpinnedImageBytes: Int64 = 512 * 1024 * 1024) throws {
        // Pinned clips are never removed by the retention policy.
        let expiry = Date().addingTimeInterval(
            -Double(ClipboardPreferences.retentionDays) * 86_400
        ).timeIntervalSince1970
        let expired = try prepare("DELETE FROM clips WHERE pinned=0 AND created_at < ?;")
        sqlite3_bind_double(expired, 1, expiry)
        do { try stepDone(expired) } catch { sqlite3_finalize(expired); throw error }
        sqlite3_finalize(expired)

        let capped = try prepare("""
            DELETE FROM clips WHERE pinned=0 AND id NOT IN (
                SELECT id FROM clips WHERE pinned=0 ORDER BY created_at DESC LIMIT ?
            );
            """)
        sqlite3_bind_int(capped, 1, Int32(ClipboardPreferences.retentionCount))
        do { try stepDone(capped) } catch { sqlite3_finalize(capped); throw error }
        sqlite3_finalize(capped)

        try trimImageAssets(to: maxUnpinnedImageBytes)
        try removeUnreferencedAssets()
    }

    private func trimImageAssets(to limit: Int64) throws {
        var candidates: [(id: String, bytes: Int64)] = []
        var totalBytes: Int64 = 0
        do {
            let stmt = try prepare("""
                SELECT id, asset_filename FROM clips
                WHERE pinned=0 AND asset_filename IS NOT NULL
                ORDER BY created_at ASC;
                """)
            defer { sqlite3_finalize(stmt) }
            while true {
                let status = sqlite3_step(stmt)
                if status == SQLITE_DONE { break }
                guard status == SQLITE_ROW else {
                    throw ClipboardStoreError.database(String(cString: sqlite3_errmsg(database)))
                }
                guard let id = columnText(stmt, 0),
                      let filename = columnText(stmt, 1),
                      filename.range(
                          of: #"^[a-f0-9]{64}\.png$"#, options: .regularExpression
                      ) != nil else { continue }
                let url = assetsDirectory.appendingPathComponent(filename)
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let bytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
                totalBytes += bytes
                candidates.append((id: id, bytes: bytes))
            }
        }
        guard totalBytes > limit else { return }
        // Remove the oldest unpinned images until back under budget.
        let stmt = try prepare("DELETE FROM clips WHERE id=? AND pinned=0;")
        defer { sqlite3_finalize(stmt) }
        for item in candidates where totalBytes > limit {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            bind(item.id, to: 1, in: stmt)
            try stepDone(stmt)
            totalBytes -= item.bytes
        }
    }

    private func removeUnreferencedAssets() throws {
        let stmt = try prepare("SELECT asset_filename FROM clips WHERE asset_filename IS NOT NULL;")
        defer { sqlite3_finalize(stmt) }
        var active = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let filename = columnText(stmt, 0) { active.insert(filename) }
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: assetsDirectory, includingPropertiesForKeys: nil
        )
        for url in files where url.pathExtension.lowercased() == "png" && !active.contains(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func hasColumn(named name: String, in table: String) throws -> Bool {
        // The table identifier is a fixed string defined in application code.
        let stmt = try prepare("PRAGMA table_info(\(table));")
        defer { sqlite3_finalize(stmt) }
        while true {
            let status = sqlite3_step(stmt)
            if status == SQLITE_DONE { return false }
            guard status == SQLITE_ROW else {
                throw ClipboardStoreError.database(String(cString: sqlite3_errmsg(database)))
            }
            if columnText(stmt, 1) == name { return true }
        }
    }

    private func schemaVersion() throws -> Int32 {
        let stmt = try prepare("PRAGMA user_version;")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw ClipboardStoreError.database("Unable to read schema version")
        }
        return sqlite3_column_int(stmt, 0)
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
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ClipboardStoreError.database(String(cString: sqlite3_errmsg(database)))
        }
        return stmt
    }

    private func bind(_ value: String?, to index: Int32, in stmt: OpaquePointer) {
        guard let value else {
            sqlite3_bind_null(stmt, index)
            return
        }
        sqlite3_bind_text(stmt, index, value, -1, transient)
    }

    private func columnText(_ stmt: OpaquePointer, _ index: Int32) -> String? {
        guard let raw = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: UnsafeRawPointer(raw).assumingMemoryBound(to: CChar.self))
    }

    private func stepDone(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ClipboardStoreError.database(String(cString: sqlite3_errmsg(database)))
        }
    }
}
