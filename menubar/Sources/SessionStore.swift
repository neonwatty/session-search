import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SessionStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.neonwatty.SessionSearch.store")

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
            try exec("""
                INSERT INTO sessions (id, project, project_path, session_name, first_timestamp, last_timestamp, cwd, message_count, file_mtime)
                VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?)
                """,
                bind: [.text(parsed.sessionID), .text(project), .text(projectPath),
                       .double(parsed.firstTimestamp.timeIntervalSince1970),
                       .double(parsed.lastTimestamp.timeIntervalSince1970),
                       .optionalText(parsed.cwd), .int(parsed.messageCount), .double(fileMtime)])
            try exec("INSERT INTO session_content (session_id, content) VALUES (?, ?)",
                     bind: [.text(parsed.sessionID), .text(parsed.content)])
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func search(query: String, limit: Int = 20) throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let sanitized = Self.sanitizeFTSQuery(trimmed)
        let ftsQuery = "\"\(sanitized)\"*"

        return try queue.sync {
            let sql = """
                SELECT s.id, s.project, s.project_path, s.session_name, s.cwd, s.last_timestamp,
                       snippet(session_content, 1, '<<', '>>', '...', 32) AS snip,
                       rank
                FROM session_content
                JOIN sessions s ON s.id = session_content.session_id
                WHERE session_content MATCH ?
                ORDER BY rank
                LIMIT ?
                """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, ftsQuery, -1, sqliteTransient)
            sqlite3_bind_int(stmt, 2, Int32(limit))

            var results: [SearchResult] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = columnText(stmt, 0) ?? ""
                let project = columnText(stmt, 1) ?? ""
                let projectPath = columnText(stmt, 2) ?? ""
                let sessionName = columnText(stmt, 3)
                let cwd = columnText(stmt, 4)
                let lastTs = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
                let snippet = columnText(stmt, 6) ?? ""
                let rank = sqlite3_column_double(stmt, 7)

                results.append(
                    SearchResult(
                        id: id, project: project, projectPath: projectPath,
                        sessionName: sessionName, cwd: cwd, lastTimestamp: lastTs,
                        snippet: snippet, rank: rank
                    ))
            }
            return results
        }
    }

    private func columnText(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL,
            let ptr = sqlite3_column_text(stmt, col)
        else { return nil }
        return String(cString: ptr)
    }

    static func sanitizeFTSQuery(_ input: String) -> String {
        var result = input.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsSpecials: [Character] = ["*", "^", "(", ")", "{", "}", "[", "]", "+", "|"]
        result.removeAll { ftsSpecials.contains($0) }
        return result
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

    func stats() throws -> IndexStats {
        try queue.sync {
            let sessionCount = try countQuery("SELECT COUNT(*) FROM sessions")
            let projectCount = try countQuery("SELECT COUNT(DISTINCT project) FROM sessions")
            return IndexStats(sessionCount: sessionCount, projectCount: projectCount)
        }
    }

    private func countQuery(_ sql: String) throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    typealias PendingItem = (parsed: ParsedSession, project: String, projectPath: String, fileMtime: Double)

    func batchUpsert(pending: [PendingItem], seenIDs: Set<String>) {
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

            if !seenIDs.isEmpty {
                pruneStale(keepIDs: seenIDs)
            }
        }
    }

    private func pruneStale(keepIDs: Set<String>) {
        guard !keepIDs.isEmpty else { return }

        do {
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

    private enum BindValue {
        case text(String)
        case optionalText(String?)
        case int(Int)
        case double(Double)
    }

    private func exec(_ sql: String, bind: [BindValue] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

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

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    enum StoreError: Error {
        case openFailed(String)
        case execFailed(String)
    }
}
