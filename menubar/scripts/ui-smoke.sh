#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/Build/Products/Release/SessionSearch.app}"
APP_EXEC="$APP_PATH/Contents/MacOS/SessionSearch"

if [[ ! -x "$APP_EXEC" ]]; then
  echo "SessionSearch executable not found at $APP_EXEC" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/session-search-ui-smoke.XXXXXX")"
PROJECTS_DIR="$TEMP_DIR/projects"
DB_PATH="$TEMP_DIR/index.db"
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

mkdir -p "$PROJECTS_DIR/-Smoke-Alpha" "$PROJECTS_DIR/-Smoke-Beta"
cat >"$PROJECTS_DIR/-Smoke-Alpha/smoke-alpha.jsonl" <<'JSON'
{"type":"user","sessionId":"smoke-alpha","timestamp":"2026-04-29T12:00:00Z","cwd":"/tmp/smoke-alpha","message":{"content":"Alpha project has a playwright smoke issue for the UI harness."}}
JSON
cat >"$PROJECTS_DIR/-Smoke-Beta/smoke-beta.jsonl" <<'JSON'
{"type":"user","sessionId":"smoke-beta","timestamp":"2026-04-29T12:00:00Z","cwd":"/tmp/smoke-beta","message":{"content":"Beta project has unrelated session content."}}
JSON

SESSION_SEARCH_UI_TESTING=1 \
SESSION_SEARCH_SMOKE_WINDOW=1 \
SESSION_SEARCH_DISABLE_INDEX_TIMER=1 \
SESSION_SEARCH_DB_PATH="$DB_PATH" \
SESSION_SEARCH_PROJECTS_DIR="$PROJECTS_DIR" \
  "$APP_EXEC" >/tmp/session-search-ui-smoke.log 2>&1 &

osascript <<'APPLESCRIPT' >/dev/null
on waitForWindow()
  repeat 80 times
    tell application "System Events"
      if exists process "SessionSearch" then
        tell process "SessionSearch"
          if exists window "Session Search Smoke" then return true
        end tell
      end if
    end tell
    delay 0.1
  end repeat
  error "Session Search smoke window did not appear"
end waitForWindow

on assertStaticTextContaining(expectedText)
  tell application "System Events"
    tell process "SessionSearch"
      if my elementContainsStaticText(window "Session Search Smoke", expectedText) then return true
    end tell
  end tell
  error "Expected visible text containing: " & expectedText
end assertStaticTextContaining

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

waitForWindow()
tell application "System Events"
  tell process "SessionSearch"
    set frontmost to true
    if not my focusFirstTextField(window "Session Search Smoke") then error "Search field not found"
    keystroke "playwright"
  end tell
end tell
delay 1
assertStaticTextContaining("Alpha")
assertStaticTextContaining("indexed")

tell application "System Events"
  tell process "SessionSearch"
    if not my focusFirstTextField(window "Session Search Smoke") then error "Search field not found"
    keystroke "a" using command down
    keystroke "* | ()"
  end tell
end tell
delay 1
assertStaticTextContaining("No results")
APPLESCRIPT

echo "UI smoke passed"
