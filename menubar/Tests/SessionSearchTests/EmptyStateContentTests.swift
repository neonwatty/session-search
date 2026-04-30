import XCTest

@testable import SessionSearch

final class EmptyStateContentTests: XCTestCase {
    func testMissingProjectsFolder() {
        let content = EmptyStateContent.make(
            projects: .init(path: "/tmp/missing-projects", exists: false, jsonlFileCount: 0),
            stats: nil,
            isIndexing: false,
            errorMessage: nil
        )

        XCTAssertEqual(content.title, "Claude projects folder not found")
        XCTAssertTrue(content.detail.contains("/tmp/missing-projects"))
        XCTAssertEqual(content.rows.first?.value, "Missing")
        XCTAssertTrue(content.rows.first?.isWarning ?? false)
    }

    func testEmptyProjectsFolder() {
        let content = EmptyStateContent.make(
            projects: .init(path: "/tmp/projects", exists: true, jsonlFileCount: 0),
            stats: nil,
            isIndexing: false,
            errorMessage: nil
        )

        XCTAssertEqual(content.title, "No Claude session files found")
        XCTAssertTrue(content.detail.contains("does not contain any JSONL"))
        XCTAssertEqual(content.rows[1].value, "0 JSONL")
        XCTAssertTrue(content.rows[1].isWarning)
    }

    func testParseFailureWithNoIndexedSessions() {
        let stats = IndexStats(
            sessionCount: 0,
            projectCount: 0,
            lastIndexedAt: Date(timeIntervalSince1970: 1_772_000_000),
            scannedFileCount: 3,
            skippedFileCount: 0,
            failedParseCount: 3
        )

        let content = EmptyStateContent.make(
            projects: .init(path: "/tmp/projects", exists: true, jsonlFileCount: 3),
            stats: stats,
            isIndexing: false,
            errorMessage: nil
        )

        XCTAssertEqual(content.title, "Session files could not be indexed")
        XCTAssertEqual(content.rows[3].value, "3")
        XCTAssertTrue(content.rows[3].isWarning)
    }

    func testIndexingStateTakesPriority() {
        let content = EmptyStateContent.make(
            projects: .init(path: "/tmp/projects", exists: false, jsonlFileCount: 0),
            stats: nil,
            isIndexing: true,
            errorMessage: "Could not read the local index."
        )

        XCTAssertEqual(content.title, "Indexing sessions")
        XCTAssertTrue(content.detail.contains("/tmp/projects"))
    }
}
