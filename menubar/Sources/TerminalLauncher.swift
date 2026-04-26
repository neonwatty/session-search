import AppKit
import Foundation

func launchInTerminal(_ terminal: TerminalApp, resumeCommandParts: [String]) {
    let shellSafe = resumeCommandParts.map { part in
        "'" + part.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }.joined(separator: " ")

    let script: [String]
    switch terminal {
    case .terminal:
        script = [
            "-e",
            "tell application \"Terminal\" to do script \(appleScriptString(shellSafe))",
            "-e", "tell application \"Terminal\" to activate",
        ]
    case .iterm2:
        script = [
            "-e", "tell application \"iTerm2\"",
            "-e", "create window with default profile",
            "-e", "tell current session of current window",
            "-e", "write text \(appleScriptString(shellSafe))",
            "-e", "end tell",
            "-e", "activate",
            "-e", "end tell",
        ]
    case .ghostty:
        script = [
            "-e", "tell application \"Ghostty\"",
            "-e", "set win to new window",
            "-e", "set term to focused terminal of selected tab of win",
            "-e", "input text (\(appleScriptString(shellSafe)) & return) to term",
            "-e", "activate",
            "-e", "end tell",
        ]
    }

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = script

    let errorPipe = Pipe()
    proc.standardError = errorPipe

    do {
        try proc.run()
    } catch {
        NSLog("SessionSearch: failed to start osascript for %@: %@", terminal.rawValue, "\(error)")
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
        }
    }
}

private func appleScriptString(_ s: String) -> String {
    let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"" + escaped + "\""
}
