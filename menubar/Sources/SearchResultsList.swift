import SwiftUI

struct SearchResultsList: View {
    let results: [SearchResult]
    let selectedID: String?
    let searchError: String?
    let queryIsEmpty: Bool
    let onSelect: (SearchResult) -> Void
    let onCopy: (SearchResult) -> Void
    let onOpen: (SearchResult) -> Void
    let onHover: (SearchResult) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(results) { result in
                    SearchResultRow(
                        result: result,
                        isSelected: selectedID == result.id,
                        onSelect: { onSelect(result) },
                        onCopy: { onCopy(result) },
                        onOpen: { onOpen(result) },
                        onHover: { hovering in
                            if hovering {
                                onHover(result)
                            }
                        }
                    )
                }
                emptyOrErrorMessage
            }
        }
        .frame(maxHeight: 300)
    }

    @ViewBuilder
    private var emptyOrErrorMessage: some View {
        if let searchError {
            Text(searchError)
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .padding(.vertical, 8)
        } else if results.isEmpty && !queryIsEmpty {
            Text("No results")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
    }
}
