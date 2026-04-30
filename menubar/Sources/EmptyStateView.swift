import AppKit
import SwiftUI

struct EmptyStateView: View {
    let store: SessionStore
    let projectsDir: String
    let indexStats: IndexStats?
    let projectsSnapshot: DiagnosticsReport.ProjectsDirectorySnapshot
    let isIndexing: Bool
    let errorMessage: String?
    let onRebuild: () async -> Void

    var body: some View {
        let content = EmptyStateContent.make(
            projects: projectsSnapshot,
            stats: indexStats,
            isIndexing: isIndexing,
            errorMessage: errorMessage
        )

        VStack(spacing: 10) {
            Text(content.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("session-search.empty-title")

            Text(content.detail)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("session-search.empty-detail")

            VStack(spacing: 6) {
                ForEach(content.rows, id: \.label) { row in
                    HStack {
                        Text(row.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(row.value)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(row.isWarning ? .orange : .secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            if isIndexing {
                ProgressView()
                    .controlSize(.small)
            } else {
                HStack(spacing: 12) {
                    Button("Rebuild Index") {
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

                    Button("Reveal Folder") {
                        revealProjectsLocation()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .padding(.vertical, 10)
    }

    private func revealProjectsLocation() {
        let url = URL(fileURLWithPath: projectsDir)
        if projectsSnapshot.exists {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }
}
