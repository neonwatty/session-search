import XCTest

@testable import SessionSearch

final class TerminalLauncherTests: XCTestCase {
    func testTerminalShellCommandQuotesArgumentsAndCwd() {
        let command = terminalShellCommand(
            cwd: "/Users/test/it's here",
            commandParts: ["claude", "--resume", "abc-123", "--model", "opus"]
        )

        XCTAssertEqual(command, "cd '/Users/test/it'\\''s here' && 'claude' '--resume' 'abc-123' '--model' 'opus'")
    }

    func testTerminalShellCommandWithoutCwd() {
        let command = terminalShellCommand(
            cwd: nil,
            commandParts: ["claude", "--resume", "abc-123"]
        )

        XCTAssertEqual(command, "'claude' '--resume' 'abc-123'")
    }

    func testAppleScriptStringEscapesQuotesAndBackslashes() {
        XCTAssertEqual(appleScriptString("say \"hi\" \\ now"), "\"say \\\"hi\\\" \\\\ now\"")
    }

    func testTerminalAppleScriptArguments() {
        let args = terminalAppleScriptArguments(.terminal, shellCommand: "'claude' '--resume' 'abc-123'")

        XCTAssertEqual(
            args,
            [
                "-e",
                "tell application \"Terminal\" to do script \"'claude' '--resume' 'abc-123'\"",
                "-e", "tell application \"Terminal\" to activate",
            ])
    }

    func testITermAppleScriptArguments() {
        let args = terminalAppleScriptArguments(.iterm2, shellCommand: "'claude' '--resume' 'abc-123'")

        XCTAssertTrue(args.contains("tell application \"iTerm2\""))
        XCTAssertTrue(args.contains("create window with default profile"))
        XCTAssertTrue(args.contains("write text \"'claude' '--resume' 'abc-123'\""))
    }

    func testGhosttyAppleScriptArguments() {
        let args = terminalAppleScriptArguments(.ghostty, shellCommand: "'claude' '--resume' 'abc-123'")

        XCTAssertTrue(args.contains("tell application \"Ghostty\""))
        XCTAssertTrue(args.contains("set win to new window"))
        XCTAssertTrue(args.contains("input text (\"'claude' '--resume' 'abc-123'\" & return) to term"))
    }
}
