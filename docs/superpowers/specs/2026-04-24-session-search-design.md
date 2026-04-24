# Session Search — Design Spec

A macOS menu bar app for full-text searching Claude Code session history and resuming sessions.

## Problem

Claude Code's built-in `/resume` picker searches session metadata (name, branch, first prompt) but not conversation content. Finding a past session by a keyword discussed mid-conversation requires manually grepping JSONL files. This app brings full-text search to the menu bar for instant access.

## Architecture

Three layers in a single native SwiftUI menu bar app:

### 1. Indexer

Scans `~/.claude/projects/*/` on app launch and every N minutes (configurable, default 10). Parses `.jsonl` session files and upserts searchable content into a local SQLite FTS5 database.

- **Database location:** `~/Library/Application Support/SessionSearch/index.db`
- **Incremental indexing:** tracks `mtime` of each `.jsonl` file, skips unchanged files on re-index
- **Content extraction:** parses only `type: "user"` and `type: "assistant"` JSONL lines, extracts text content from `message.content` (handles both plain string and array-of-blocks formats)
- **Concatenation:** all text per session is concatenated into a single FTS5 row (simpler than per-message, FTS5 `snippet()` still works for highlighting)

### 2. Search Engine

Thin wrapper around SQLite FTS5 queries.

- Takes a search string, returns ranked results via FTS5 relevance scoring
- Uses FTS5 `snippet()` for keyword-in-context extraction with match highlighting
- Results capped at 20
- Query fires on every keystroke, debounced ~100ms

### 3. UI

NSStatusItem with an NSPopover (same pattern as FleetMenuBar). Two views sharing the same popover:

**Main View (search + results):**
- Magnifying glass SF Symbol in the menu bar (static, no dynamic state)
- Search field auto-focused when popover opens
- Results in "comfortable" density: project name, relative timestamp, 2-line snippet with keyword highlighting in gold
- Selected result gets a blue left-border accent
- Subtle "N flags active" indicator below search bar (not inline pills)
- Command preview at bottom showing full `claude --resume <id> [flags]` command
- Arrow keys navigate results, updating the command preview
- Footer shows result count and last-indexed timestamp

**Settings View (via gear icon):**
- Back arrow returns to main view
- Flag Presets section: toggle switches for each preset, add/remove presets
- Index section: project/session counts, last indexed time, manual "Rebuild" button
- Refresh Interval: configurable dropdown (default 10 minutes)

## Data Model

### SQLite Tables

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,           -- session UUID (from filename)
    project TEXT NOT NULL,         -- human-readable name (last path segment of project dir)
    project_path TEXT NOT NULL,    -- full project directory path
    session_name TEXT,             -- from /rename if set, NULL otherwise
    first_timestamp TEXT NOT NULL, -- ISO8601, from first message
    last_timestamp TEXT NOT NULL,  -- ISO8601, from last message
    cwd TEXT,                      -- working directory from session metadata
    message_count INTEGER NOT NULL,
    file_mtime REAL NOT NULL       -- mtime of .jsonl file at last index
);

CREATE VIRTUAL TABLE session_content USING fts5(
    session_id,
    content,
    tokenize='porter unicode61'
);
```

### Settings JSON

Stored at `~/Library/Application Support/SessionSearch/settings.json`:

```json
{
    "flagPresets": [
        { "flag": "--dangerously-skip-permissions", "enabled": true },
        { "flag": "--verbose", "enabled": false },
        { "flag": "--model opus", "enabled": false }
    ],
    "refreshIntervalMinutes": 10
}
```

## Interactions

| Action | Behavior |
|--------|----------|
| Click menu bar icon | Toggle popover, focus search field |
| Type in search field | FTS5 query (debounced 100ms), update results |
| Arrow keys | Navigate results, update command preview |
| Single-click result | Copy `claude --resume <id> [active flags]` to clipboard, show "Copied" toast |
| Double-click result | Open Terminal.app and run the command (via osascript, same as fleet) |
| Click gear icon | Switch popover to settings view |
| Click back arrow | Return to search view |

## JSONL Parsing

Each `.jsonl` file contains one JSON object per line. Relevant types:

- `type: "user"` — user messages. Text at `message.content` (string).
- `type: "assistant"` — assistant responses. Text at `message.content` (array of blocks, extract `text` from blocks where `type == "text"`).
- `type: "permission-mode"` — contains `sessionId`. First line of file.
- Metadata fields on message lines: `sessionId`, `timestamp`, `cwd`, `entrypoint`.

Session name (from `/rename`) is not stored in the JSONL — it comes from Claude Code's internal metadata. For MVP, `session_name` will be NULL; this can be enhanced later if Claude Code exposes the name in the transcript.

## Project Structure

```
session-search/
  menubar/
    project.yml                    -- xcodegen spec (source of truth)
    Sources/
      SessionSearchApp.swift       -- @main entry point
      AppDelegate.swift            -- creates StatusItemController on launch
      StatusItemController.swift   -- NSStatusItem + popover toggle
      PopoverView.swift            -- search field + results list
      SettingsView.swift           -- flag presets + index controls
      SessionStore.swift           -- SQLite FTS5 indexer + query engine
      SessionModel.swift           -- data types (Session, SearchResult)
      Settings.swift               -- flag presets persistence (JSON)
    Makefile
```

## Build & Install

Following fleet conventions:

- **Build toolchain:** xcodegen → xcodebuild
- **Signing:** ad-hoc (`CODE_SIGN_IDENTITY: "-"`)
- **App config:** `LSUIElement: true` (no dock icon), macOS 13.0+ deployment target
- **`make install`** — builds and copies to `~/Applications/SessionSearch.app`
- **`make install-login`** — writes LaunchAgent plist at `~/Library/LaunchAgents/com.neonwatty.SessionSearch.plist` and loads it (SMAppService silently fails for ad-hoc signed apps, so LaunchAgent is the supported path)
- **Repo:** standalone at `github.com/neonwatty/session-search`
- **Xcode project is gitignored** — `project.yml` is the source of truth, requires `brew install xcodegen`

## Out of Scope (MVP)

- Session names from `/rename` (not in JSONL transcripts)
- Multi-machine sync
- FSEvents file watching (periodic timer is sufficient)
- Filtering by project or date range (can add later)
- Indexing tool call content (user + assistant text is sufficient for search)
