#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/Build/Products/Release/SessionSearch.app}"
APP_EXEC="$APP_PATH/Contents/MacOS/SessionSearch"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASSET_DIR="$ROOT_DIR/docs/assets"
WINDOW_TITLE="${SESSION_SEARCH_MARKETING_WINDOW_TITLE:-Session Search}"
export SESSION_SEARCH_CAPTURE_WINDOW_TITLE="$WINDOW_TITLE"

if [[ ! -x "$APP_EXEC" ]]; then
  echo "SessionSearch executable not found at $APP_EXEC" >&2
  exit 1
fi

mkdir -p "$ASSET_DIR"

TEMP_DIR="${TMPDIR:-/tmp}/ssm-assets"
PROJECTS_DIR="$TEMP_DIR/projects"
DB_PATH="$TEMP_DIR/index.db"
EMPTY_PROJECTS_DIR="$TEMP_DIR/empty-projects"
EMPTY_DB_PATH="$TEMP_DIR/empty-index.db"
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
mkdir -p "$PROJECTS_DIR/MarketingSearch" "$PROJECTS_DIR/MarketingDocs" "$EMPTY_PROJECTS_DIR"
cat >"$PROJECTS_DIR/MarketingSearch/session-search.jsonl" <<'JSON'
{"type":"user","sessionId":"marketing-search","timestamp":"2026-04-29T12:00:00Z","cwd":"/tmp/session-search-demo","message":{"content":"Investigate the playwright smoke issue in the UI harness and keep the screenshot flow deterministic."}}
JSON
cat >"$PROJECTS_DIR/MarketingDocs/session-docs.jsonl" <<'JSON'
{"type":"user","sessionId":"marketing-docs","timestamp":"2026-04-28T16:30:00Z","cwd":"/tmp/session-docs-demo","message":{"content":"Draft documentation for the local-first index diagnostics and the playwright smoke coverage."}}
JSON

capture_window() {
  local output="$1"
  local rect
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
  sleep 0.2
  rect="$(osascript <<'APPLESCRIPT' | tr -d '[:space:]' | sed -E 's/,+/,/g; s/^,//; s/,$//'
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
)"
  if [[ ! "$rect" =~ ^-?[0-9]+,-?[0-9]+,[0-9]+,[0-9]+$ ]]; then
    echo "Could not resolve Session Search Smoke window rectangle: $rect" >&2
    exit 1
  fi
  screencapture -x -R "$rect" "$output"
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

open_settings() {
  osascript <<'APPLESCRIPT' >/dev/null
tell application "System Events"
  tell process "SessionSearch"
    set frontmost to true
    set windowTitle to system attribute "SESSION_SEARCH_CAPTURE_WINDOW_TITLE"
    set windowPosition to position of window windowTitle
    set windowSize to size of window windowTitle
    set x to (item 1 of windowPosition) + (item 1 of windowSize) - 28
    set y to (item 2 of windowPosition) + 52
    click at {x, y}
  end tell
end tell
APPLESCRIPT
}

launch_app() {
  local projects_dir="$1"
  local db_path="$2"
  SESSION_SEARCH_UI_TESTING=1 \
  SESSION_SEARCH_SMOKE_WINDOW=1 \
  SESSION_SEARCH_SMOKE_WINDOW_TITLE="$WINDOW_TITLE" \
  SESSION_SEARCH_DISABLE_INDEX_TIMER=1 \
  SESSION_SEARCH_DB_PATH="$db_path" \
  SESSION_SEARCH_PROJECTS_DIR="$projects_dir" \
    "$APP_EXEC" >/tmp/session-search-marketing-assets.log 2>&1 &
}

launch_app "$PROJECTS_DIR" "$DB_PATH"
wait_for_text "SESSION SEARCH"
focus_search_field
osascript -e 'tell application "System Events" to tell process "SessionSearch" to keystroke "harness"' >/dev/null
wait_for_text "session-search-demo"
capture_window "$ASSET_DIR/session-search-results.png"

open_settings
wait_for_text "Settings"
capture_window "$ASSET_DIR/session-search-settings.png"

osascript -e 'tell application "SessionSearch" to quit' >/dev/null 2>&1 || true
sleep 1

launch_app "$EMPTY_PROJECTS_DIR" "$EMPTY_DB_PATH"
wait_for_text "No Claude session files found"
capture_window "$ASSET_DIR/session-search-empty-state.png"

echo "Captured marketing assets in $ASSET_DIR"
