#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/Build/Products/Release/SessionSearch.app}"
APP_EXEC="$APP_PATH/Contents/MacOS/SessionSearch"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASSET_DIR="$ROOT_DIR/docs/assets"
OUTPUT_GIF="$ASSET_DIR/session-search-demo.gif"
WINDOW_TITLE="${SESSION_SEARCH_MARKETING_WINDOW_TITLE:-Session Search}"
export SESSION_SEARCH_CAPTURE_WINDOW_TITLE="$WINDOW_TITLE"

if [[ ! -x "$APP_EXEC" ]]; then
  echo "SessionSearch executable not found at $APP_EXEC" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to generate the demo GIF" >&2
  exit 1
fi

mkdir -p "$ASSET_DIR"

TEMP_DIR="/tmp/ssm-demo-gif"
PROJECTS_DIR="$TEMP_DIR/projects"
DB_PATH="$TEMP_DIR/index.db"
FRAMES_DIR="$TEMP_DIR/frames"
WAS_RUNNING=0

cleanup() {
  osascript -e 'tell application "SessionSearch" to quit' >/dev/null 2>&1 || true
  rm -rf "$TEMP_DIR"
  if [[ "$WAS_RUNNING" == "1" && -d "$HOME/Applications/SessionSearch.app" ]]; then
    open "$HOME/Applications/SessionSearch.app" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if pgrep -x SessionSearch >/dev/null 2>&1; then
  WAS_RUNNING=1
  osascript -e 'tell application "SessionSearch" to quit' >/dev/null 2>&1 || true
  sleep 1
  pkill -x SessionSearch >/dev/null 2>&1 || true
fi

rm -rf "$TEMP_DIR"
mkdir -p "$PROJECTS_DIR/MarketingSearch" "$PROJECTS_DIR/MarketingDocs" "$FRAMES_DIR"
cat >"$PROJECTS_DIR/MarketingSearch/session-search.jsonl" <<'JSON'
{"type":"user","sessionId":"marketing-search","timestamp":"2026-04-29T12:00:00Z","cwd":"/tmp/session-search-demo","message":{"content":"Investigate the playwright smoke issue in the UI harness and keep the screenshot flow deterministic."}}
JSON
cat >"$PROJECTS_DIR/MarketingDocs/session-docs.jsonl" <<'JSON'
{"type":"user","sessionId":"marketing-docs","timestamp":"2026-04-28T16:30:00Z","cwd":"/tmp/session-docs-demo","message":{"content":"Draft documentation for the local-first index diagnostics and release smoke coverage."}}
JSON

window_rect() {
  osascript <<'APPLESCRIPT' | tr -d '[:space:]' | sed -E 's/,+/,/g; s/^,//; s/,$//'
tell application "System Events"
  tell process "SessionSearch"
    set windowTitle to system attribute "SESSION_SEARCH_CAPTURE_WINDOW_TITLE"
    set windowPosition to position of window windowTitle
    set windowSize to size of window windowTitle
    set x to item 1 of windowPosition
    set y to item 2 of windowPosition
    set w to item 1 of windowSize
    set h to item 2 of windowSize
    return (x as integer) & "," & (y as integer) & "," & (w as integer) & "," & (h as integer)
  end tell
end tell
APPLESCRIPT
}

raise_window() {
  osascript <<'APPLESCRIPT' >/dev/null
tell application "SessionSearch" to activate
tell application "System Events"
  tell process "SessionSearch"
    set frontmost to true
    set windowTitle to system attribute "SESSION_SEARCH_CAPTURE_WINDOW_TITLE"
    perform action "AXRaise" of window windowTitle
  end tell
end tell
APPLESCRIPT
}

capture_frame() {
  local frame="$1"
  local rect
  raise_window
  sleep 0.08
  rect="$(window_rect)"
  if [[ ! "$rect" =~ ^-?[0-9]+,-?[0-9]+,[0-9]+,[0-9]+$ ]]; then
    echo "Could not resolve Session Search window rectangle: $rect" >&2
    exit 1
  fi
  screencapture -x -R "$rect" "$FRAMES_DIR/frame-$(printf '%03d' "$frame").png"
}

wait_for_text() {
  local expected="$1"
  EXPECTED_TEXT="$expected" osascript <<'APPLESCRIPT' >/dev/null
set expectedText to system attribute "EXPECTED_TEXT"

on elementContainsStaticText(elementRef, expectedText)
  tell application "System Events"
    try
      if role of elementRef is "AXStaticText" then
        if (value of elementRef as text) contains expectedText then return true
      end if
    end try
    try
      repeat with childRef in UI elements of elementRef
        if my elementContainsStaticText(childRef, expectedText) then return true
      end repeat
    end try
  end tell
  return false
end elementContainsStaticText

repeat 80 times
  tell application "System Events"
    if exists process "SessionSearch" then
      tell process "SessionSearch"
        set windowTitle to system attribute "SESSION_SEARCH_CAPTURE_WINDOW_TITLE"
        if exists window windowTitle then
          if my elementContainsStaticText(window windowTitle, expectedText) then return true
        end if
      end tell
    end if
  end tell
  delay 0.1
end repeat

error "Expected visible text containing: " & expectedText
APPLESCRIPT
}

focus_search_field() {
  osascript <<'APPLESCRIPT' >/dev/null
on focusFirstTextField(elementRef)
  tell application "System Events"
    try
      if role of elementRef is "AXTextField" then
        perform action "AXPress" of elementRef
        set focused of elementRef to true
        return true
      end if
    end try
    try
      repeat with childRef in UI elements of elementRef
        if my focusFirstTextField(childRef) then return true
      end repeat
    end try
  end tell
  return false
end focusFirstTextField

tell application "System Events"
  tell process "SessionSearch"
    set frontmost to true
    set windowTitle to system attribute "SESSION_SEARCH_CAPTURE_WINDOW_TITLE"
    if not my focusFirstTextField(window windowTitle) then error "Search field not found"
  end tell
end tell
APPLESCRIPT
}

SESSION_SEARCH_UI_TESTING=1 \
SESSION_SEARCH_SMOKE_WINDOW=1 \
SESSION_SEARCH_SMOKE_WINDOW_TITLE="$WINDOW_TITLE" \
SESSION_SEARCH_DISABLE_INDEX_TIMER=1 \
SESSION_SEARCH_DB_PATH="$DB_PATH" \
SESSION_SEARCH_PROJECTS_DIR="$PROJECTS_DIR" \
  "$APP_EXEC" >/tmp/session-search-demo-gif.log 2>&1 &

wait_for_text "SESSION SEARCH"
focus_search_field

frame=1
capture_frame "$frame"
for char in p l a y w r i g h t; do
  osascript -e "tell application \"System Events\" to tell process \"SessionSearch\" to keystroke \"$char\"" >/dev/null
  sleep 0.12
  frame=$((frame + 1))
  capture_frame "$frame"
done

wait_for_text "session-search-demo"
for _ in 1 2 3 4 5 6; do
  frame=$((frame + 1))
  capture_frame "$frame"
done

ffmpeg -y \
  -framerate 5 \
  -i "$FRAMES_DIR/frame-%03d.png" \
  -vf "fps=10,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=192[p];[s1][p]paletteuse=dither=sierra2_4a" \
  -loop 0 \
  "$OUTPUT_GIF" >/tmp/session-search-demo-gif-ffmpeg.log 2>&1

echo "Captured demo GIF at $OUTPUT_GIF"
