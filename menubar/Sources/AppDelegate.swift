import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController!
    private var store: SessionStore!
    private var settings: AppSettings!
    private var indexTimer: Timer?
    private var settingsSub: AnyCancellable?
    private var smokeWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        settings = AppSettings()

        let dbDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionSearch")
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath =
            Self.environmentValue("SESSION_SEARCH_DB_PATH")
            ?? dbDir.appendingPathComponent("index.db").path

        do {
            store = try SessionStore(dbPath: dbPath)
        } catch {
            AppLog.error("failed to open database", error)
            return
        }
        controller = StatusItemController(store: store, settings: settings)
        if Self.environmentFlag("SESSION_SEARCH_SMOKE_WINDOW") {
            showSmokeWindow()
        }

        let projectsDir = Self.projectsDirectoryPath()
        Task.detached { [store = self.store!] in
            do {
                try store.indexAll(projectsDir: projectsDir)
            } catch {
                AppLog.error("initial index failed", error)
            }
        }

        if !Self.environmentFlag("SESSION_SEARCH_DISABLE_INDEX_TIMER") {
            startIndexTimer()
        }

        settingsSub = settings.$refreshIntervalMinutes
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.startIndexTimer()
            }
    }

    private func startIndexTimer() {
        indexTimer?.invalidate()
        let interval = TimeInterval(settings.refreshIntervalMinutes * 60)
        let projectsDir = Self.projectsDirectoryPath()
        let store = self.store!
        indexTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task.detached {
                do {
                    try store.indexAll(projectsDir: projectsDir)
                } catch {
                    AppLog.error("periodic index failed", error)
                }
            }
        }
    }

    private func showSmokeWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = Self.environmentValue("SESSION_SEARCH_SMOKE_WINDOW_TITLE") ?? "Session Search Smoke"
        window.center()
        window.contentViewController = NSHostingController(rootView: PopoverView(store: store, settings: settings))
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        smokeWindow = window
    }

    static func projectsDirectoryPath() -> String {
        environmentValue("SESSION_SEARCH_PROJECTS_DIR")
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            && !environmentFlag("SESSION_SEARCH_UI_TESTING")
    }

    private static func environmentValue(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private static func environmentFlag(_ key: String) -> Bool {
        ProcessInfo.processInfo.environment[key] == "1"
    }
}
