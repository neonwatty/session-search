import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var flagPresets: [FlagPreset] = []
    @Published var refreshIntervalMinutes: Int = 10
    @Published var terminalApp: TerminalApp = .terminal

    private let fileURL: URL

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("settings.json")
        load()
    }

    convenience init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionSearch")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(directory: dir)
    }

    var activeFlags: [String] {
        flagPresets.filter(\.enabled).map(\.flag)
    }

    var activeFlagArguments: [String] {
        activeFlags.flatMap(Self.shellSplit)
    }

    func resumeCommandParts(sessionID: String) -> [String] {
        var parts = ["claude", "--resume", sessionID]
        parts.append(contentsOf: activeFlagArguments)
        return parts
    }

    func resumeCommand(sessionID: String, cwd: String? = nil) -> String {
        let cmd = resumeCommandParts(sessionID: sessionID)
            .map(Self.shellEscapedArgument)
            .joined(separator: " ")
        if let cwd, !cwd.isEmpty {
            return "cd \(Self.shellEscapedArgument(cwd)) && \(cmd)"
        }
        return cmd
    }

    private static func shellSplit(_ input: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false
        var tokenStarted = false

        for char in input {
            if escaping {
                current.append(char)
                escaping = false
                tokenStarted = true
                continue
            }

            if char == "\\" {
                escaping = true
                continue
            }

            if let activeQuote = quote {
                if char == activeQuote {
                    quote = nil
                } else {
                    current.append(char)
                }
                tokenStarted = true
                continue
            }

            if char == "'" || char == "\"" {
                quote = char
                tokenStarted = true
            } else if char.isWhitespace {
                if tokenStarted {
                    result.append(current)
                    current = ""
                    tokenStarted = false
                }
            } else {
                current.append(char)
                tokenStarted = true
            }
        }

        if escaping {
            current.append("\\")
            tokenStarted = true
        }
        if tokenStarted {
            result.append(current)
        }
        return result
    }

    private static func shellEscapedArgument(_ argument: String) -> String {
        guard !argument.isEmpty else { return "''" }
        let safeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/._-:=@%+"))
        if argument.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) {
            return argument
        }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    func save() {
        let data = SettingsData(
            flagPresets: flagPresets, refreshIntervalMinutes: refreshIntervalMinutes, terminalApp: terminalApp)
        guard let json = try? JSONEncoder().encode(data) else { return }
        try? json.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode(SettingsData.self, from: data)
        else { return }
        flagPresets = decoded.flagPresets
        refreshIntervalMinutes = decoded.refreshIntervalMinutes
        terminalApp = decoded.terminalApp ?? .terminal
    }
}

private struct SettingsData: Codable {
    let flagPresets: [FlagPreset]
    let refreshIntervalMinutes: Int
    let terminalApp: TerminalApp?
}
