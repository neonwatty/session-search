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
    @State private var launchError: String?
    @State private var indexStats: IndexStats?
    @FocusState private var isSearchFocused: Bool
    @State private var eventMonitor: Any?

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

            if query.isEmpty && (indexStats?.sessionCount ?? 0) == 0 {
                emptyState
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            } else {
                resultsList
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }

            if let selected = results.first(where: { $0.id == selectedID }) {
                commandPreview(for: selected)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
            }

            if let launchError {
                Text(launchError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
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
        .onAppear {
            isSearchFocused = true
            installKeyboardMonitor()
        }
        .onDisappear {
            searchTask?.cancel()
            removeKeyboardMonitor()
        }
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
                .focused($isSearchFocused)
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
        SearchResultRow(
            result: result,
            isSelected: selectedID == result.id,
            onSingleTap: { copyToClipboard(result) },
            onDoubleTap: { openInTerminal(result) },
            onHover: { hovering in if hovering { selectedID = result.id } }
        )
    }

    private func commandPreview(for result: SearchResult) -> some View {
        Text(settings.resumeCommand(sessionID: result.id, cwd: result.cwd))
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color.accentColor)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .cornerRadius(4)
    }

    private var emptyState: some View {
        EmptyStateView(store: store) { await loadStats() }
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
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func installKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125:  // Down arrow
                selectNext()
                return nil
            case 126:  // Up arrow
                selectPrevious()
                return nil
            case 36:  // Return/Enter
                if let selected = results.first(where: { $0.id == selectedID }) {
                    copyToClipboard(selected)
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func selectNext() {
        guard !results.isEmpty else { return }
        guard let currentID = selectedID,
            let idx = results.firstIndex(where: { $0.id == currentID })
        else {
            selectedID = results.first?.id
            return
        }
        let nextIdx = results.index(after: idx)
        selectedID = nextIdx < results.endIndex ? results[nextIdx].id : results.first?.id
    }

    private func selectPrevious() {
        guard !results.isEmpty else { return }
        guard let currentID = selectedID,
            let idx = results.firstIndex(where: { $0.id == currentID })
        else {
            selectedID = results.last?.id
            return
        }
        selectedID = idx > results.startIndex ? results[results.index(before: idx)].id : results.last?.id
    }

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
        let cmd = settings.resumeCommand(sessionID: result.id, cwd: result.cwd)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        selectedID = result.id
        copiedID = result.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedID = nil }
    }

    private func openInTerminal(_ result: SearchResult) {
        let sessionFile = (result.projectPath as NSString).appendingPathComponent(result.id + ".jsonl")
        guard FileManager.default.fileExists(atPath: sessionFile) else {
            store.removeSession(id: result.id)
            results.removeAll { $0.id == result.id }
            if selectedID == result.id { selectedID = results.first?.id }
            launchError = "Session no longer exists — removed from index"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { launchError = nil }
            return
        }
        launchError = nil
        launchInTerminal(settings.terminalApp, cwd: result.cwd, resumeCommandParts: settings.resumeCommandParts(sessionID: result.id))
    }

}
