import Foundation
import SQLite3

extension SessionStore {
    func indexFailures() throws -> [IndexFailure] {
        try queue.sync {
            let sql = "SELECT path, error, failed_at FROM index_failures ORDER BY path"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            var result: [IndexFailure] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let path = columnText(stmt, 0),
                    let error = columnText(stmt, 1)
                else { continue }

                result.append(
                    IndexFailure(
                        path: path,
                        error: error,
                        failedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                    ))
            }
            return result
        }
    }

    func replaceIndexFailures(_ failures: [IndexFailure]) {
        do {
            try exec("DELETE FROM index_failures")
            for failure in failures {
                try exec(
                    "INSERT OR REPLACE INTO index_failures (path, error, failed_at) VALUES (?, ?, ?)",
                    bind: [
                        .text(failure.path),
                        .text(failure.error),
                        .double(failure.failedAt.timeIntervalSince1970),
                    ])
            }
        } catch {
            NSLog("SessionSearch: storing index failures failed: %@", "\(error)")
        }
    }
}
