import SwiftUI

struct EmptyStateView: View {
    let store: SessionStore
    let projectsDir: String
    let isIndexing: Bool
    let errorMessage: String?
    let onRebuild: () async -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            if isIndexing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)
            } else {
                Button("Rebuild Now") {
                    Task.detached { [store, projectsDir] in
                        do {
                            try store.indexAll(projectsDir: projectsDir)
                        } catch {
                            NSLog("SessionSearch: rebuild failed: %@", "\(error)")
                        }
                        await onRebuild()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
    }

    private var title: String {
        if isIndexing { return "Indexing sessions..." }
        if errorMessage != nil { return "Index status unavailable" }
        if !FileManager.default.fileExists(atPath: projectsDir) { return "Claude projects folder not found" }
        return "No sessions indexed yet"
    }

    private var detail: String {
        if let errorMessage { return errorMessage }
        if !FileManager.default.fileExists(atPath: projectsDir) {
            return "Expected sessions at \(projectsDir)"
        }
        return "Sessions will appear after the next index run"
    }
}
