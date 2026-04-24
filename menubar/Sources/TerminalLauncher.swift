import AppKit
import Foundation

func launchInTerminal(resumeCommandParts: [String]) {
    let shellSafe = resumeCommandParts.map { part in
        "'" + part.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }.joined(separator: " ")
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = [
        "-e",
        "tell application \"Terminal\" to do script \(appleScriptString(shellSafe))",
        "-e", "tell application \"Terminal\" to activate",
    ]
    try? proc.run()
}

private func appleScriptString(_ s: String) -> String {
    let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"" + escaped + "\""
}
