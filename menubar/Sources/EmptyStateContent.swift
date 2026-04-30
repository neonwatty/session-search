struct EmptyStateContent: Equatable {
    struct Row: Equatable {
        let label: String
        let value: String
        let isWarning: Bool
    }

    let title: String
    let detail: String
    let rows: [Row]

    static func make(
        projects: DiagnosticsReport.ProjectsDirectorySnapshot,
        stats: IndexStats?,
        isIndexing: Bool,
        errorMessage: String?
    ) -> EmptyStateContent {
        let rows = [
            Row(label: "Projects folder", value: projects.exists ? "Found" : "Missing", isWarning: !projects.exists),
            Row(
                label: "Session files",
                value: "\(projects.jsonlFileCount) JSONL",
                isWarning: projects.exists && projects.jsonlFileCount == 0
            ),
            Row(label: "Indexed sessions", value: "\(stats?.sessionCount ?? 0)", isWarning: false),
            Row(
                label: "Failed parses",
                value: "\(stats?.failedParseCount ?? 0)",
                isWarning: (stats?.failedParseCount ?? 0) > 0
            ),
        ]

        if isIndexing {
            return EmptyStateContent(
                title: "Indexing sessions",
                detail: "Scanning \(projects.path)",
                rows: rows
            )
        }

        if let errorMessage {
            return EmptyStateContent(
                title: "Index status unavailable",
                detail: errorMessage,
                rows: rows
            )
        }

        if !projects.exists {
            return EmptyStateContent(
                title: "Claude projects folder not found",
                detail: "Expected transcripts at \(projects.path)",
                rows: rows
            )
        }

        if projects.jsonlFileCount == 0 {
            return EmptyStateContent(
                title: "No Claude session files found",
                detail: "The projects folder exists, but it does not contain any JSONL transcripts yet.",
                rows: rows
            )
        }

        if (stats?.failedParseCount ?? 0) > 0 && (stats?.sessionCount ?? 0) == 0 {
            return EmptyStateContent(
                title: "Session files could not be indexed",
                detail: "The last scan found JSONL files, but none produced searchable sessions.",
                rows: rows
            )
        }

        if stats?.lastIndexedAt == nil {
            return EmptyStateContent(
                title: "No index run yet",
                detail: "Run a rebuild to scan existing Claude sessions.",
                rows: rows
            )
        }

        return EmptyStateContent(
            title: "No sessions indexed yet",
            detail: "The last scan completed, but did not find searchable sessions.",
            rows: rows
        )
    }
}
