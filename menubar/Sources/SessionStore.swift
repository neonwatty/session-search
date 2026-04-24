import Foundation
import SQLite3

struct IndexStats {
    let sessionCount: Int
    let projectCount: Int
}

final class SessionStore {
    private var db: OpaquePointer?

    init(dbPath: String) throws {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw StoreError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        try createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

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
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Upsert

    func upsert(parsed: ParsedSession, project: String, projectPath: String, fileMtime: Double) throws {
        try exec("DELETE FROM session_content WHERE session_id = ?", bind: [.text(parsed.sessionID)])
        try exec("DELETE FROM sessions WHERE id = ?", bind: [.text(parsed.sessionID)])

        try exec("""
            INSERT INTO sessions (id, project, project_path, session_name, first_timestamp, last_timestamp, cwd, message_count, file_mtime)
            VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?)
            """, bind: [
                .text(parsed.sessionID),
                .text(project),
                .text(projectPath),
                .double(parsed.firstTimestamp.timeIntervalSince1970),
                .double(parsed.lastTimestamp.timeIntervalSince1970),
                .optionalText(parsed.cwd),
                .int(parsed.messageCount),
                .double(fileMtime),
            ])

        try exec("""
            INSERT INTO session_content (session_id, content) VALUES (?, ?)
            """, bind: [.text(parsed.sessionID), .text(parsed.content)])
    }

    // MARK: - Query

    func search(query: String, limit: Int = 20) throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let sanitized = query.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsQuery = "\"\(sanitized)\"*"

        let sql = """
            SELECT s.id, s.project, s.project_path, s.session_name, s.last_timestamp,
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

        sqlite3_bind_text(stmt, 1, ftsQuery, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let project = String(cString: sqlite3_column_text(stmt, 1))
            let projectPath = String(cString: sqlite3_column_text(stmt, 2))
            let sessionName: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL
                ? nil : String(cString: sqlite3_column_text(stmt, 3))
            let lastTs = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            let snippet = String(cString: sqlite3_column_text(stmt, 5))
            let rank = sqlite3_column_double(stmt, 6)

            results.append(SearchResult(
                id: id, project: project, projectPath: projectPath,
                sessionName: sessionName, lastTimestamp: lastTs,
                snippet: snippet, rank: rank
            ))
        }
        return results
    }

    // MARK: - Mtime check

    func getMtime(sessionID: String) throws -> Double? {
        let sql = "SELECT file_mtime FROM sessions WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_double(stmt, 0)
        }
        return nil
    }

    // MARK: - Stats

    func stats() throws -> IndexStats {
        var sessionCount = 0
        var projectCount = 0

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM sessions", -1, &stmt, nil)
        if sqlite3_step(stmt) == SQLITE_ROW { sessionCount = Int(sqlite3_column_int(stmt, 0)) }
        sqlite3_finalize(stmt)

        sqlite3_prepare_v2(db, "SELECT COUNT(DISTINCT project) FROM sessions", -1, &stmt, nil)
        if sqlite3_step(stmt) == SQLITE_ROW { projectCount = Int(sqlite3_column_int(stmt, 0)) }
        sqlite3_finalize(stmt)

        return IndexStats(sessionCount: sessionCount, projectCount: projectCount)
    }

    // MARK: - Full index

    func indexAll(projectsDir: String) throws {
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: projectsDir)

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsURL, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let project = projectDir.lastPathComponent

            guard let files = try? fm.contentsOfDirectory(
                at: projectDir, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                let sessionID = file.deletingPathExtension().lastPathComponent
                // Skip agent sub-sessions (contain #)
                guard !sessionID.contains("#") else { continue }

                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let mtime = attrs.contentModificationDate?.timeIntervalSince1970 else { continue }

                if let existing = try? getMtime(sessionID: sessionID), existing == mtime {
                    continue
                }

                guard let parsed = try? JSONLParser.parse(fileAt: file) else { continue }
                try upsert(parsed: parsed, project: project, projectPath: projectDir.path, fileMtime: mtime)
            }
        }
    }

    // MARK: - Helpers

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
                sqlite3_bind_text(stmt, idx, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .optionalText(let s):
                if let s {
                    sqlite3_bind_text(stmt, idx, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
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
