import Foundation

// Main-thread only — called exclusively from SwiftUI view bodies
private var projectNameCache: [String: String] = [:]

@MainActor
func resolveProjectName(_ encoded: String) -> String {
    if let cached = projectNameCache[encoded] { return cached }
    let resolved = _resolveProjectName(encoded)
    projectNameCache[encoded] = resolved
    return resolved
}

private func _resolveProjectName(_ encoded: String) -> String {
    // Try reconstructing the filesystem path
    let candidatePath =
        "/"
        + encoded
        .split(separator: "-", omittingEmptySubsequences: false)
        .dropFirst()  // leading empty string from "-Users..."
        .joined(separator: "/")

    if !candidatePath.isEmpty && candidatePath != "/",
        FileManager.default.fileExists(atPath: candidatePath)
    {
        return URL(fileURLWithPath: candidatePath).lastPathComponent
    }

    // Fallback: anchor-based extraction
    let parts = encoded.split(separator: "-")

    if let desktopIdx = parts.lastIndex(of: "Desktop") {
        let remaining = parts[(desktopIdx + 1)...]
        return remaining.isEmpty ? encoded : remaining.joined(separator: "-")
    }

    if let docsIdx = parts.lastIndex(of: "Documents") {
        let remaining = parts[(docsIdx + 1)...]
        return remaining.isEmpty ? encoded : remaining.joined(separator: "-")
    }

    if parts.count > 2 {
        return parts.suffix(2).joined(separator: "-")
    }

    return encoded
}
