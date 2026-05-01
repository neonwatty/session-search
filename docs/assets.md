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

Generate deterministic smoke-window GIFs:

```bash
cd menubar
make demo-gif
```

The command writes:

- `docs/assets/session-search-demo.gif`

The landing page demo is currently based on a real desktop recording rather than the deterministic smoke window. To refresh it from a local recording:

```bash
ffmpeg -y -i ~/Desktop/session-search.mp4 -an \
  -vf "fps=30,scale=960:-2:flags=lanczos" \
  -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
  -crf 25 -preset slow -movflags +faststart \
  docs/assets/session-search-demo.mp4

ffmpeg -y -i ~/Desktop/session-search.mp4 \
  -vf "fps=8,scale=760:-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=160[p];[s1][p]paletteuse=dither=sierra2_4a" \
  -loop 0 docs/assets/session-search-demo.gif

ffmpeg -y -ss 3.5 -i ~/Desktop/session-search.mp4 -frames:v 1 \
  -vf "scale=960:-2:flags=lanczos" -q:v 3 \
  docs/assets/session-search-demo-poster.jpg
```

The commands write:

- `docs/assets/session-search-demo.mp4`
- `docs/assets/session-search-demo.gif`
- `docs/assets/session-search-demo-poster.jpg`

macOS may require Screen Recording and Accessibility permissions for the terminal app running the command. If permissions are changed, rerun the command after restarting the terminal.

## Usage

Use the generated screenshots for:

- GitHub Pages landing page media.
- README screenshots.
- Demo GIFs for the landing page.
- Release notes.
- Social posts and launch threads.

Review each image before publishing to confirm no private local data is visible.
