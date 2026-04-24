import XCTest
@testable import SessionSearch

final class JSONLParserTests: XCTestCase {
    private func fixtureURL() -> URL {
        Bundle(for: type(of: self))
            .url(forResource: "sample-session", withExtension: "jsonl")!
    }

    func testParseSessionMetadata() throws {
        let result = try JSONLParser.parse(fileAt: fixtureURL())
        XCTAssertEqual(result.sessionID, "de951b93-ec97-4566-bad9-54f683846d06")
        XCTAssertEqual(result.cwd, "/Users/neonwatty/Desktop")
        XCTAssertEqual(result.messageCount, 4) // 2 user + 2 assistant
    }

    func testParseTimestamps() throws {
        let result = try JSONLParser.parse(fileAt: fixtureURL())
        let cal = Calendar(identifier: .gregorian)
        let firstComps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: result.firstTimestamp)
        XCTAssertEqual(firstComps.hour, 22)
        XCTAssertEqual(firstComps.minute, 45)
        let lastComps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: result.lastTimestamp)
        XCTAssertEqual(lastComps.minute, 49)
    }

    func testParseContentConcatenation() throws {
        let result = try JSONLParser.parse(fileAt: fixtureURL())
        XCTAssertTrue(result.content.contains("Playwrights CLI"))
        XCTAssertTrue(result.content.contains("cross-repo browser automation"))
        XCTAssertTrue(result.content.contains("storageState"))
        // tool_use blocks should NOT be in content
        XCTAssertFalse(result.content.contains("toolu_123"))
    }

    func testParseSkipsNonMessageLines() throws {
        let result = try JSONLParser.parse(fileAt: fixtureURL())
        XCTAssertFalse(result.content.contains("trackedFileBackups"))
    }

    func testParseEmptyFile() {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).jsonl")
        FileManager.default.createFile(atPath: tempFile.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try JSONLParser.parse(fileAt: tempFile))
    }
}
