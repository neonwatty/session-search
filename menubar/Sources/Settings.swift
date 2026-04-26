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

    func resumeCommandParts(sessionID: String) -> [String] {
        var parts = ["claude", "--resume", sessionID]
        parts.append(contentsOf: activeFlags)
        return parts
    }

    func resumeCommand(sessionID: String) -> String {
        resumeCommandParts(sessionID: sessionID).joined(separator: " ")
    }

    func save() {
        let data = SettingsData(flagPresets: flagPresets, refreshIntervalMinutes: refreshIntervalMinutes, terminalApp: terminalApp)
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
