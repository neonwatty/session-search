import AppKit
import Foundation

enum AppLog {
    private static let queue = DispatchQueue(label: "com.neonwatty.SessionSearch.log")

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionSearch/Logs")
    }

    static var fileURL: URL {
        directory.appendingPathComponent("session-search.log")
    }

    static func info(_ message: String) {
        write(message)
    }

    static func error(_ message: String, _ error: Error? = nil) {
        if let error {
            write("\(message): \(error)")
        } else {
            write(message)
        }
    }

    static func revealInFinder() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private static func write(_ message: String) {
        NSLog("SessionSearch: %@", message)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        queue.async {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } catch {
                NSLog("SessionSearch: failed to write app log: %@", "\(error)")
            }
        }
    }
}
