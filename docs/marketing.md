# Marketing Kit

Reusable copy and asset guidance for Session Search.

## Positioning

Session Search is a macOS menu bar app that adds full-text search to Claude Code session history. It is built for developers who remember a detail from a prior Claude Code conversation, but not the session name, branch, or first prompt.

## One-Liner

Full-text search for Claude Code sessions, from the macOS menu bar.

## Short Description

Session Search indexes local Claude Code transcripts and lets you find past sessions by conversation content. Search by keyword, inspect the highlighted snippet, and resume the exact session in Terminal.app, iTerm2, or Ghostty.

## Longer Description

Claude Code's `/resume` picker is useful when you remember session metadata. Session Search fills the gap when you remember something discussed mid-conversation: an error, command, implementation detail, filename, or decision. The app runs from the macOS menu bar, indexes local transcripts under `~/.claude/projects/`, and opens the selected result with `claude --resume`.

## Key Messages

- Search the content of Claude Code sessions, not just metadata.
- Resume the right session without hunting through old transcripts.
- Keep data local: transcripts, index, settings, and logs stay on your Mac.
- Use the terminal you already work in: Terminal.app, iTerm2, or Ghostty.
- Diagnose indexing issues with visible counts, parse failures, and local logs.

## Audience

- Claude Code users with many active or historical sessions.
- Developers who frequently return to earlier implementation discussions.
- Teams or solo builders who use Claude Code as a working memory for projects.

## Launch Post

I built Session Search, a small macOS menu bar app for full-text searching Claude Code session history.

Claude Code's `/resume` picker is useful when you remember metadata, but I kept wanting to find sessions by something discussed mid-conversation: an error, command, filename, implementation detail, or decision.

Session Search indexes local Claude Code transcripts, shows highlighted snippets, and resumes the selected session in Terminal.app, iTerm2, or Ghostty.

Download: https://github.com/neonwatty/session-search/releases/latest

## Short Social Post

Session Search adds full-text search to Claude Code session history.

Find a past conversation by keyword, preview the matching snippet, and resume it from the macOS menu bar.

https://neonwatty.github.io/session-search/

## GitHub Release Blurb

Session Search is a local-first macOS menu bar app for finding and resuming Claude Code sessions by conversation content.

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
- Short GIF: open menu bar, search keyword, select result, press Enter, terminal opens.

Regenerate sanitized screenshots with:

```bash
cd menubar
make marketing-assets
```

See [assets.md](assets.md) for details.

## Privacy Copy

Session Search reads local Claude Code transcript files from `~/.claude/projects/`. It stores its searchable index, settings, and logs locally under `~/Library/Application Support/SessionSearch/`.

## Links

- Landing page: https://neonwatty.github.io/session-search/
- Latest release: https://github.com/neonwatty/session-search/releases/latest
- Repository: https://github.com/neonwatty/session-search
