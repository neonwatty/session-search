import Foundation
import SQLite3

extension SessionStore {
    func search(
        query: String,
        limit: Int = 20,
        project: String? = nil,
        dateFilter: SearchDateFilter = .all
    ) throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        guard let ftsQuery = Self.makeFTSQuery(trimmed) else { return [] }

        return try queue.sync {
            var whereClauses = ["session_content MATCH ?"]
            var bind: [BindValue] = [.text(ftsQuery)]
            if let project {
                whereClauses.append("s.project = ?")
                bind.append(.text(project))
            }
            if let cutoff = dateFilter.cutoffDate {
                whereClauses.append("s.last_timestamp >= ?")
                bind.append(.double(cutoff.timeIntervalSince1970))
            }
            bind.append(.int(limit))

            let sql = """
                SELECT s.id, s.project, s.project_path, s.session_name, s.cwd, s.last_timestamp,
                       snippet(session_content, 1, '<<', '>>', '...', 32) AS snip,
                       rank
                FROM session_content
                JOIN sessions s ON s.id = session_content.session_id
                WHERE \(whereClauses.joined(separator: " AND "))
                ORDER BY rank
                LIMIT ?
                """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            bindValues(bind, to: stmt)

            var results: [SearchResult] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(readSearchResult(stmt))
            }
            return results
        }
    }

    private func readSearchResult(_ stmt: OpaquePointer?) -> SearchResult {
        SearchResult(
            id: columnText(stmt, 0) ?? "",
            project: columnText(stmt, 1) ?? "",
            projectPath: columnText(stmt, 2) ?? "",
            sessionName: columnText(stmt, 3),
            cwd: columnText(stmt, 4),
            lastTimestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5)),
            snippet: columnText(stmt, 6) ?? "",
            rank: sqlite3_column_double(stmt, 7)
        )
    }
}
