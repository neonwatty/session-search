import Foundation
import SQLite3

extension SessionStore {
    func stats() throws -> IndexStats {
        try queue.sync {
            let sessionCount = try countQuery("SELECT COUNT(*) FROM sessions")
            let projectCount = try countQuery("SELECT COUNT(DISTINCT project) FROM sessions")
            let lastIndexedAt = try optionalDoubleQuery("SELECT value FROM metadata WHERE key = 'last_indexed_at'")
                .map { Date(timeIntervalSince1970: $0) }
            return IndexStats(sessionCount: sessionCount, projectCount: projectCount, lastIndexedAt: lastIndexedAt)
        }
    }

    func projects() throws -> [String] {
        try queue.sync {
            let sql = "SELECT DISTINCT project FROM sessions ORDER BY project"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            var result: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let project = columnText(stmt, 0) {
                    result.append(project)
                }
            }
            return result
        }
    }
}
