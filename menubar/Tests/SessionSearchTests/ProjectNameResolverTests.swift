import XCTest

@testable import SessionSearch

@MainActor
final class ProjectNameResolverTests: XCTestCase {
    func testExistingDesktopPath() {
        // This path exists on the CI/dev machine's filesystem
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let homeParts = home.dropFirst().split(separator: "/").joined(separator: "-")
        let encoded = "-\(homeParts)-Desktop"
        let result = resolveProjectName(encoded)
        XCTAssertEqual(result, "Desktop")
    }

    func testNonExistentPathFallsBackToAnchor() {
        let encoded = "-Users-fake-Desktop-my-project"
        let result = resolveProjectName(encoded)
        XCTAssertEqual(result, "my-project")
    }

    func testNoAnchorMoreThanTwoSegments() {
        let encoded = "-some-deep-path-thing"
        let result = resolveProjectName(encoded)
        XCTAssertEqual(result, "path-thing")
    }

    func testSingleSegment() {
        let encoded = "onlyone"
        let result = resolveProjectName(encoded)
        XCTAssertEqual(result, "onlyone")
    }

    func testDocumentsAnchor() {
        let encoded = "-Users-fake-Documents-reports"
        let result = resolveProjectName(encoded)
        XCTAssertEqual(result, "reports")
    }

    func testAnchorIsLastSegment() {
        let encoded = "-Users-fake-Desktop"
        let result = resolveProjectName(encoded)
        XCTAssertEqual(result, "-Users-fake-Desktop")
    }
}
