# Session Search

A macOS menu bar app for full-text searching [Claude Code](https://docs.anthropic.com/en/docs/claude-code) session history with one-click terminal resumption.

Claude Code's built-in `/resume` picker searches session metadata (name, branch, first prompt) but not conversation content. Session Search brings full-text search to the menu bar — find any past session by a keyword discussed mid-conversation.

## Features

- **Full-text search** over all Claude Code sessions via SQLite FTS5
- **Keyword highlighting** in search result snippets
- **One-click resume** — double-click a result to open `claude --resume` in your terminal
- **Terminal choice** — use Terminal.app, iTerm2, or Ghostty (configurable in Settings)
- **Flag presets** — configure CLI flags (e.g. `--verbose`, `--dangerously-skip-permissions`) that are appended to every resume command
- **Keyboard navigation** — arrow keys to browse results, Enter to open the selected session
- **Automatic indexing** — scans `~/.claude/projects/` on launch and periodically (configurable interval)
- **Copy to clipboard** — use the copy button or Cmd+C on the selected result to copy the full resume command

## Requirements

- macOS 13.0+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed (sessions live in `~/.claude/projects/`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for building from source)

## Install

```bash
cd menubar
make install
```

This builds a Release configuration and copies `SessionSearch.app` to `~/Applications/`. On first launch, the app appears as an orange Claude icon in your menu bar.

To start on login:

```bash
make install-login
```

## Usage

Click the menu bar icon to open the search popover. Type a keyword to search across all your Claude Code sessions. Results show the project name, relative timestamp, and a snippet with your keyword highlighted.

- **Single-click** a result to select it and preview the resume command
- **Copy** with the copy button or Cmd+C
- **Open** with Enter, double-click, or the open button

### Settings

Click the gear icon to access settings:

| Section | Description |
|---------|-------------|
| **Terminal** | Choose your terminal app: Terminal.app (default), iTerm2, or Ghostty (requires 1.3.0+) |
| **Flag Presets** | Add CLI flags that are appended to every resume command. Toggle individual flags on/off. |
| **Index** | View project/session counts. Click "Rebuild" to re-index all sessions immediately. |
| **Refresh Interval** | How often the app re-scans for new sessions (5, 10, 15, or 30 minutes). |

### Terminal Support

Session Search uses AppleScript to launch sessions in your preferred terminal:

| Terminal | macOS API | Notes |
|----------|-----------|-------|
| **Terminal.app** | `do script` | Built-in, works out of the box |
| **iTerm2** | `create window` / `write text` | Requires iTerm2 installed |
| **Ghostty** | `new window` / `input text` | Requires Ghostty 1.3.0+ with AppleScript enabled (on by default) |

If the selected terminal is not installed or Automation permission is denied, the error is logged to the system log (`SessionSearch:` prefix).

## Development

```bash
cd menubar

# Generate Xcode project (requires xcodegen)
make generate

# Build
make build

# Run tests
make test

# Clean build artifacts
make clean
```

### Architecture

Three layers in a single native SwiftUI app:

1. **Indexer** (`SessionIndexer.swift`) — scans `~/.claude/projects/*/` for `.jsonl` session files, parses user/assistant messages, upserts into SQLite FTS5
2. **Search Engine** (`SessionStore.swift`) — thin wrapper around FTS5 queries with prefix matching and `snippet()` for keyword-in-context extraction
3. **UI** (`PopoverView.swift`, `SettingsView.swift`) — NSStatusItem with NSPopover, search field with debounced queries, keyboard navigation

Data is stored in:
- **Index:** `~/Library/Application Support/SessionSearch/index.db`
- **Settings:** `~/Library/Application Support/SessionSearch/settings.json`

## License

Copyright 2026 Jeremy Watt
