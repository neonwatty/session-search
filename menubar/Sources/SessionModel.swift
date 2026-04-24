import Foundation

struct IndexStats {
    let sessionCount: Int
    let projectCount: Int
}

struct Session: Identifiable, Equatable {
    let id: String  // session UUID
    let project: String  // human-readable project name
    let projectPath: String  // full directory path
    let sessionName: String?  // from /rename, nil for MVP
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
    let lastTimestamp: Date
    let snippet: String  // FTS5 snippet with match markers
    let rank: Double  // FTS5 relevance score
}

struct FlagPreset: Codable, Identifiable, Equatable {
    var id: String { flag }
    let flag: String
    var enabled: Bool
}
