import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onHover: (Bool) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
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

            if isSelected || isHovering {
                HStack(spacing: 6) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Copy resume command")
                    .accessibilityLabel("Copy resume command")

                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Open in terminal")
                    .accessibilityLabel("Open in terminal")
                }
                .foregroundStyle(.secondary)
            }
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
            onOpen()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
        .onHover {
            isHovering = $0
            onHover($0)
        }
    }
}
