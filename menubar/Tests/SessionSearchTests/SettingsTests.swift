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
        XCTAssertEqual(settings.terminalApp, .terminal)
    }

    func testSaveAndLoad() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--verbose", enabled: true)
        ]
        settings.refreshIntervalMinutes = 5
        settings.terminalApp = .iterm2
        settings.save()

        let reloaded = AppSettings(directory: tempDir)
        XCTAssertEqual(reloaded.flagPresets.count, 1)
        XCTAssertEqual(reloaded.flagPresets[0].flag, "--verbose")
        XCTAssertTrue(reloaded.flagPresets[0].enabled)
        XCTAssertEqual(reloaded.refreshIntervalMinutes, 5)
        XCTAssertEqual(reloaded.terminalApp, .iterm2)
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
            FlagPreset(flag: "--dangerously-skip-permissions", enabled: true)
        ]
        let cmd = settings.resumeCommand(sessionID: "abc-123")
        XCTAssertEqual(cmd, "claude --resume abc-123 --dangerously-skip-permissions")
    }

    func testResumeCommandPartsSplitsMultiTokenFlags() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--model opus", enabled: true)
        ]

        XCTAssertEqual(
            settings.resumeCommandParts(sessionID: "abc-123"), ["claude", "--resume", "abc-123", "--model", "opus"])
        XCTAssertEqual(settings.resumeCommand(sessionID: "abc-123"), "claude --resume abc-123 --model opus")
    }

    func testResumeCommandPartsPreservesQuotedFlagValue() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--append-system-prompt \"hello world\"", enabled: true)
        ]

        XCTAssertEqual(
            settings.resumeCommandParts(sessionID: "abc-123"),
            ["claude", "--resume", "abc-123", "--append-system-prompt", "hello world"]
        )
        XCTAssertEqual(
            settings.resumeCommand(sessionID: "abc-123"),
            "claude --resume abc-123 --append-system-prompt 'hello world'"
        )
    }

    func testResumeCommandNoFlags() {
        let settings = AppSettings(directory: tempDir)
        let cmd = settings.resumeCommand(sessionID: "abc-123")
        XCTAssertEqual(cmd, "claude --resume abc-123")
    }

    func testLoadLegacySettingsWithoutTerminalApp() {
        let json = """
            {"flagPresets":[{"flag":"--verbose","enabled":true}],"refreshIntervalMinutes":5}
            """.data(using: .utf8)!
        let fileURL = tempDir.appendingPathComponent("settings.json")
        try! json.write(to: fileURL)

        let settings = AppSettings(directory: tempDir)
        XCTAssertEqual(settings.terminalApp, .terminal)
        XCTAssertEqual(settings.flagPresets.count, 1)
        XCTAssertEqual(settings.refreshIntervalMinutes, 5)
    }

    func testResumeCommandWithCwd() {
        let settings = AppSettings(directory: tempDir)
        let cmd = settings.resumeCommand(sessionID: "abc-123", cwd: "/Users/test/my project")
        XCTAssertEqual(cmd, "cd '/Users/test/my project' && claude --resume abc-123")
    }

    func testResumeCommandWithCwdContainingSingleQuote() {
        let settings = AppSettings(directory: tempDir)
        let cmd = settings.resumeCommand(sessionID: "abc-123", cwd: "/Users/test/it's a project")
        XCTAssertEqual(cmd, "cd '/Users/test/it'\\''s a project' && claude --resume abc-123")
    }

    func testResumeCommandWithNilCwd() {
        let settings = AppSettings(directory: tempDir)
        let cmd = settings.resumeCommand(sessionID: "abc-123", cwd: nil)
        XCTAssertEqual(cmd, "claude --resume abc-123")
    }

    func testResumeCommandWithEmptyCwd() {
        let settings = AppSettings(directory: tempDir)
        let cmd = settings.resumeCommand(sessionID: "abc-123", cwd: "")
        XCTAssertEqual(cmd, "claude --resume abc-123")
    }

    func testTerminalAppRawValues() {
        XCTAssertEqual(TerminalApp(rawValue: "Terminal"), .terminal)
        XCTAssertEqual(TerminalApp(rawValue: "iTerm2"), .iterm2)
        XCTAssertEqual(TerminalApp(rawValue: "Ghostty"), .ghostty)
        XCTAssertEqual(TerminalApp.allCases.count, 3)
    }
}
