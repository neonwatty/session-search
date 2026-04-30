# Marketing Assets

Real screenshots for the landing page and launch materials are generated from the app's deterministic smoke-window mode. The fixture data is synthetic and does not use local Claude Code transcripts.

## Generate

```bash
cd menubar
make marketing-assets
```

The command writes:

- `docs/assets/session-search-results.png`
- `docs/assets/session-search-settings.png`
- `docs/assets/session-search-empty-state.png`

Generate the social preview card after the screenshots exist:

```bash
swift docs/scripts/generate-social-card.swift
```

The command writes:

- `docs/assets/session-search-social-card.png`

macOS may require Screen Recording and Accessibility permissions for the terminal app running the command. If permissions are changed, rerun the command after restarting the terminal.

## Usage

Use the generated screenshots for:

- GitHub Pages landing page media.
- README screenshots.
- Release notes.
- Social posts and launch threads.

Review each image before publishing to confirm no private local data is visible.
