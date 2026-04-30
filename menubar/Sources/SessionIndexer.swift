import Foundation

/// Scans the given projects directory and batch-upserts parsed sessions into the store.
extension SessionStore {
    func indexAll(projectsDir: String) throws {
        try indexAll(
            projectsDir: projectsDir,
            parseFile: JSONLParser.parse(fileAt:),
            retrySleep: Thread.sleep(forTimeInterval:)
        )
    }

    func indexAll(
        projectsDir: String,
        parseFile: (URL) throws -> ParsedSession,
        retrySleep: (TimeInterval) -> Void
    ) throws {
        NotificationCenter.default.post(name: .sessionSearchIndexDidStart, object: nil)
        defer {
            NotificationCenter.default.post(name: .sessionSearchIndexDidChange, object: nil)
        }
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: projectsDir)

        if !fm.fileExists(atPath: projectsURL.path) {
            batchUpsert(pending: [], seenIDs: [], runStats: .empty)
            return
        }

        let projectDirs = try fm.contentsOfDirectory(
            at: projectsURL, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        // Bulk-fetch existing mtimes to skip unchanged files before parsing
        let existingMtimes = (try? getAllMtimes()) ?? [:]

        struct PendingSession {
            let parsed: ParsedSession
            let project: String
            let projectPath: String
            let fileMtime: Double
        }
        var pending: [PendingSession] = []
        var seenIDs: Set<String> = []
        var scannedFileCount = 0
        var skippedFileCount = 0
        var failedParseCount = 0
        var indexFailures: [IndexFailure] = []

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let project = projectDir.lastPathComponent

            guard
                let files = try? fm.contentsOfDirectory(
                    at: projectDir, includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            for file in files where file.pathExtension == "jsonl" {
                scannedFileCount += 1
                let fileSessionID = file.deletingPathExtension().lastPathComponent
                guard !fileSessionID.contains("#") else { continue }

                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                    let mtime = attrs.contentModificationDate?.timeIntervalSince1970
                else { continue }

                // Skip parsing if file hasn't changed since last index
                if let existing = existingMtimes[fileSessionID], existing == mtime {
                    seenIDs.insert(fileSessionID)
                    skippedFileCount += 1
                    continue
                }

                let parsedResult = parseSessionFile(
                    file, fileMtime: mtime, parseFile: parseFile, retrySleep: retrySleep)
                guard case .success(let parsed) = parsedResult else {
                    failedParseCount += 1
                    if case .failure(let error) = parsedResult {
                        indexFailures.append(
                            IndexFailure(
                                path: file.path,
                                error: String(describing: error),
                                failedAt: Date()
                            ))
                    }
                    if existingMtimes[fileSessionID] != nil {
                        seenIDs.insert(fileSessionID)
                    }
                    AppLog.error("failed to parse \(file.lastPathComponent)")
                    continue
                }

                seenIDs.insert(parsed.sessionID)
                pending.append(
                    PendingSession(
                        parsed: parsed, project: project,
                        projectPath: projectDir.path, fileMtime: mtime
                    ))
            }
        }

        let items: [PendingItem] = pending.map {
            (parsed: $0.parsed, project: $0.project, projectPath: $0.projectPath, fileMtime: $0.fileMtime)
        }
        batchUpsert(
            pending: items,
            seenIDs: seenIDs,
            runStats: IndexRunStats(
                scannedFileCount: scannedFileCount,
                skippedFileCount: skippedFileCount,
                failedParseCount: failedParseCount
            ),
            indexFailures: indexFailures
        )
    }

    private func parseSessionFile(
        _ file: URL,
        fileMtime: Double,
        parseFile: (URL) throws -> ParsedSession,
        retrySleep: (TimeInterval) -> Void
    ) -> Result<ParsedSession, Error> {
        let attempts = Date().timeIntervalSince1970 - fileMtime < 5 ? 3 : 1
        var lastError: Error?

        for attempt in 1...attempts {
            do {
                return .success(try parseFile(file))
            } catch {
                lastError = error
            }

            if attempt < attempts {
                retrySleep(0.15)
            }
        }

        return .failure(lastError ?? StoreError.execFailed("Unknown parse failure"))
    }
}
