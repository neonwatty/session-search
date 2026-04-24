import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController!
    private var store: SessionStore!
    private var settings: AppSettings!
    private var indexTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = AppSettings()

        let dbDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionSearch")
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("index.db").path

        do {
            store = try SessionStore(dbPath: dbPath)
        } catch {
            NSLog("SessionSearch: failed to open database: \(error)")
            return
        }
        controller = StatusItemController(store: store, settings: settings)

        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
        Task.detached { [store = self.store!] in
            try? store.indexAll(projectsDir: projectsDir)
        }

        startIndexTimer()
    }

    private func startIndexTimer() {
        indexTimer?.invalidate()
        let interval = TimeInterval(settings.refreshIntervalMinutes * 60)
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
        let store = self.store!
        indexTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task.detached {
                try? store.indexAll(projectsDir: projectsDir)
            }
        }
    }
}
