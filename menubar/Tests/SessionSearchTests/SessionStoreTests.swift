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
}
