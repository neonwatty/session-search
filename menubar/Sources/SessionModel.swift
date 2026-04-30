import Foundation

struct IndexStats {
    let sessionCount: Int
    let projectCount: Int
    let lastIndexedAt: Date?
    let scannedFileCount: Int
    let skippedFileCount: Int
    let failedParseCount: Int
}

struct IndexRunStats {
    let scannedFileCount: Int
    let skippedFileCount: Int
    let failedParseCount: Int

    static let empty = IndexRunStats(scannedFileCount: 0, skippedFileCount: 0, failedParseCount: 0)
}

struct Session: Identifiable, Equatable {
    let id: String  // session UUID
    let project: String  // human-readable project name
    let projectPath: String  // full directory path
    let sessionName: String?  // reserved for future /rename support; always nil currently
    let firstTimestamp: Date
    let lastTimestamp: Date
    let cwd: String?
    let messageCount: Int
    let fileMtime: TimeInterval
}

struct SearchResult: Identifiable, Equatable {
    let id: String  // session UUID
    let project: String
    let projectPath: String
    let sessionName: String?
    let cwd: String?  // original working directory for cd before resume
    let lastTimestamp: Date
    let snippet: String  // FTS5 snippet with match markers
    let rank: Double  // FTS5 relevance score
}

struct FlagPreset: Codable, Identifiable, Equatable {
    var id: String { flag }
    let flag: String
    var enabled: Bool
}

enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm2 = "iTerm2"
    case ghostty = "Ghostty"

    var id: String { rawValue }
}
