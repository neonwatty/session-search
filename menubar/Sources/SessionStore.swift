import Foundation
import SQLite3

let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SessionStore: @unchecked Sendable {
    var db: OpaquePointer?
    let queue = DispatchQueue(label: "com.neonwatty.SessionSearch.store")

    init(dbPath: String) throws {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw StoreError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        try enableWAL()
        try createTables()
    }

    deinit {
        sqlite3_close_v2(db)
    }

    private func enableWAL() throws {
        guard sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func createTables() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                project TEXT NOT NULL,
                project_path TEXT NOT NULL,
                session_name TEXT,
                first_timestamp REAL NOT NULL,
                last_timestamp REAL NOT NULL,
                cwd TEXT,
                message_count INTEGER NOT NULL,
                file_mtime REAL NOT NULL
            );
            CREATE VIRTUAL TABLE IF NOT EXISTS session_content USING fts5(
                session_id,
                content,
                tokenize='porter unicode61'
            );
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY,
                value REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS index_failures (
                path TEXT PRIMARY KEY,
                error TEXT NOT NULL,
                failed_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project);
            CREATE INDEX IF NOT EXISTS idx_sessions_last_ts ON sessions(last_timestamp);
            CREATE INDEX IF NOT EXISTS idx_sessions_mtime ON sessions(file_mtime);
            """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func upsert(parsed: ParsedSession, project: String, projectPath: String, fileMtime: Double) throws {
        try queue.sync {
            try _upsert(parsed: parsed, project: project, projectPath: projectPath, fileMtime: fileMtime)
        }
    }

    /// Must be called on `queue`.
    private func _upsert(parsed: ParsedSession, project: String, projectPath: String, fileMtime: Double) throws {
        try exec("BEGIN IMMEDIATE")
        do {
            try exec("DELETE FROM session_content WHERE session_id = ?", bind: [.text(parsed.sessionID)])
            try exec("DELETE FROM sessions WHERE id = ?", bind: [.text(parsed.sessionID)])
            try exec(
                """
                INSERT INTO sessions (id, project, project_path, session_name, first_timestamp, last_timestamp, cwd, message_count, file_mtime)
                VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?)
                """,
                bind: [
                    .text(parsed.sessionID), .text(project), .text(projectPath),
                    .double(parsed.firstTimestamp.timeIntervalSince1970),
                    .double(parsed.lastTimestamp.timeIntervalSince1970),
                    .optionalText(parsed.cwd), .int(parsed.messageCount), .double(fileMtime),
                ])
            try exec(
                "INSERT INTO session_content (session_id, content) VALUES (?, ?)",
                bind: [
                    .text(parsed.sessionID),
                    .text(searchableContent(parsed, project: project, projectPath: projectPath)),
                ])
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    private func searchableContent(_ parsed: ParsedSession, project: String, projectPath: String) -> String {
        [parsed.sessionID, project, projectPath, parsed.cwd, parsed.content]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    func columnText(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL,
            let ptr = sqlite3_column_text(stmt, col)
        else { return nil }
        return String(cString: ptr)
    }

    func getMtime(sessionID: String) throws -> Double? {
        try queue.sync { try _getMtime(sessionID: sessionID) }
    }

    /// Must be called on `queue`.
    private func _getMtime(sessionID: String) throws -> Double? {
        let sql = "SELECT file_mtime FROM sessions WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionID, -1, sqliteTransient)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_double(stmt, 0)
        }
        return nil
    }

    func getAllMtimes() throws -> [String: Double] {
        try queue.sync {
            let sql = "SELECT id, file_mtime FROM sessions"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            var result: [String: Double] = [:]
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) {
                    result[String(cString: ptr)] = sqlite3_column_double(stmt, 1)
                }
            }
            return result
        }
    }

    func removeSession(id: String) {
        queue.sync {
            try? exec("DELETE FROM session_content WHERE session_id = ?", bind: [.text(id)])
            try? exec("DELETE FROM sessions WHERE id = ?", bind: [.text(id)])
        }
    }

    func countQuery(_ sql: String) throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    func optionalDoubleQuery(_ sql: String) throws -> Double? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? sqlite3_column_double(stmt, 0) : nil
    }

    typealias PendingItem = (parsed: ParsedSession, project: String, projectPath: String, fileMtime: Double)

    func batchUpsert(
        pending: [PendingItem],
        seenIDs: Set<String>,
        runStats: IndexRunStats = .empty,
        indexFailures: [IndexFailure] = []
    ) {
        queue.sync {
            for item in pending {
                if let existing = try? _getMtime(sessionID: item.parsed.sessionID),
                    existing == item.fileMtime
                {
                    continue
                }
                do {
                    try _upsert(
                        parsed: item.parsed, project: item.project,
                        projectPath: item.projectPath, fileMtime: item.fileMtime)
                } catch {
                    NSLog("SessionSearch: upsert failed for %@: %@", item.parsed.sessionID, "\(error)")
                }
            }

            pruneStale(keepIDs: seenIDs)
            try? exec(
                "INSERT OR REPLACE INTO metadata (key, value) VALUES ('last_indexed_at', ?)",
                bind: [.double(Date().timeIntervalSince1970)])
            try? setMetadata("last_scanned_file_count", Double(runStats.scannedFileCount))
            try? setMetadata("last_skipped_file_count", Double(runStats.skippedFileCount))
            try? setMetadata("last_failed_parse_count", Double(runStats.failedParseCount))
            replaceIndexFailures(indexFailures)
        }
    }

    private func setMetadata(_ key: String, _ value: Double) throws {
        try exec(
            "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
            bind: [.text(key), .double(value)])
    }

    private func pruneStale(keepIDs: Set<String>) {
        do {
            guard !keepIDs.isEmpty else {
                try exec("DELETE FROM session_content")
                try exec("DELETE FROM sessions")
                return
            }

            try exec("CREATE TEMP TABLE IF NOT EXISTS keep_ids (id TEXT PRIMARY KEY)")
            try exec("DELETE FROM keep_ids")

            for id in keepIDs {
                try exec("INSERT OR IGNORE INTO keep_ids (id) VALUES (?)", bind: [.text(id)])
            }

            try exec("DELETE FROM session_content WHERE session_id NOT IN (SELECT id FROM keep_ids)")
            try exec("DELETE FROM sessions WHERE id NOT IN (SELECT id FROM keep_ids)")
            try exec("DROP TABLE IF EXISTS keep_ids")
        } catch {
            NSLog("SessionSearch: pruneStale failed: %@", "\(error)")
            try? exec("DROP TABLE IF EXISTS keep_ids")
        }
    }

    enum BindValue {
        case text(String)
        case optionalText(String?)
        case int(Int)
        case double(Double)
    }

    func exec(_ sql: String, bind: [BindValue] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        bindValues(bind, to: stmt)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func bindValues(_ bind: [BindValue], to stmt: OpaquePointer?) {
        for (i, value) in bind.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case .text(let s):
                sqlite3_bind_text(stmt, idx, s, -1, sqliteTransient)
            case .optionalText(let s):
                if let s {
                    sqlite3_bind_text(stmt, idx, s, -1, sqliteTransient)
                } else {
                    sqlite3_bind_null(stmt, idx)
                }
            case .int(let n):
                sqlite3_bind_int(stmt, idx, Int32(n))
            case .double(let d):
                sqlite3_bind_double(stmt, idx, d)
            }
        }
    }

    enum StoreError: Error {
        case openFailed(String)
        case execFailed(String)
    }
}
