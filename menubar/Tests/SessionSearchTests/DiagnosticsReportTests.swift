import XCTest

@testable import SessionSearch

@MainActor
final class DiagnosticsReportTests: XCTestCase {
    func testReportIncludesCoreFields() {
        let settings = AppSettings(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        settings.terminalApp = .ghostty
        settings.refreshIntervalMinutes = 15
        settings.flagPresets = [FlagPreset(flag: "--verbose", enabled: true)]

        let stats = IndexStats(
            sessionCount: 4,
            projectCount: 2,
            lastIndexedAt: Date(timeIntervalSince1970: 1_772_000_000),
            scannedFileCount: 8,
            skippedFileCount: 3,
            failedParseCount: 1
        )

        let report = DiagnosticsReport.make(
            appVersion: "1.2.3",
            buildVersion: "45",
            settings: settings,
            stats: stats,
            indexFailures: [
                IndexFailure(
                    path: "/tmp/projects/bad.jsonl",
                    error: "bad JSON",
                    failedAt: Date(timeIntervalSince1970: 1_772_000_001)
                )
            ],
            projects: .init(path: "/tmp/projects", exists: true, jsonlFileCount: 9),
            logPath: "/tmp/session-search.log",
            recentLog: "recent log line"
        )

        XCTAssertTrue(report.contains("App Version: 1.2.3 (45)"))
        XCTAssertTrue(report.contains("Terminal: Ghostty"))
        XCTAssertTrue(report.contains("Refresh Interval: 15 minutes"))
        XCTAssertTrue(report.contains("Active Flags: --verbose"))
        XCTAssertTrue(report.contains("Projects Directory Exists: yes"))
        XCTAssertTrue(report.contains("Project JSONL Files: 9"))
        XCTAssertTrue(report.contains("Index Sessions: 4"))
        XCTAssertTrue(report.contains("Last Scan Failed Parses: 1"))
        XCTAssertTrue(report.contains("/tmp/projects/bad.jsonl"))
        XCTAssertTrue(report.contains("bad JSON"))
        XCTAssertTrue(report.contains("recent log line"))
    }

    func testRecentLogReturnsTail() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "one\ntwo\nthree".write(to: url, atomically: true, encoding: .utf8)

        XCTAssertEqual(DiagnosticsReport.recentLog(from: url, maxLines: 2), "two\nthree")
    }
}
