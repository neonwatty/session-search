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
    @State private var failedLaunchResult: SearchResult?
    @State private var indexStats: IndexStats?
    @State private var isIndexing = false
    @State private var indexStateError: String?
    @State private var projectOptions: [String] = []
    @State private var selectedProject: String?
    @State private var dateFilter: SearchDateFilter = .all
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
            PopoverSearchHeader(
                query: $query,
                isSearchFocused: $isSearchFocused,
                onSettings: { showSettings = true },
                onSubmit: performSearch,
                onQueryChange: debouncedSearch
            )
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            SearchFilterControls(
                projectOptions: projectOptions,
                selectedProject: $selectedProject,
                dateFilter: $dateFilter,
                onChange: performSearchIfNeeded
            )
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
                EmptyStateView(
                    store: store,
                    projectsDir: AppDelegate.projectsDirectoryPath(),
                    isIndexing: isIndexing,
                    errorMessage: indexStateError
                ) { await loadIndexState() }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            } else {
                SearchResultsList(
                    results: results,
                    selectedID: selectedID,
                    searchError: searchError,
                    queryIsEmpty: query.isEmpty,
                    onSelect: selectResult,
                    onCopy: copyToClipboard,
                    onOpen: openInTerminal,
                    onHover: { selectedID = $0.id }
                )
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
            if let selected = results.first(where: { $0.id == selectedID }) {
                CommandPreview(command: settings.resumeCommand(sessionID: selected.id, cwd: selected.cwd))
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
            }
            if let launchError {
                LaunchErrorView(
                    message: launchError,
                    onRetry: {
                        if let failedLaunchResult {
                            openInTerminal(failedLaunchResult)
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            Divider()
                .padding(.horizontal, 14)
                .padding(.top, 8)

            SearchFooter(
                resultCount: results.count,
                hasCopiedResult: copiedID != nil,
                indexStats: indexStats,
                isIndexing: isIndexing
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .task { await loadIndexState() }
        .onReceive(NotificationCenter.default.publisher(for: .sessionSearchIndexDidChange)) { _ in
            isIndexing = false
            Task {
                await loadIndexState()
                if !query.isEmpty {
                    performSearch()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionSearchIndexDidStart)) { _ in
            isIndexing = true
            indexStateError = nil
        }
        .onAppear {
            isSearchFocused = true
            installKeyboardMonitor()
        }
        .onDisappear {
            searchTask?.cancel()
            removeKeyboardMonitor()
        }
    }

    private func loadIndexState() async {
        do {
            let state = try await Task.detached(operation: { [store] in
                (try store.stats(), try store.projects())
            }).value
            indexStats = state.0
            projectOptions = state.1
            indexStateError = nil
            if let selectedProject, !projectOptions.contains(selectedProject) {
                self.selectedProject = nil
            }
        } catch {
            indexStateError = "Could not read the local index. Try rebuilding."
            NSLog("SessionSearch: loading index state failed: \(error)")
        }
    }

    private func installKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125:  // Down arrow
                moveSelection(forward: true)
                return nil
            case 126:  // Up arrow
                moveSelection(forward: false)
                return nil
            case 36:  // Return/Enter
                if let selected = results.first(where: { $0.id == selectedID }) {
                    openInTerminal(selected)
                    return nil
                }
                return event
            case 8:  // C
                if event.modifierFlags.contains(.command),
                    let selected = results.first(where: { $0.id == selectedID })
                {
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

    private func moveSelection(forward: Bool) {
        guard !results.isEmpty else { return }
        guard let currentID = selectedID,
            let idx = results.firstIndex(where: { $0.id == currentID })
        else {
            selectedID = forward ? results.first?.id : results.last?.id
            return
        }
        if forward {
            let nextIdx = results.index(after: idx)
            selectedID = nextIdx < results.endIndex ? results[nextIdx].id : results.first?.id
        } else {
            selectedID = idx > results.startIndex ? results[results.index(before: idx)].id : results.last?.id
        }
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

    private func performSearchIfNeeded() {
        if query.isEmpty {
            return
        }
        performSearch()
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
            results = try store.search(query: query, project: selectedProject, dateFilter: dateFilter)
            searchError = nil
        } catch {
            results = []
            searchError = "Search failed"
            NSLog("SessionSearch: search failed: \(error)")
        }
        selectedID = results.first?.id
        copiedID = nil
    }

    private func selectResult(_ result: SearchResult) {
        selectedID = result.id
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
            failedLaunchResult = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { launchError = nil }
            return
        }
        launchError = nil
        failedLaunchResult = nil
        launchInTerminal(
            settings.terminalApp, cwd: result.cwd, resumeCommandParts: settings.resumeCommandParts(sessionID: result.id)
        ) { message in
            launchError = message
            failedLaunchResult = result
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if launchError == message {
                    launchError = nil
                    failedLaunchResult = nil
                }
            }
        }
    }

}
