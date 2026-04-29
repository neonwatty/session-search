import SwiftUI

struct PopoverSearchHeader: View {
    @Binding var query: String
    let isSearchFocused: FocusState<Bool>.Binding
    let onSettings: () -> Void
    let onSubmit: () -> Void
    let onQueryChange: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("SESSION SEARCH")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                TextField("Search sessions...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused(isSearchFocused)
                    .onSubmit(onSubmit)
                    .onChange(of: query) { _ in onQueryChange() }
                    .accessibilityIdentifier("session-search.query")
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
    }
}
