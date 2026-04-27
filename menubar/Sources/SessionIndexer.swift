import Foundation

/// Scans the given projects directory and batch-upserts parsed sessions into the store.
extension SessionStore {
    func indexAll(projectsDir: String) throws {
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: projectsDir)

        guard
            let projectDirs = try? fm.contentsOfDirectory(
                at: projectsURL, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { return }

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
                let fileSessionID = file.deletingPathExtension().lastPathComponent
                guard !fileSessionID.contains("#") else { continue }

                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                    let mtime = attrs.contentModificationDate?.timeIntervalSince1970
                else { continue }

                // Skip parsing if file hasn't changed since last index
                if let existing = existingMtimes[fileSessionID], existing == mtime {
                    seenIDs.insert(fileSessionID)
                    continue
                }

                guard let parsed = try? JSONLParser.parse(fileAt: file) else {
                    NSLog("SessionSearch: failed to parse %@", file.lastPathComponent)
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
        batchUpsert(pending: items, seenIDs: seenIDs)
    }
}
