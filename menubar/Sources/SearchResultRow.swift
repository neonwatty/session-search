import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onHover: (Bool) -> Void

    @State private var clickTimer: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(resolveProjectName(result.project))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(relativeTime(result.lastTimestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            highlightedSnippet(result.snippet)
                .font(.system(size: 11))
                .lineLimit(2)
        }
        .padding(10)
        .background(
            isSelected
                ? Color(nsColor: .controlBackgroundColor)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
            }
        }
        .cornerRadius(6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("session-search.result.\(result.id)")
        .onTapGesture(count: 2) {
            clickTimer?.cancel()
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            clickTimer?.cancel()
            let work = DispatchWorkItem { onSingleTap() }
            clickTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
        .onHover { onHover($0) }
        .onDisappear { clickTimer?.cancel() }
    }
}
