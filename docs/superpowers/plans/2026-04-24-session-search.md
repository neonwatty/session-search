# Session Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that provides full-text search across Claude Code session history with one-click resume.

**Architecture:** Native SwiftUI menu bar app with SQLite FTS5 for indexing JSONL session transcripts. Three layers: JSONL parser, SQLite indexer/query engine, SwiftUI popover UI. Follows FleetMenuBar conventions (xcodegen, ad-hoc signing, LaunchAgent).

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSStatusItem/NSPopover), SQLite3 C API (system library), xcodegen

---

## File Map

```
session-search/
  menubar/
    project.yml                          -- xcodegen spec
    Sources/
      SessionSearchApp.swift             -- @main, empty scene (UI via AppDelegate)
      AppDelegate.swift                  -- creates StatusItemController + starts indexer
      StatusItemController.swift         -- NSStatusItem, popover toggle
      PopoverView.swift                  -- search field + results list + command preview
      SettingsView.swift                 -- flag presets toggles + index info + refresh interval
      SessionModel.swift                 -- Session, SearchResult, FlagPreset structs
      Settings.swift                     -- load/save settings JSON, ObservableObject
      SessionStore.swift                 -- SQLite FTS5: create tables, index, query, snippet
      JSONLParser.swift                  -- parse .jsonl files, extract messages + metadata
    Tests/
      SessionSearchTests/
        JSONLParserTests.swift           -- parse user/assistant messages, edge cases
        SessionStoreTests.swift          -- index, query, snippet, incremental reindex
        SettingsTests.swift              -- load/save/defaults
      SessionSearchTests/Fixtures/
        sample-session.jsonl             -- realistic test fixture
    scripts/
      install-login-item.sh             -- LaunchAgent plist writer (from fleet pattern)
    Makefile                             -- build, test, install, install-login, clean
```

---

### Task 1: Project Scaffold -- xcodegen, Makefile, App Shell

**Files:**
- Create: `menubar/project.yml`
- Create: `menubar/Sources/SessionSearchApp.swift`
- Create: `menubar/Sources/AppDelegate.swift`
- Create: `menubar/Sources/Info.plist`
- Create: `menubar/Makefile`

- [ ] **Step 1: Create `menubar/project.yml`**

```yaml
name: SessionSearch
options:
  bundleIdPrefix: com.neonwatty
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"
    ENABLE_HARDENED_RUNTIME: NO
    ENABLE_APP_SANDBOX: NO
    COMBINE_HIDPI_IMAGES: YES

targets:
  SessionSearch:
    type: application
    platform: macOS
    sources:
      - path: Sources
    info:
      path: Sources/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: SessionSearch
        CFBundleDisplayName: Session Search
        CFBundleIdentifier: com.neonwatty.SessionSearch
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        LSMinimumSystemVersion: "13.0"
        NSHumanReadableCopyright: "Copyright 2026 Jeremy Watt"

  SessionSearchTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/SessionSearchTests
      - path: Tests/SessionSearchTests/Fixtures
        buildPhase: resources
    dependencies:
      - target: SessionSearch
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.neonwatty.SessionSearchTests
```

- [ ] **Step 2: Create `menubar/Sources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>SessionSearch</string>
    <key>CFBundleDisplayName</key>
    <string>Session Search</string>
    <key>CFBundleIdentifier</key>
    <string>com.neonwatty.SessionSearch</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Jeremy Watt</string>
</dict>
</plist>
```

- [ ] **Step 3: Create `menubar/Sources/SessionSearchApp.swift`**

```swift
import SwiftUI

@main
struct SessionSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 4: Create `menubar/Sources/AppDelegate.swift`**

Minimal version -- just prove the app launches. StatusItemController and SessionStore will be wired in later tasks.

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Will wire up StatusItemController + SessionStore in later tasks
        print("SessionSearch launched")
    }
}
```

- [ ] **Step 5: Create `menubar/Makefile`**

```makefile
.PHONY: build test install install-login clean generate

APP_NAME := SessionSearch
PROJ := $(APP_NAME).xcodeproj
BUILD_DIR := build
INSTALL_DIR := $(HOME)/Applications

generate:
	xcodegen generate

build: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -configuration Release -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

install: build
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app $(INSTALL_DIR)/
	@if [ -f "$(HOME)/Library/LaunchAgents/com.neonwatty.$(APP_NAME).plist" ]; then \
	  echo "LaunchAgent detected -- restarting managed instance"; \
	  launchctl kickstart -k "gui/$$(id -u)/com.neonwatty.$(APP_NAME)"; \
	else \
	  open $(INSTALL_DIR)/$(APP_NAME).app; \
	fi

install-login:
	./scripts/install-login-item.sh

clean:
	rm -rf $(PROJ) $(BUILD_DIR)
```

- [ ] **Step 6: Verify build**

```bash
cd menubar && make build
```

Expected: build succeeds, app binary at `menubar/build/Build/Products/Release/SessionSearch.app`.

- [ ] **Step 7: Commit**

```bash
git add menubar/project.yml menubar/Sources/Info.plist menubar/Sources/SessionSearchApp.swift menubar/Sources/AppDelegate.swift menubar/Makefile
git commit -m "scaffold: xcodegen project, app shell, Makefile"
```

---

### Task 2: Data Model -- SessionModel.swift

**Files:**
- Create: `menubar/Sources/SessionModel.swift`

- [ ] **Step 1: Create `menubar/Sources/SessionModel.swift`**

```swift
import Foundation

struct Session: Identifiable, Equatable {
    let id: String            // session UUID
    let project: String       // human-readable project name
    let projectPath: String   // full directory path
    let sessionName: String?  // from /rename, nil for MVP
    let firstTimestamp: Date
    let lastTimestamp: Date
    let cwd: String?
    let messageCount: Int
    let fileMtime: TimeInterval
}

struct SearchResult: Identifiable, Equatable {
    let id: String            // session UUID
    let project: String
    let projectPath: String
    let sessionName: String?
    let lastTimestamp: Date
    let snippet: String       // FTS5 snippet with match markers
    let rank: Double          // FTS5 relevance score
}

struct FlagPreset: Codable, Identifiable, Equatable {
    var id: String { flag }
    let flag: String
    var enabled: Bool
}
```

- [ ] **Step 2: Verify build**

```bash
cd menubar && make build
```

Expected: compiles cleanly.

- [ ] **Step 3: Commit**

```bash
git add menubar/Sources/SessionModel.swift
git commit -m "feat: add Session, SearchResult, FlagPreset data types"
```

---

### Task 3: Settings Persistence -- Settings.swift

**Files:**
- Create: `menubar/Sources/Settings.swift`
- Create: `menubar/Tests/SessionSearchTests/SettingsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `menubar/Tests/SessionSearchTests/SettingsTests.swift`:

```swift
import XCTest
@testable import SessionSearch

final class SettingsTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDefaultSettings() {
        let settings = AppSettings(directory: tempDir)
        XCTAssertTrue(settings.flagPresets.isEmpty)
        XCTAssertEqual(settings.refreshIntervalMinutes, 10)
    }

    func testSaveAndLoad() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--verbose", enabled: true)
        ]
        settings.refreshIntervalMinutes = 5
        settings.save()

        let reloaded = AppSettings(directory: tempDir)
        XCTAssertEqual(reloaded.flagPresets.count, 1)
        XCTAssertEqual(reloaded.flagPresets[0].flag, "--verbose")
        XCTAssertTrue(reloaded.flagPresets[0].enabled)
        XCTAssertEqual(reloaded.refreshIntervalMinutes, 5)
    }

    func testActiveFlags() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--verbose", enabled: true),
            FlagPreset(flag: "--model opus", enabled: false),
            FlagPreset(flag: "--dangerously-skip-permissions", enabled: true),
        ]
        XCTAssertEqual(settings.activeFlags, ["--verbose", "--dangerously-skip-permissions"])
    }

    func testResumeCommand() {
        let settings = AppSettings(directory: tempDir)
        settings.flagPresets = [
            FlagPreset(flag: "--dangerously-skip-permissions", enabled: true),
        ]
        let cmd = settings.resumeCommand(sessionID: "abc-123")
        XCTAssertEqual(cmd, "claude --resume abc-123 --dangerously-skip-permissions")
    }

    func testResumeCommandNoFlags() {
        let settings = AppSettings(directory: tempDir)
        let cmd = settings.resumeCommand(sessionID: "abc-123")
        XCTAssertEqual(cmd, "claude --resume abc-123")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd menubar && make test
```

Expected: FAIL -- `AppSettings` not defined.

- [ ] **Step 3: Implement `menubar/Sources/Settings.swift`**

```swift
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var flagPresets: [FlagPreset] = []
    @Published var refreshIntervalMinutes: Int = 10

    private let fileURL: URL

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("settings.json")
        load()
    }

    convenience init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionSearch")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(directory: dir)
    }

    var activeFlags: [String] {
        flagPresets.filter(\.enabled).map(\.flag)
    }

    func resumeCommand(sessionID: String) -> String {
        var parts = ["claude", "--resume", sessionID]
        parts.append(contentsOf: activeFlags)
        return parts.joined(separator: " ")
    }

    func save() {
        let data = SettingsData(flagPresets: flagPresets, refreshIntervalMinutes: refreshIntervalMinutes)
        guard let json = try? JSONEncoder().encode(data) else { return }
        try? json.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(SettingsData.self, from: data) else { return }
        flagPresets = decoded.flagPresets
        refreshIntervalMinutes = decoded.refreshIntervalMinutes
    }
}

private struct SettingsData: Codable {
    let flagPresets: [FlagPreset]
    let refreshIntervalMinutes: Int
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd menubar && make test
```

Expected: all 5 settings tests PASS.

- [ ] **Step 5: Commit**

```bash
git add menubar/Sources/Settings.swift menubar/Tests/SessionSearchTests/SettingsTests.swift
git commit -m "feat: settings persistence with flag presets and resume command builder"
```

---

### Task 4: JSONL Parser -- JSONLParser.swift

**Files:**
- Create: `menubar/Sources/JSONLParser.swift`
- Create: `menubar/Tests/SessionSearchTests/JSONLParserTests.swift`
- Create: `menubar/Tests/SessionSearchTests/Fixtures/sample-session.jsonl`

- [ ] **Step 1: Create the test fixture**

Create `menubar/Tests/SessionSearchTests/Fixtures/sample-session.jsonl`:

```jsonl
{"type":"permission-mode","permissionMode":"bypassPermissions","sessionId":"de951b93-ec97-4566-bad9-54f683846d06"}
{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"Help me understand more about Playwrights CLI and its ability to be used across repos"},"uuid":"32fa59fc-3799-4a27-adfd-e03335fafcab","timestamp":"2026-04-23T22:45:40.063Z","sessionId":"de951b93-ec97-4566-bad9-54f683846d06","cwd":"/Users/neonwatty/Desktop"}
{"parentUuid":"32fa59fc","isSidechain":false,"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Playwright CLI provides cross-repo browser automation with session isolation."},{"type":"tool_use","id":"toolu_123","name":"Read","input":{"file_path":"/tmp/test"}}]},"uuid":"ccfeb2fa","timestamp":"2026-04-23T22:46:10.000Z","sessionId":"de951b93-ec97-4566-bad9-54f683846d06"}
{"type":"file-history-snapshot","messageId":"xyz","snapshot":{"messageId":"xyz","trackedFileBackups":{},"timestamp":"2026-04-23T22:47:00.000Z"},"isSnapshotUpdate":false}
{"parentUuid":"ccfeb2fa","isSidechain":false,"type":"user","message":{"role":"user","content":"How do I set up storageState for auth?"},"uuid":"aaa111","timestamp":"2026-04-23T22:48:00.000Z","sessionId":"de951b93-ec97-4566-bad9-54f683846d06","cwd":"/Users/neonwatty/Desktop"}
{"parentUuid":"aaa111","isSidechain":false,"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"You can save auth state using storageState option in Playwright config."}]},"uuid":"bbb222","timestamp":"2026-04-23T22:49:00.000Z","sessionId":"de951b93-ec97-4566-bad9-54f683846d06"}
```

- [ ] **Step 2: Write the failing tests**

Create `menubar/Tests/SessionSearchTests/JSONLParserTests.swift`:

```swift
import XCTest
@testable import SessionSearch

final class JSONLParserTests: XCTestCase {
    private func fixtureURL() -> URL {
        Bundle(for: type(of: self))
            .url(forResource: "sample-session", withExtension: "jsonl")!
    }

    func testParseSessionMetadata() throws {
        let result = try JSONLParser.parse(fileAt: fixtureURL())
        XCTAssertEqual(result.sessionID, "de951b93-ec97-4566-bad9-54f683846d06")
        XCTAssertEqual(result.cwd, "/Users/neonwatty/Desktop")
        XCTAssertEqual(result.messageCount, 4) // 2 user + 2 assistant
    }

    func testParseTimestamps() throws {
        let result = try JSONLParser.parse(fileAt: fixtureURL())
        let cal = Calendar(identifier: .gregorian)
        let firstComps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: result.firstTimestamp)
        XCTAssertEqual(firstComps.hour, 22)
        XCTAssertEqual(firstComps.minute, 45)
        let lastComps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: result.lastTimestamp)
        XCTAssertEqual(lastComps.minute, 49)
    }

    func testParseContentConcatenation() throws {
        let result = try JSONLParser.parse(fileAt: fixtureURL())
        XCTAssertTrue(result.content.contains("Playwrights CLI"))
        XCTAssertTrue(result.content.contains("cross-repo browser automation"))
        XCTAssertTrue(result.content.contains("storageState"))
        // tool_use blocks should NOT be in content
        XCTAssertFalse(result.content.contains("toolu_123"))
    }

    func testParseSkipsNonMessageLines() throws {
        let result = try JSONLParser.parse(fileAt: fixtureURL())
        XCTAssertFalse(result.content.contains("trackedFileBackups"))
    }

    func testParseEmptyFile() {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).jsonl")
        FileManager.default.createFile(atPath: tempFile.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try JSONLParser.parse(fileAt: tempFile))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd menubar && make test
```

Expected: FAIL -- `JSONLParser` not defined.

- [ ] **Step 4: Implement `menubar/Sources/JSONLParser.swift`**

```swift
import Foundation

struct ParsedSession {
    let sessionID: String
    let cwd: String?
    let firstTimestamp: Date
    let lastTimestamp: Date
    let messageCount: Int
    let content: String
}

enum JSONLParser {
    enum ParseError: Error {
        case emptyFile
        case noMessages
    }

    static func parse(fileAt url: URL) throws -> ParsedSession {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw ParseError.emptyFile }

        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        var sessionID: String?
        var cwd: String?
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var messageCount = 0
        var contentParts: [String] = []

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = obj["type"] as? String else { continue }

            if type == "permission-mode" {
                sessionID = obj["sessionId"] as? String
                continue
            }

            guard type == "user" || type == "assistant" else { continue }

            if let ts = obj["timestamp"] as? String {
                if let date = isoFormatter.date(from: ts) {
                    if firstTimestamp == nil { firstTimestamp = date }
                    lastTimestamp = date
                }
            }

            if cwd == nil, let c = obj["cwd"] as? String {
                cwd = c
            }

            if sessionID == nil, let sid = obj["sessionId"] as? String {
                sessionID = sid
            }

            guard let message = obj["message"] as? [String: Any] else { continue }
            messageCount += 1

            if let contentStr = message["content"] as? String {
                contentParts.append(contentStr)
            } else if let contentArr = message["content"] as? [[String: Any]] {
                for block in contentArr {
                    if block["type"] as? String == "text",
                       let text = block["text"] as? String {
                        contentParts.append(text)
                    }
                }
            }
        }

        guard let sid = sessionID, let first = firstTimestamp, let last = lastTimestamp,
              messageCount > 0 else {
            throw ParseError.noMessages
        }

        return ParsedSession(
            sessionID: sid,
            cwd: cwd,
            firstTimestamp: first,
            lastTimestamp: last,
            messageCount: messageCount,
            content: contentParts.joined(separator: "\n")
        )
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd menubar && make test
```

Expected: all 5 parser tests PASS.

- [ ] **Step 6: Commit**

```bash
git add menubar/Sources/JSONLParser.swift menubar/Tests/SessionSearchTests/JSONLParserTests.swift menubar/Tests/SessionSearchTests/Fixtures/sample-session.jsonl
git commit -m "feat: JSONL parser extracts session metadata and content"
```

---

### Task 5: SQLite FTS5 Store -- SessionStore.swift

**Files:**
- Create: `menubar/Sources/SessionStore.swift`
- Create: `menubar/Tests/SessionSearchTests/SessionStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `menubar/Tests/SessionSearchTests/SessionStoreTests.swift`:

```swift
import XCTest
@testable import SessionSearch

final class SessionStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: SessionStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = try! SessionStore(dbPath: tempDir.appendingPathComponent("test.db").path)
    }

    override func tearDown() {
        store = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testUpsertAndSearch() throws {
        let parsed = ParsedSession(
            sessionID: "sess-001",
            cwd: "/Users/test/Desktop",
            firstTimestamp: Date(timeIntervalSince1970: 1000),
            lastTimestamp: Date(timeIntervalSince1970: 2000),
            messageCount: 5,
            content: "Setting up Playwright for browser testing across repos"
        )
        try store.upsert(parsed: parsed, project: "my-project", projectPath: "/projects/my-project", fileMtime: 100.0)

        let results = try store.search(query: "playwright")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "sess-001")
        XCTAssertEqual(results[0].project, "my-project")
        XCTAssertTrue(results[0].snippet.lowercased().contains("playwright"))
    }

    func testSearchNoResults() throws {
        let results = try store.search(query: "nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testUpsertOverwrites() throws {
        let v1 = ParsedSession(
            sessionID: "sess-001", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "old content about React"
        )
        try store.upsert(parsed: v1, project: "proj", projectPath: "/proj", fileMtime: 100.0)

        let v2 = ParsedSession(
            sessionID: "sess-001", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 2, content: "new content about Playwright"
        )
        try store.upsert(parsed: v2, project: "proj", projectPath: "/proj", fileMtime: 200.0)

        XCTAssertTrue(try store.search(query: "react").isEmpty)
        XCTAssertEqual(try store.search(query: "playwright").count, 1)
    }

    func testGetMtime() throws {
        let parsed = ParsedSession(
            sessionID: "sess-001", cwd: nil,
            firstTimestamp: Date(), lastTimestamp: Date(),
            messageCount: 1, content: "test"
        )
        try store.upsert(parsed: parsed, project: "p", projectPath: "/p", fileMtime: 42.5)
        XCTAssertEqual(try store.getMtime(sessionID: "sess-001"), 42.5)
        XCTAssertNil(try store.getMtime(sessionID: "nonexistent"))
    }

    func testStats() throws {
        let p1 = ParsedSession(sessionID: "s1", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(), messageCount: 1, content: "a")
        let p2 = ParsedSession(sessionID: "s2", cwd: nil, firstTimestamp: Date(), lastTimestamp: Date(), messageCount: 1, content: "b")
        try store.upsert(parsed: p1, project: "proj-a", projectPath: "/a", fileMtime: 1)
        try store.upsert(parsed: p2, project: "proj-b", projectPath: "/b", fileMtime: 2)

        let stats = try store.stats()
        XCTAssertEqual(stats.sessionCount, 2)
        XCTAssertEqual(stats.projectCount, 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd menubar && make test
```

Expected: FAIL -- `SessionStore` not defined.

- [ ] **Step 3: Implement `menubar/Sources/SessionStore.swift`**

```swift
import Foundation
import SQLite3

struct IndexStats {
    let sessionCount: Int
    let projectCount: Int
}

final class SessionStore {
    private var db: OpaquePointer?

    init(dbPath: String) throws {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw StoreError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        try createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private func createTables() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            project TEXT NOT NULL,
            project_path TEXT NOT NULL,
            session_name TEXT,
            first_timestamp REAL NOT NULL,
            last_timestamp REAL NOT NULL,
            cwd TEXT,
            message_count INTEGER NOT NULL,
            file_mtime REAL NOT NULL
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS session_content USING fts5(
            session_id,
            content,
            tokenize='porter unicode61'
        );
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Upsert

    func upsert(parsed: ParsedSession, project: String, projectPath: String, fileMtime: Double) throws {
        try exec("DELETE FROM session_content WHERE session_id = ?", bind: [.text(parsed.sessionID)])
        try exec("DELETE FROM sessions WHERE id = ?", bind: [.text(parsed.sessionID)])

        try exec("""
            INSERT INTO sessions (id, project, project_path, session_name, first_timestamp, last_timestamp, cwd, message_count, file_mtime)
            VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?)
            """, bind: [
                .text(parsed.sessionID),
                .text(project),
                .text(projectPath),
                .double(parsed.firstTimestamp.timeIntervalSince1970),
                .double(parsed.lastTimestamp.timeIntervalSince1970),
                .optionalText(parsed.cwd),
                .int(parsed.messageCount),
                .double(fileMtime),
            ])

        try exec("""
            INSERT INTO session_content (session_id, content) VALUES (?, ?)
            """, bind: [.text(parsed.sessionID), .text(parsed.content)])
    }

    // MARK: - Query

    func search(query: String, limit: Int = 20) throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let sanitized = query.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsQuery = "\"\(sanitized)\"*"

        let sql = """
            SELECT s.id, s.project, s.project_path, s.session_name, s.last_timestamp,
                   snippet(session_content, 1, '<<', '>>', '...', 32) AS snip,
                   rank
            FROM session_content
            JOIN sessions s ON s.id = session_content.session_id
            WHERE session_content MATCH ?
            ORDER BY rank
            LIMIT ?
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, ftsQuery, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let project = String(cString: sqlite3_column_text(stmt, 1))
            let projectPath = String(cString: sqlite3_column_text(stmt, 2))
            let sessionName: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL
                ? nil : String(cString: sqlite3_column_text(stmt, 3))
            let lastTs = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            let snippet = String(cString: sqlite3_column_text(stmt, 5))
            let rank = sqlite3_column_double(stmt, 6)

            results.append(SearchResult(
                id: id, project: project, projectPath: projectPath,
                sessionName: sessionName, lastTimestamp: lastTs,
                snippet: snippet, rank: rank
            ))
        }
        return results
    }

    // MARK: - Mtime check

    func getMtime(sessionID: String) throws -> Double? {
        let sql = "SELECT file_mtime FROM sessions WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_double(stmt, 0)
        }
        return nil
    }

    // MARK: - Stats

    func stats() throws -> IndexStats {
        var sessionCount = 0
        var projectCount = 0

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM sessions", -1, &stmt, nil)
        if sqlite3_step(stmt) == SQLITE_ROW { sessionCount = Int(sqlite3_column_int(stmt, 0)) }
        sqlite3_finalize(stmt)

        sqlite3_prepare_v2(db, "SELECT COUNT(DISTINCT project) FROM sessions", -1, &stmt, nil)
        if sqlite3_step(stmt) == SQLITE_ROW { projectCount = Int(sqlite3_column_int(stmt, 0)) }
        sqlite3_finalize(stmt)

        return IndexStats(sessionCount: sessionCount, projectCount: projectCount)
    }

    // MARK: - Helpers

    private enum BindValue {
        case text(String)
        case optionalText(String?)
        case int(Int)
        case double(Double)
    }

    private func exec(_ sql: String, bind: [BindValue] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        for (i, value) in bind.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case .text(let s):
                sqlite3_bind_text(stmt, idx, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .optionalText(let s):
                if let s {
                    sqlite3_bind_text(stmt, idx, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                } else {
                    sqlite3_bind_null(stmt, idx)
                }
            case .int(let n):
                sqlite3_bind_int(stmt, idx, Int32(n))
            case .double(let d):
                sqlite3_bind_double(stmt, idx, d)
            }
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    enum StoreError: Error {
        case openFailed(String)
        case execFailed(String)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd menubar && make test
```

Expected: all 5 store tests PASS.

- [ ] **Step 5: Commit**

```bash
git add menubar/Sources/SessionStore.swift menubar/Tests/SessionSearchTests/SessionStoreTests.swift
git commit -m "feat: SQLite FTS5 session store with upsert, search, and stats"
```

---

### Task 6: Indexer -- Wire Parser + Store for Directory Scanning

**Files:**
- Modify: `menubar/Sources/SessionStore.swift` -- add `indexAll(projectsDir:)` method
- Modify: `menubar/Tests/SessionSearchTests/SessionStoreTests.swift` -- add indexer tests

- [ ] **Step 1: Write the failing tests**

Add to `menubar/Tests/SessionSearchTests/SessionStoreTests.swift`:

```swift
func testIndexAllScansDirectory() throws {
    let projectsDir = tempDir.appendingPathComponent("projects")
    let projectDir = projectsDir.appendingPathComponent("-test-project")
    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

    let fixtureURL = Bundle(for: type(of: self))
        .url(forResource: "sample-session", withExtension: "jsonl")!
    let destURL = projectDir.appendingPathComponent("de951b93-ec97-4566-bad9-54f683846d06.jsonl")
    try FileManager.default.copyItem(at: fixtureURL, to: destURL)

    try store.indexAll(projectsDir: projectsDir.path)

    let results = try store.search(query: "playwright")
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].project, "-test-project")
}

func testIndexAllSkipsUnchangedFiles() throws {
    let projectsDir = tempDir.appendingPathComponent("projects")
    let projectDir = projectsDir.appendingPathComponent("-test-project")
    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

    let fixtureURL = Bundle(for: type(of: self))
        .url(forResource: "sample-session", withExtension: "jsonl")!
    let destURL = projectDir.appendingPathComponent("sess-skip.jsonl")
    try FileManager.default.copyItem(at: fixtureURL, to: destURL)

    try store.indexAll(projectsDir: projectsDir.path)
    try store.indexAll(projectsDir: projectsDir.path)

    let results = try store.search(query: "playwright")
    XCTAssertEqual(results.count, 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd menubar && make test
```

Expected: FAIL -- `indexAll` method not defined.

- [ ] **Step 3: Add `indexAll` to `SessionStore.swift`**

Add this method to the `SessionStore` class:

```swift
// MARK: - Full index

func indexAll(projectsDir: String) throws {
    let fm = FileManager.default
    let projectsURL = URL(fileURLWithPath: projectsDir)

    guard let projectDirs = try? fm.contentsOfDirectory(
        at: projectsURL, includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else { return }

    for projectDir in projectDirs {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

        let project = projectDir.lastPathComponent

        guard let files = try? fm.contentsOfDirectory(
            at: projectDir, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { continue }

        for file in files where file.pathExtension == "jsonl" {
            let sessionID = file.deletingPathExtension().lastPathComponent
            // Skip agent sub-sessions (contain #)
            guard !sessionID.contains("#") else { continue }

            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let mtime = attrs.contentModificationDate?.timeIntervalSince1970 else { continue }

            if let existing = try? getMtime(sessionID: sessionID), existing == mtime {
                continue
            }

            guard let parsed = try? JSONLParser.parse(fileAt: file) else { continue }
            try upsert(parsed: parsed, project: project, projectPath: projectDir.path, fileMtime: mtime)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd menubar && make test
```

Expected: all store tests PASS (including the 2 new indexer tests).

- [ ] **Step 5: Commit**

```bash
git add menubar/Sources/SessionStore.swift menubar/Tests/SessionSearchTests/SessionStoreTests.swift
git commit -m "feat: directory scanner indexes all projects with mtime-based skip"
```

---

### Task 7: StatusItemController -- Menu Bar Icon + Popover Shell

**Files:**
- Create: `menubar/Sources/StatusItemController.swift`
- Modify: `menubar/Sources/AppDelegate.swift` -- wire up controller + store + timer
- Create: `menubar/Sources/PopoverView.swift` -- placeholder

- [ ] **Step 1: Create `menubar/Sources/StatusItemController.swift`**

```swift
import AppKit
import SwiftUI

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(store: SessionStore, settings: AppSettings) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.behavior = .transient
        let hosting = NSHostingController(rootView: PopoverView(store: store, settings: settings))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        let config = NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor])
        let image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: "Session Search"
        )?.withSymbolConfiguration(config)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

- [ ] **Step 2: Update `menubar/Sources/AppDelegate.swift`**

Replace the full contents:

```swift
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

        store = try! SessionStore(dbPath: dbPath)
        controller = StatusItemController(store: store, settings: settings)

        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
        Task.detached { [store] in
            try? store!.indexAll(projectsDir: projectsDir)
        }

        startIndexTimer()
    }

    private func startIndexTimer() {
        indexTimer?.invalidate()
        let interval = TimeInterval(settings.refreshIntervalMinutes * 60)
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
        indexTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let store = self?.store else { return }
            Task.detached {
                try? store.indexAll(projectsDir: projectsDir)
            }
        }
    }
}
```

- [ ] **Step 3: Create placeholder `menubar/Sources/PopoverView.swift`**

```swift
import SwiftUI

struct PopoverView: View {
    let store: SessionStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        Text("Session Search")
            .padding()
            .frame(width: 360)
    }
}
```

- [ ] **Step 4: Verify build**

```bash
cd menubar && make build
```

Expected: builds cleanly, magnifying glass icon appears in menu bar when run.

- [ ] **Step 5: Commit**

```bash
git add menubar/Sources/StatusItemController.swift menubar/Sources/AppDelegate.swift menubar/Sources/PopoverView.swift
git commit -m "feat: menu bar icon with popover shell, background indexer with timer"
```

---

### Task 8: PopoverView -- Search UI + Results

**Files:**
- Modify: `menubar/Sources/PopoverView.swift` -- full search UI

- [ ] **Step 1: Replace `menubar/Sources/PopoverView.swift`**

```swift
import SwiftUI
import AppKit

struct PopoverView: View {
    let store: SessionStore
    @ObservedObject var settings: AppSettings

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var selectedID: String?
    @State private var showSettings = false
    @State private var copiedID: String?

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
                .onChange(of: query) { _ in performSearch() }
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

                if results.isEmpty && !query.isEmpty {
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
                Text(humanProjectName(result.project))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(relativeTime(result.lastTimestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Text(result.snippet
                .replacingOccurrences(of: "<<", with: "")
                .replacingOccurrences(of: ">>", with: ""))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(selectedID == result.id
            ? Color(nsColor: .controlBackgroundColor)
            : Color.clear)
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
                Text("\(results.count) result\(results.count == 1 ? "" : "s") \u{00B7} click to copy, dbl-click to open")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let stats = try? store.stats() {
                Text("indexed \(stats.sessionCount) sessions")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions

    private func performSearch() {
        guard !query.isEmpty else { results = []; selectedID = nil; return }
        results = (try? store.search(query: query)) ?? []
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
        let cmd = settings.resumeCommand(sessionID: result.id)
        let escaped = cmd.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = [
            "-e", "tell application \"Terminal\" to do script \"\(escaped)\"",
            "-e", "tell application \"Terminal\" to activate",
        ]
        try? proc.run()
    }

    // MARK: - Formatting

    private func humanProjectName(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        if let desktopIdx = parts.lastIndex(of: "Desktop") {
            let remaining = parts[(desktopIdx + 1)...]
            return remaining.isEmpty ? raw : remaining.joined(separator: "-")
        }
        if let docsIdx = parts.lastIndex(of: "Documents") {
            let remaining = parts[(docsIdx + 1)...]
            return remaining.isEmpty ? raw : remaining.joined(separator: "-")
        }
        if parts.count > 2 {
            return parts.suffix(2).joined(separator: "-")
        }
        return raw
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

- [ ] **Step 2: Create placeholder `menubar/Sources/SettingsView.swift`**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let store: SessionStore
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13))
                        .foregroundStyle(.accentColor)
                }
                .buttonStyle(.plain)
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(14)

            Text("Coming soon...")
                .foregroundStyle(.secondary)
                .padding(14)
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}
```

- [ ] **Step 3: Verify build and test manually**

```bash
cd menubar && make build && open build/Build/Products/Release/SessionSearch.app
```

Expected: magnifying glass in menu bar, click opens popover with search field. Type a query and see results from indexed sessions.

- [ ] **Step 4: Commit**

```bash
git add menubar/Sources/PopoverView.swift menubar/Sources/SettingsView.swift
git commit -m "feat: search popover with results, click-to-copy, double-click-to-open"
```

---

### Task 9: SettingsView -- Flag Presets + Index Info

**Files:**
- Modify: `menubar/Sources/SettingsView.swift` -- full implementation

- [ ] **Step 1: Replace `menubar/Sources/SettingsView.swift`**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let store: SessionStore
    let onBack: () -> Void

    @State private var newFlag = ""
    @State private var isAddingFlag = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(14)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    flagPresetsSection
                    indexSection
                    refreshSection
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13))
                    .foregroundStyle(.accentColor)
            }
            .buttonStyle(.plain)
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
    }

    // MARK: - Flag Presets

    private var flagPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FLAG PRESETS")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(settings.flagPresets.enumerated()), id: \.element.id) { index, preset in
                    HStack {
                        Text(preset.flag)
                            .font(.system(size: 12, design: .monospaced))

                        Spacer()

                        Button(action: {
                            settings.flagPresets.remove(at: index)
                            settings.save()
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Toggle("", isOn: Binding(
                            get: { settings.flagPresets[index].enabled },
                            set: { settings.flagPresets[index].enabled = $0; settings.save() }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < settings.flagPresets.count - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            if isAddingFlag {
                HStack(spacing: 8) {
                    TextField("--flag-name", text: $newFlag)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit { addFlag() }
                    Button("Add") { addFlag() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.accentColor)
                    Button("Cancel") { isAddingFlag = false; newFlag = "" }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            } else {
                Button(action: { isAddingFlag = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                            .foregroundStyle(.accentColor)
                        Text("Add flag preset...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Index

    private var indexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INDEX")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let stats = try? store.stats() {
                        Text("\(stats.projectCount) projects \u{00B7} \(stats.sessionCount) sessions")
                            .font(.system(size: 12))
                    }
                }
                Spacer()
                Button("Rebuild") {
                    let projectsDir = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".claude/projects").path
                    Task.detached { [store] in
                        try? store.indexAll(projectsDir: projectsDir)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.accentColor)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
    }

    // MARK: - Refresh Interval

    private var refreshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REFRESH INTERVAL")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { settings.refreshIntervalMinutes },
                set: { settings.refreshIntervalMinutes = $0; settings.save() }
            )) {
                Text("Every 5 minutes").tag(5)
                Text("Every 10 minutes").tag(10)
                Text("Every 15 minutes").tag(15)
                Text("Every 30 minutes").tag(30)
            }
            .pickerStyle(.menu)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
    }

    // MARK: - Helpers

    private func addFlag() {
        let trimmed = newFlag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settings.flagPresets.append(FlagPreset(flag: trimmed, enabled: false))
        settings.save()
        newFlag = ""
        isAddingFlag = false
    }
}
```

- [ ] **Step 2: Verify build and test manually**

```bash
cd menubar && make build && open build/Build/Products/Release/SessionSearch.app
```

Expected: gear icon opens settings with flag presets (add/remove/toggle), index stats with rebuild button, and refresh interval picker.

- [ ] **Step 3: Commit**

```bash
git add menubar/Sources/SettingsView.swift
git commit -m "feat: settings view with flag presets, index info, and refresh interval"
```

---

### Task 10: Install Scripts -- LaunchAgent + Makefile Polish

**Files:**
- Create: `menubar/scripts/install-login-item.sh`

- [ ] **Step 1: Create `menubar/scripts/install-login-item.sh`**

```bash
#!/bin/bash
# Install SessionSearch as a login item via LaunchAgent.
# Ad-hoc signed apps can't use SMAppService.mainApp.register(), so we install
# a plist directly.

set -euo pipefail

LABEL="com.neonwatty.SessionSearch"
APP_PATH="${HOME}/Applications/SessionSearch.app"
EXEC_PATH="${APP_PATH}/Contents/MacOS/SessionSearch"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [ ! -x "${EXEC_PATH}" ]; then
  echo "error: ${EXEC_PATH} not found or not executable" >&2
  echo "run 'make install' first" >&2
  exit 1
fi

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "${PLIST_PATH}" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${EXEC_PATH}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
PLISTEOF

pkill -x SessionSearch 2>/dev/null || true

launchctl unload "${PLIST_PATH}" 2>/dev/null || true
launchctl load "${PLIST_PATH}"

echo "installed LaunchAgent: ${PLIST_PATH}"
echo "SessionSearch will launch at login."
echo "to uninstall: launchctl unload \"${PLIST_PATH}\" && rm \"${PLIST_PATH}\""
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x menubar/scripts/install-login-item.sh
```

- [ ] **Step 3: Verify full install flow**

```bash
cd menubar && make install
```

Expected: app installed at `~/Applications/SessionSearch.app` and opens with menu bar icon.

- [ ] **Step 4: Commit**

```bash
git add menubar/scripts/install-login-item.sh
git commit -m "feat: LaunchAgent install script for login auto-start"
```

---

### Task 11: Final Wiring -- End-to-End Verification

**Files:**
- No new files -- verification only

- [ ] **Step 1: Run full test suite**

```bash
cd menubar && make test
```

Expected: all tests pass.

- [ ] **Step 2: Clean install and verify**

```bash
cd menubar && make clean && make install
```

Expected: fresh build, app installs, menu bar icon appears.

- [ ] **Step 3: End-to-end manual test**

1. Click magnifying glass icon -- popover opens, search field focused
2. Type "playwright" -- results appear with snippets
3. Click a result -- command copied to clipboard, "Copied!" toast
4. Double-click a result -- Terminal opens and runs `claude --resume <id>`
5. Click gear -- settings view with flag presets
6. Add a flag preset, toggle it on, go back -- "1 flag active" shown, command preview includes flag
7. Click gear -- rebuild index -- stats update

- [ ] **Step 4: Commit any fixes from manual testing**

- [ ] **Step 5: Push to remote**

```bash
git push origin main
```
