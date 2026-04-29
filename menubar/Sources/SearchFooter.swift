import AppKit
import SwiftUI

struct SearchFooter: View {
    let resultCount: Int
    let hasCopiedResult: Bool
    let indexStats: IndexStats?
    let isIndexing: Bool

    var body: some View {
        HStack {
            if hasCopiedResult {
                Text("Copied!")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            } else {
                Text("\(resultCount) result\(resultCount == 1 ? "" : "s") \u{00B7} click selects, Enter opens")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier("session-search.result-count")
            }
            Spacer()
            if isIndexing {
                Text("indexing...")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier("session-search.index-summary")
            } else if let indexStats {
                Text(indexSummary(indexStats))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier("session-search.index-summary")
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
    }

    private func indexSummary(_ stats: IndexStats) -> String {
        guard let lastIndexedAt = stats.lastIndexedAt else {
            return "indexed \(stats.sessionCount) sessions"
        }
        return "indexed \(relativeTime(lastIndexedAt))"
    }
}
