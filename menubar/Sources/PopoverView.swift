import AppKit
import SwiftUI

struct PopoverView: View {
    let store: SessionStore
    @ObservedObject var settings: AppSettings

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var selectedID: String?
    @State private var showSettings = false
    @State private var copiedID: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var searchError: String?
    @State private var indexStats: IndexStats?

    var body: some View {
        if showSettings {
            SettingsView(settings: settings, store: store, onBack: { showSettings = false })
        } else {
            searchView
        }
    }

    private var searchView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            searchField
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            if !settings.activeFlags.isEmpty {
                Text("\u{2713} \(settings.activeFlags.count) flag\(settings.activeFlags.count == 1 ? "" : "s") active")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            Divider()
                .padding(.horizontal, 14)

            resultsList
                .padding(.horizontal, 14)
                .padding(.top, 8)

            if let selected = results.first(where: { $0.id == selectedID }) {
                commandPreview(for: selected)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
            }

            Divider()
                .padding(.horizontal, 14)
                .padding(.top, 8)

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .task { await loadStats() }
    }

    private func loadStats() async {
        indexStats = try? await Task.detached { [store] in
            try store.stats()
        }.value
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SESSION SEARCH")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
            TextField("Search sessions...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit { performSearch() }
                .onChange(of: query) { _ in debouncedSearch() }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(results) { result in
                    resultRow(result)
                }

                if let searchError {
                    Text(searchError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .padding(.vertical, 8)
                } else if results.isEmpty && !query.isEmpty {
                    Text("No results")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func resultRow(_ result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(resolveProjectName(result.project))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(relativeTime(result.lastTimestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Text(
                result.snippet
                    .replacingOccurrences(of: "<<", with: "")
                    .replacingOccurrences(of: ">>", with: "")
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .padding(10)
        .background(
            selectedID == result.id
                ? Color(nsColor: .controlBackgroundColor)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if selectedID == result.id {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
            }
        }
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { openInTerminal(result) }
        .onTapGesture(count: 1) { copyToClipboard(result) }
        .onHover { hovering in
            if hovering { selectedID = result.id }
        }
    }

    private func commandPreview(for result: SearchResult) -> some View {
        Text(settings.resumeCommand(sessionID: result.id))
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color.accentColor)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .cornerRadius(4)
    }

    private var footer: some View {
        HStack {
            if copiedID != nil {
                Text("Copied!")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            } else {
                Text(
                    "\(results.count) result\(results.count == 1 ? "" : "s") \u{00B7} click to copy, dbl-click to open"
                )
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
            Spacer()
            if let stats = indexStats {
                Text("indexed \(stats.sessionCount) sessions")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions

    private func debouncedSearch() {
        searchTask?.cancel()
        if query.isEmpty {
            results = []
            selectedID = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)  // 250ms
            guard !Task.isCancelled else { return }
            performSearch()
        }
    }

    private func performSearch() {
        searchTask?.cancel()
        guard !query.isEmpty else {
            results = []
            selectedID = nil
            searchError = nil
            return
        }
        do {
            results = try store.search(query: query)
            searchError = nil
        } catch {
            results = []
            searchError = "Search failed"
            NSLog("SessionSearch: search failed: \(error)")
        }
        selectedID = results.first?.id
        copiedID = nil
    }

    private func copyToClipboard(_ result: SearchResult) {
        let cmd = settings.resumeCommand(sessionID: result.id)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        selectedID = result.id
        copiedID = result.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedID = nil }
    }

    private func openInTerminal(_ result: SearchResult) {
        let parts = settings.resumeCommandParts(sessionID: result.id)
        let shellSafe = parts.map { part in
            "'" + part.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }.joined(separator: " ")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = [
            "-e",
            "tell application \"Terminal\" to do script \(appleScriptString(shellSafe))",
            "-e", "tell application \"Terminal\" to activate",
        ]
        try? proc.run()
    }

    private func appleScriptString(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
