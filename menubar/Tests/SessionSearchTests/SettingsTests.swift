import XCTest
@testable import SessionSearch

@MainActor
final class SettingsTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDefaultSettings() {
        let settings = AppSettings(directory: tempDir)
        XCTAssertTrue(settings.flagPresets.isEmpty)
        XCTAssertEqual(settings.refreshIntervalMinutes, 10)
    }

    func testSaveAndLoad() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--verbose", enabled: true)
        ]
        settings.refreshIntervalMinutes = 5
        settings.save()

        let reloaded = AppSettings(directory: tempDir)
        XCTAssertEqual(reloaded.flagPresets.count, 1)
        XCTAssertEqual(reloaded.flagPresets[0].flag, "--verbose")
        XCTAssertTrue(reloaded.flagPresets[0].enabled)
        XCTAssertEqual(reloaded.refreshIntervalMinutes, 5)
    }

    func testActiveFlags() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--verbose", enabled: true),
            FlagPreset(flag: "--model opus", enabled: false),
            FlagPreset(flag: "--dangerously-skip-permissions", enabled: true),
        ]
        XCTAssertEqual(settings.activeFlags, ["--verbose", "--dangerously-skip-permissions"])
    }

    func testResumeCommand() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--dangerously-skip-permissions", enabled: true),
        ]
        let cmd = settings.resumeCommand(sessionID: "abc-123")
        XCTAssertEqual(cmd, "claude --resume abc-123 --dangerously-skip-permissions")
    }

    func testResumeCommandNoFlags() {
        let settings = AppSettings(directory: tempDir)
        let cmd = settings.resumeCommand(sessionID: "abc-123")
        XCTAssertEqual(cmd, "claude --resume abc-123")
    }
}
