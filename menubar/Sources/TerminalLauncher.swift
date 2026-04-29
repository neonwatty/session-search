import AppKit
import Foundation

func launchInTerminal(
    _ terminal: TerminalApp,
    cwd: String?,
    resumeCommandParts: [String],
    onFailure: @escaping (String) -> Void = { _ in }
) {
    let fullCommand = terminalShellCommand(cwd: cwd, commandParts: resumeCommandParts)
    let script = terminalAppleScriptArguments(terminal, shellCommand: fullCommand)

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = script

    let errorPipe = Pipe()
    proc.standardError = errorPipe

    do {
        try proc.run()
    } catch {
        let message = "Failed to start \(terminal.rawValue): \(error.localizedDescription)"
        NSLog("SessionSearch: %@", message)
        DispatchQueue.main.async {
            onFailure(message)
        }
        return
    }

    DispatchQueue.global(qos: .utility).async {
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "unknown error"
            NSLog(
                "SessionSearch: %@ AppleScript failed (exit %d): %@",
                terminal.rawValue, proc.terminationStatus, errorMsg)
            DispatchQueue.main.async {
                onFailure(
                    "\(terminal.rawValue) launch failed: \(errorMsg.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
    }
}

func terminalShellCommand(cwd: String?, commandParts: [String]) -> String {
    let shellSafe = commandParts.map(shellEscapedArgument).joined(separator: " ")
    if let cwd, !cwd.isEmpty {
        return "cd \(shellEscapedArgument(cwd)) && \(shellSafe)"
    }
    return shellSafe
}

func terminalAppleScriptArguments(_ terminal: TerminalApp, shellCommand: String) -> [String] {
    switch terminal {
    case .terminal:
        return [
            "-e",
            "tell application \"Terminal\" to do script \(appleScriptString(shellCommand))",
            "-e", "tell application \"Terminal\" to activate",
        ]
    case .iterm2:
        return [
            "-e", "tell application \"iTerm2\"",
            "-e", "create window with default profile",
            "-e", "tell current session of current window",
            "-e", "write text \(appleScriptString(shellCommand))",
            "-e", "end tell",
            "-e", "activate",
            "-e", "end tell",
        ]
    case .ghostty:
        return [
            "-e", "tell application \"Ghostty\"",
            "-e", "set win to new window",
            "-e", "set term to focused terminal of selected tab of win",
            "-e", "input text (\(appleScriptString(shellCommand)) & return) to term",
            "-e", "activate",
            "-e", "end tell",
        ]
    }
}

func shellEscapedArgument(_ argument: String) -> String {
    "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func appleScriptString(_ s: String) -> String {
    let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"" + escaped + "\""
}
