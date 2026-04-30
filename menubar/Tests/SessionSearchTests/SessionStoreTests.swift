import XCTest

@testable import SessionSearch

final class SessionStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: SessionStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = try! SessionStore(dbPath: tempDir.appendingPathComponent("test.db").path)
    }

    override func tearDown() {
        store = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testUpsertAndSearch() throws {
        let parsed = ParsedSession(
            sessionID: "sess-001",
            cwd: "/Users/test/Desktop",
            firstTimestamp: Date(timeIntervalSince1970: 1000),
            lastTimestamp: Date(timeIntervalSince1970: 2000),
            messageCount: 5,
            content: "Setting up Playwright for browser testing across repos"
        )
        try store.upsert(parsed: parsed, project: "my-project", projectPath: "/projects/my-project", fileMtime: 100.0)

        let results = try store.search(query: "playwright")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "sess-001")
        XCTAssertEqual(results[0].project, "my-project")
        XCTAssertTrue(results[0].snippet.lowercased().contains("playwright"))
    }

    func testSearchNoResults() throws {
        let results = try store.search(query: "nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testUpsertOverwrites() throws {
        let v1 = ParsedSession(
            sessionID: "sess-001", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "old content about React"
        )
        try store.upsert(parsed: v1, project: "proj", projectPath: "/proj", fileMtime: 100.0)

        let v2 = ParsedSession(
            sessionID: "sess-001", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 2, content: "new content about Playwright"
        )
        try store.upsert(parsed: v2, project: "proj", projectPath: "/proj", fileMtime: 200.0)

        XCTAssertTrue(try store.search(query: "react").isEmpty)
        XCTAssertEqual(try store.search(query: "playwright").count, 1)
    }

    func testGetMtime() throws {
        let parsed = ParsedSession(
            sessionID: "sess-001", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "test"
        )
        try store.upsert(parsed: parsed, project: "p", projectPath: "/p", fileMtime: 42.5)
        XCTAssertEqual(try store.getMtime(sessionID: "sess-001"), 42.5)
        XCTAssertNil(try store.getMtime(sessionID: "nonexistent"))
    }

    func testStats() throws {
        let p1 = ParsedSession(
            sessionID: "s1", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(), messageCount: 1, content: "a")
        let p2 = ParsedSession(
            sessionID: "s2", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(), messageCount: 1, content: "b")
        try store.upsert(parsed: p1, project: "proj-a", projectPath: "/a", fileMtime: 1)
        try store.upsert(parsed: p2, project: "proj-b", projectPath: "/b", fileMtime: 2)

        let stats = try store.stats()
        XCTAssertEqual(stats.sessionCount, 2)
        XCTAssertEqual(stats.projectCount, 2)
        XCTAssertNil(stats.lastIndexedAt)
    }

    func testProjectsReturnsSortedProjects() throws {
        let p1 = ParsedSession(
            sessionID: "s1", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(), messageCount: 1, content: "a")
        let p2 = ParsedSession(
            sessionID: "s2", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(), messageCount: 1, content: "b")
        try store.upsert(parsed: p1, project: "z-project", projectPath: "/z", fileMtime: 1)
        try store.upsert(parsed: p2, project: "a-project", projectPath: "/a", fileMtime: 2)

        XCTAssertEqual(try store.projects(), ["a-project", "z-project"])
    }

    func testIndexAllScansDirectory() throws {
        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("-test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let fixtureURL = Bundle(for: type(of: self))
            .url(forResource: "sample-session", withExtension: "jsonl")!
        let destURL = projectDir.appendingPathComponent("de951b93-ec97-4566-bad9-54f683846d06.jsonl")
        try FileManager.default.copyItem(at: fixtureURL, to: destURL)

        try store.indexAll(projectsDir: projectsDir.path)

        let results = try store.search(query: "playwright")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].project, "-test-project")
    }

    func testIndexAllSkipsUnchangedFiles() throws {
        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("-test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let fixtureURL = Bundle(for: type(of: self))
            .url(forResource: "sample-session", withExtension: "jsonl")!
        let destURL = projectDir.appendingPathComponent("sess-skip.jsonl")
        try FileManager.default.copyItem(at: fixtureURL, to: destURL)

        try store.indexAll(projectsDir: projectsDir.path)
        try store.indexAll(projectsDir: projectsDir.path)

        let results = try store.search(query: "playwright")
        XCTAssertEqual(results.count, 1)
    }

    func testRemoveSession() throws {
        let parsed = ParsedSession(
            sessionID: "sess-rm", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "removable content"
        )
        try store.upsert(parsed: parsed, project: "proj", projectPath: "/proj", fileMtime: 1.0)
        XCTAssertEqual(try store.search(query: "removable").count, 1)

        store.removeSession(id: "sess-rm")
        XCTAssertTrue(try store.search(query: "removable").isEmpty)
        XCTAssertEqual(try store.stats().sessionCount, 0)
    }

    func testGetAllMtimes() throws {
        let p1 = ParsedSession(
            sessionID: "s1", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "a"
        )
        let p2 = ParsedSession(
            sessionID: "s2", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "b"
        )
        try store.upsert(parsed: p1, project: "proj", projectPath: "/p", fileMtime: 10.0)
        try store.upsert(parsed: p2, project: "proj", projectPath: "/p", fileMtime: 20.0)

        let mtimes = try store.getAllMtimes()
        XCTAssertEqual(mtimes["s1"], 10.0)
        XCTAssertEqual(mtimes["s2"], 20.0)
        XCTAssertNil(mtimes["nonexistent"])
    }

    func testSearchReturnsCwd() throws {
        let parsed = ParsedSession(
            sessionID: "sess-cwd", cwd: "/Users/test/my project",
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "cwd test content"
        )
        try store.upsert(parsed: parsed, project: "proj", projectPath: "/proj", fileMtime: 1.0)

        let results = try store.search(query: "cwd test")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].cwd, "/Users/test/my project")
    }

    func testBatchPruneStale() throws {
        let p1 = ParsedSession(
            sessionID: "keep-me", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "keeper"
        )
        let p2 = ParsedSession(
            sessionID: "remove-me", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "stale session"
        )
        try store.upsert(parsed: p1, project: "proj", projectPath: "/p", fileMtime: 1.0)
        try store.upsert(parsed: p2, project: "proj", projectPath: "/p", fileMtime: 2.0)

        // batchUpsert with seenIDs only containing "keep-me" should prune "remove-me"
        store.batchUpsert(pending: [], seenIDs: Set(["keep-me"]))

        XCTAssertEqual(try store.stats().sessionCount, 1)
        XCTAssertEqual(try store.search(query: "keeper").count, 1)
        XCTAssertTrue(try store.search(query: "stale").isEmpty)
    }

    func testIndexAllPrunesWhenProjectsDirectoryIsEmpty() throws {
        let parsed = ParsedSession(
            sessionID: "stale-session", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "stale content"
        )
        try store.upsert(parsed: parsed, project: "proj", projectPath: "/p", fileMtime: 1.0)

        let projectsDir = tempDir.appendingPathComponent("projects")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        try store.indexAll(projectsDir: projectsDir.path)

        XCTAssertEqual(try store.stats().sessionCount, 0)
        XCTAssertTrue(try store.search(query: "stale").isEmpty)
    }

    func testIndexAllPrunesWhenProjectsDirectoryIsMissing() throws {
        let parsed = ParsedSession(
            sessionID: "stale-session", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "stale content"
        )
        try store.upsert(parsed: parsed, project: "proj", projectPath: "/p", fileMtime: 1.0)

        let projectsDir = tempDir.appendingPathComponent("missing-projects")

        try store.indexAll(projectsDir: projectsDir.path)

        XCTAssertEqual(try store.stats().sessionCount, 0)
        XCTAssertTrue(try store.search(query: "stale").isEmpty)
    }

    func testIndexAllKeepsExistingSessionWhenFileTemporarilyFailsToParse() throws {
        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("-test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let fixtureURL = Bundle(for: type(of: self))
            .url(forResource: "sample-session", withExtension: "jsonl")!
        let destURL = projectDir.appendingPathComponent("de951b93-ec97-4566-bad9-54f683846d06.jsonl")
        try FileManager.default.copyItem(at: fixtureURL, to: destURL)

        try store.indexAll(projectsDir: projectsDir.path)
        XCTAssertEqual(try store.search(query: "playwright").count, 1)

        try "{invalid json\n{also broken".write(to: destURL, atomically: true, encoding: .utf8)
        try store.indexAll(projectsDir: projectsDir.path)

        XCTAssertEqual(try store.stats().sessionCount, 1)
        XCTAssertEqual(try store.search(query: "playwright").count, 1)
    }

    func testIndexAllRetriesRecentlyModifiedFileThatBecomesValid() throws {
        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("-test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let destURL = projectDir.appendingPathComponent("retry-session.jsonl")
        try "{invalid json".write(to: destURL, atomically: true, encoding: .utf8)

        let validJSONL = """
            {"type":"user","message":{"role":"user","content":"eventual consistency search term"},"timestamp":"2026-04-23T22:46:10Z","sessionId":"retry-session","cwd":"/tmp/retry"}
            """

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            try? validJSONL.write(to: destURL, atomically: true, encoding: .utf8)
        }

        try store.indexAll(projectsDir: projectsDir.path)

        XCTAssertEqual(try store.search(query: "eventual consistency").map(\.id), ["retry-session"])
    }

    func testIndexAllPostsChangeNotification() throws {
        let projectsDir = tempDir.appendingPathComponent("projects")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let expectation = expectation(forNotification: .sessionSearchIndexDidChange, object: nil)

        try store.indexAll(projectsDir: projectsDir.path)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(try store.stats().lastIndexedAt)
    }

    // MARK: - FTS Query Sanitization

    func testSanitizePreservesNormalText() {
        XCTAssertEqual(SessionStore.sanitizeFTSQuery("hello world"), "hello world")
    }

    func testSanitizeStripsStars() {
        XCTAssertEqual(SessionStore.sanitizeFTSQuery("test*"), "test")
    }

    func testSanitizeStripsPipe() {
        XCTAssertEqual(SessionStore.sanitizeFTSQuery("a | b"), "a  b")
    }

    func testSanitizeStripsParens() {
        XCTAssertEqual(SessionStore.sanitizeFTSQuery("(foo)"), "foo")
    }

    func testSanitizeDoublesQuotes() {
        XCTAssertEqual(SessionStore.sanitizeFTSQuery("say \"hi\""), "say \"\"hi\"\"")
    }

    func testSanitizeLoneStar() {
        XCTAssertEqual(SessionStore.sanitizeFTSQuery("*"), "")
    }

    func testSanitizePreservesHyphens() {
        XCTAssertEqual(SessionStore.sanitizeFTSQuery("normal-query"), "normal-query")
    }

    func testMakeFTSQueryUsesAllTermsWithPrefixMatching() {
        XCTAssertEqual(SessionStore.makeFTSQuery("browser automation"), "\"browser\"* \"automation\"*")
    }

    func testMakeFTSQueryIgnoresSpecialCharacterOnlyInput() {
        XCTAssertNil(SessionStore.makeFTSQuery("* | ()"))
    }

    func testSearchMultiWordTermsNeedNotBeAdjacent() throws {
        let parsed = ParsedSession(
            sessionID: "sess-multi", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "browser setup with several words before automation"
        )
        try store.upsert(parsed: parsed, project: "proj", projectPath: "/proj", fileMtime: 1)

        let results = try store.search(query: "browser automation")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "sess-multi")
    }

    func testSearchSpecialCharacterOnlyInputReturnsNoResults() throws {
        let parsed = ParsedSession(
            sessionID: "sess-special", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "content"
        )
        try store.upsert(parsed: parsed, project: "proj", projectPath: "/proj", fileMtime: 1)

        XCTAssertTrue(try store.search(query: "* | ()").isEmpty)
    }

    func testSearchCanFilterByProject() throws {
        let p1 = ParsedSession(
            sessionID: "project-a", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "shared search term"
        )
        let p2 = ParsedSession(
            sessionID: "project-b", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "shared search term"
        )
        try store.upsert(parsed: p1, project: "a-project", projectPath: "/a", fileMtime: 1)
        try store.upsert(parsed: p2, project: "b-project", projectPath: "/b", fileMtime: 2)

        let results = try store.search(query: "shared", project: "b-project")

        XCTAssertEqual(results.map(\.id), ["project-b"])
    }

    func testSearchCanFilterByDate() throws {
        let recent = ParsedSession(
            sessionID: "recent", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "temporal search term"
        )
        let old = ParsedSession(
            sessionID: "old", cwd: nil,
            firstTimestamp: Date(timeIntervalSinceNow: -40 * 24 * 60 * 60),
            lastTimestamp: Date(timeIntervalSinceNow: -40 * 24 * 60 * 60),
            messageCount: 1, content: "temporal search term"
        )
        try store.upsert(parsed: recent, project: "proj", projectPath: "/recent", fileMtime: 1)
        try store.upsert(parsed: old, project: "proj", projectPath: "/old", fileMtime: 2)

        let results = try store.search(query: "temporal", dateFilter: .month)

        XCTAssertEqual(results.map(\.id), ["recent"])
    }

    func testSearchIndexesProjectPathAndSessionIDMetadata() throws {
        let parsed = ParsedSession(
            sessionID: "metadata-session-123", cwd: "/Users/test/worktree",
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "ordinary content"
        )
        try store.upsert(
            parsed: parsed, project: "-Users-test-Desktop-session-search",
            projectPath: "/Users/test/Desktop/session-search", fileMtime: 1)

        XCTAssertEqual(try store.search(query: "metadata-session").map(\.id), ["metadata-session-123"])
        XCTAssertEqual(try store.search(query: "session-search").map(\.id), ["metadata-session-123"])
        XCTAssertEqual(try store.search(query: "worktree").map(\.id), ["metadata-session-123"])
    }

    // MARK: - Integration Tests

    func testIndexAllSearchContentCorrectness() throws {
        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("-test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let fixtureURL = Bundle(for: type(of: self))
            .url(forResource: "sample-session", withExtension: "jsonl")!
        let destURL = projectDir.appendingPathComponent("de951b93-ec97-4566-bad9-54f683846d06.jsonl")
        try FileManager.default.copyItem(at: fixtureURL, to: destURL)

        try store.indexAll(projectsDir: projectsDir.path)

        let results = try store.search(query: "browser automation")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].project, "-test-project")
        XCTAssertTrue(results[0].lastTimestamp.timeIntervalSince1970 > 0)
        XCTAssertTrue(
            results[0].snippet.lowercased().contains("browser")
                || results[0].snippet.lowercased().contains("automation"))
    }

    func testIndexAllContinuesAfterMalformedFile() throws {
        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("-test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Valid file
        let fixtureURL = Bundle(for: type(of: self))
            .url(forResource: "sample-session", withExtension: "jsonl")!
        let validDest = projectDir.appendingPathComponent("de951b93-ec97-4566-bad9-54f683846d06.jsonl")
        try FileManager.default.copyItem(at: fixtureURL, to: validDest)

        // Malformed file
        let badDest = projectDir.appendingPathComponent("bad-session.jsonl")
        try "{invalid json\n{also broken".write(to: badDest, atomically: true, encoding: .utf8)

        // Should not throw — malformed file is skipped
        try store.indexAll(projectsDir: projectsDir.path)

        let results = try store.search(query: "playwright")
        XCTAssertEqual(results.count, 1, "Valid session should be indexed despite malformed sibling")
    }
}
