# Marketing Kit

Reusable copy and asset guidance for Session Search.

## Positioning

Session Search is a lightweight macOS menu bar app for finding Claude Code sessions by conversation content. Claude Code's built-in search does not index enough of the transcript to reliably find old work, so Session Search uses a local SQLite FTS5 index and keeps deeper search one click away.

## One-Liner

Better Claude Code session search, from the macOS menu bar.

## Short Description

Claude Code's built-in search does not index enough to reliably find old conversations. Session Search uses a lightweight local SQLite FTS5 index, lives in the macOS menu bar, and lets you search by keyword, inspect the highlighted snippet, and resume the exact session.

## Longer Description

Claude Code's `/resume` picker is useful when you remember session metadata, but its built-in search does not index enough conversation content to be reliable when you only remember an error, command, implementation detail, filename, or decision. Session Search fills that gap with a lightweight local SQLite FTS5 index over transcripts under `~/.claude/projects/`, lives in the macOS menu bar, and opens the selected result with `claude --resume`.

## Key Messages

- Claude Code's built-in search misses too much conversation content; Session Search indexes local transcripts.
- Keep search one click away in the macOS menu bar.
- Stay lightweight: SQLite FTS5, local files, no hosted search backend.
- Resume the right session without hunting through old transcripts.
- Keep data local: transcripts, index, settings, and logs stay on your Mac.
- Use the terminal you already work in: Terminal.app, iTerm2, or Ghostty.

## Audience

- Claude Code users with many active or historical sessions.
- Developers who frequently return to earlier implementation discussions.
- Teams or solo builders who use Claude Code as a working memory for projects.

## Launch Post

I built Session Search, a small macOS menu bar app for searching Claude Code session history.

Claude Code's built-in search does not index enough to reliably find old work. I kept wanting to find sessions by something discussed mid-conversation: an error, command, filename, implementation detail, or decision.

Session Search uses a lightweight local SQLite FTS5 index, lives in the macOS menu bar, shows highlighted snippets, and resumes the selected session in Terminal.app, iTerm2, or Ghostty.

Download: https://github.com/neonwatty/session-search/releases/latest

## Short Social Post

Claude Code's built-in search does not index enough conversation content.

Session Search uses a lightweight local SQLite FTS5 index and puts better Claude Code session search in the macOS menu bar.

https://neonwatty.github.io/session-search/

## GitHub Release Blurb

Session Search is a local-first macOS menu bar app for finding and resuming Claude Code sessions by conversation content. It fills the gap left by Claude Code's built-in search with a lightweight SQLite FTS5 index and keeps full-text search one click away.

Download the notarized `SessionSearch.app` zip below, unzip it, and move the app to `~/Applications/`.

Requirements:
- macOS 13.0+
- Claude Code installed with sessions under `~/.claude/projects/`

## Screenshot Plan

Use real screenshots before posting publicly. Avoid mocked private project names or real transcript content.

Recommended assets:
- Search popover with highlighted snippet results.
- Command preview for a selected result.
- Settings view showing terminal selection, flag presets, and index stats.
- Empty or diagnostic state showing index status without private paths.
- Short GIF: type `playwright`, show highlighted results, and pause on the resume command preview.

Regenerate sanitized screenshots with:

```bash
cd menubar
make marketing-assets
```

See [assets.md](assets.md) for details.

The landing page social preview uses `docs/assets/session-search-social-card.png`, generated from the real screenshot asset.

## Privacy Copy

Session Search reads local Claude Code transcript files from `~/.claude/projects/`. It stores its searchable index, settings, and logs locally under `~/Library/Application Support/SessionSearch/`.

## Links

- Landing page: https://neonwatty.github.io/session-search/
- Latest release: https://github.com/neonwatty/session-search/releases/latest
- Repository: https://github.com/neonwatty/session-search
