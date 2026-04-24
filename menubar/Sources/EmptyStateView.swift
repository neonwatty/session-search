import SwiftUI

struct EmptyStateView: View {
    let store: SessionStore
    let onRebuild: () async -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("No sessions indexed yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Sessions will appear after the next index run")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Button("Rebuild Now") {
                Task.detached { [store] in
                    do {
                        try store.indexAll(
                            projectsDir: FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent(".claude/projects").path)
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
        .frame(maxWidth: .infinity, maxHeight: 300)
    }
}
