import Foundation

enum DiagnosticsReport {
    struct ProjectsDirectorySnapshot {
        let path: String
        let exists: Bool
        let jsonlFileCount: Int
    }

    @MainActor
    static func make(
        appVersion: String,
        buildVersion: String,
        settings: AppSettings,
        stats: IndexStats?,
        indexFailures: [IndexFailure],
        projects: ProjectsDirectorySnapshot,
        logPath: String,
        recentLog: String
    ) -> String {
        var lines = [
            "Session Search Diagnostics",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "App Version: \(appVersion) (\(buildVersion))",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Terminal: \(settings.terminalApp.rawValue)",
            "Refresh Interval: \(settings.refreshIntervalMinutes) minutes",
            "Active Flags: \(settings.activeFlags.isEmpty ? "none" : settings.activeFlags.joined(separator: " "))",
            "Projects Directory: \(projects.path)",
            "Projects Directory Exists: \(projects.exists ? "yes" : "no")",
            "Project JSONL Files: \(projects.jsonlFileCount)",
            "Log File: \(logPath)",
        ]

        if let stats {
            lines.append(contentsOf: [
                "Index Sessions: \(stats.sessionCount)",
                "Index Projects: \(stats.projectCount)",
                "Last Indexed: \(stats.lastIndexedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "never")",
                "Last Scan Files: \(stats.scannedFileCount)",
                "Last Scan Unchanged: \(stats.skippedFileCount)",
                "Last Scan Failed Parses: \(stats.failedParseCount)",
            ])
        } else {
            lines.append("Index Stats: unavailable")
        }

        lines.append("")
        lines.append("Index Failures:")
        lines.append(indexFailuresReport(indexFailures))
        lines.append("")
        lines.append("Recent Log:")
        lines.append(recentLog.isEmpty ? "(empty)" : recentLog)
        return lines.joined(separator: "\n")
    }

    static func indexFailuresReport(_ failures: [IndexFailure]) -> String {
        guard !failures.isEmpty else { return "(none)" }

        let formatter = ISO8601DateFormatter()
        return failures.map { failure in
            [
                "- \(failure.path)",
                "  Failed At: \(formatter.string(from: failure.failedAt))",
                "  Error: \(failure.error)",
            ].joined(separator: "\n")
        }.joined(separator: "\n")
    }

    static func projectsSnapshot(path: String) -> ProjectsDirectorySnapshot {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        guard exists, let enumerator = fm.enumerator(atPath: path) else {
            return ProjectsDirectorySnapshot(path: path, exists: exists, jsonlFileCount: 0)
        }

        var count = 0
        for case let file as String in enumerator where file.hasSuffix(".jsonl") {
            count += 1
        }
        return ProjectsDirectorySnapshot(path: path, exists: exists, jsonlFileCount: count)
    }

    static func recentLog(from url: URL, maxLines: Int = 40) -> String {
        guard let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8)
        else { return "" }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.suffix(maxLines).joined(separator: "\n")
    }
}
