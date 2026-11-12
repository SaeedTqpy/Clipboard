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

    init() throws {
        guard let root = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { throw ClipboardStoreError.missingSupportDirectory }

        let folder = root.appendingPathComponent("Clipboard", isDirectory: true)
        assetsDirectory = folder.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

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

        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA busy_timeout=3000;")
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
                fingerprint TEXT NOT NULL UNIQUE
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
    }

    deinit { sqlite3_close(database) }

    func save(_ payload: ClipPayload, sourceApp: String) throws {
        let filename = payload.imagePNG == nil ? nil : payload.fingerprint + ".png"
        if let data = payload.imagePNG, let filename {
            try data.write(to: assetsDirectory.appendingPathComponent(filename), options: .atomic)
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
        try prune()
    }

    func items(search: String, pinnedOnly: Bool = false) throws -> [ClipItem] {
        var sql = """
            SELECT id, kind, preview, body, asset_filename, file_path,
                   source_app, created_at, pinned, fingerprint
            FROM clips WHERE 1=1
            """
        let terms = search.split(whereSeparator: { $0.isWhitespace })
        let query = terms.map {
            "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"*"
        }.joined(separator: " AND ")
        if !query.isEmpty {
            sql += " AND rowid IN (SELECT rowid FROM clips_fts WHERE clips_fts MATCH ?)"
        }
        if pinnedOnly { sql += " AND pinned=1" }
        sql += " ORDER BY pinned DESC, created_at DESC LIMIT 500;"

        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        if !query.isEmpty { bind(query, to: 1, in: stmt) }

        var found: [ClipItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
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
                fingerprint: fingerprint
            ))
        }
        return found
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
    }

    func assetURL(for item: ClipItem) -> URL? {
        guard let filename = item.assetFilename else { return nil }
        return assetsDirectory.appendingPathComponent(filename)
    }

    private func prune() throws {
        // Pinned clips are never removed by the retention policy.
        let expiry = Date().addingTimeInterval(-30 * 24 * 60 * 60).timeIntervalSince1970
        let stmt = try prepare("DELETE FROM clips WHERE pinned=0 AND created_at < ?;")
        sqlite3_bind_double(stmt, 1, expiry)
        do { try stepDone(stmt) } catch { sqlite3_finalize(stmt); throw error }
        sqlite3_finalize(stmt)
        try execute("""
            DELETE FROM clips WHERE pinned=0 AND id NOT IN (
                SELECT id FROM clips WHERE pinned=0 ORDER BY created_at DESC LIMIT 1000
            );
            """)
        try removeUnreferencedAssets()
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
