#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/Build/Products/Release/SessionSearch.app}"
APP_EXEC="$APP_PATH/Contents/MacOS/SessionSearch"

if [[ ! -x "$APP_EXEC" ]]; then
  echo "SessionSearch executable not found at $APP_EXEC" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/session-search-app-smoke.XXXXXX")"
PROJECTS_DIR="$TEMP_DIR/projects"
DB_PATH="$TEMP_DIR/index.db"
CHECKER="$TEMP_DIR/check-index.swift"

cleanup() {
  if [[ -n "${APP_PID:-}" ]]; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$PROJECTS_DIR/-Smoke-Alpha" "$PROJECTS_DIR/-Smoke-Beta"
cat >"$PROJECTS_DIR/-Smoke-Alpha/smoke-alpha.jsonl" <<'JSON'
{"type":"user","sessionId":"smoke-alpha","timestamp":"2026-04-29T12:00:00Z","cwd":"/tmp/smoke-alpha","message":{"content":"Alpha project has a playwright smoke issue for the app harness."}}
{"type":"assistant","sessionId":"smoke-alpha","timestamp":"2026-04-29T12:01:00Z","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"cat package.json"}}]}}
JSON
cat >"$PROJECTS_DIR/-Smoke-Beta/smoke-beta.jsonl" <<'JSON'
{"type":"user","sessionId":"smoke-beta","timestamp":"2026-04-29T12:00:00Z","cwd":"/tmp/smoke-beta","message":{"content":"Beta project has unrelated session content."}}
JSON
cat >"$CHECKER" <<'SWIFT'
import Foundation
import SQLite3

let dbPath = CommandLine.arguments[1]
var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    exit(1)
}
defer { sqlite3_close_v2(db) }

func count(_ sql: String) -> Int? {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        return nil
    }
    defer { sqlite3_finalize(stmt) }
    guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
    return Int(sqlite3_column_int(stmt, 0))
}

let sessionCount = count("SELECT COUNT(*) FROM sessions")
let playwrightCount = count("SELECT COUNT(*) FROM session_content WHERE session_content MATCH 'playwright'")
let packageCount = count("SELECT COUNT(*) FROM session_content WHERE session_content MATCH 'package'")

if sessionCount == 2 && playwrightCount == 1 && packageCount == 1 {
    exit(0)
}
exit(1)
SWIFT

SESSION_SEARCH_UI_TESTING=1 \
SESSION_SEARCH_DISABLE_INDEX_TIMER=1 \
SESSION_SEARCH_DB_PATH="$DB_PATH" \
SESSION_SEARCH_PROJECTS_DIR="$PROJECTS_DIR" \
LLVM_PROFILE_FILE="$TEMP_DIR/default.profraw" \
  "$APP_EXEC" >/tmp/session-search-app-smoke.log 2>&1 &
APP_PID=$!

for _ in {1..80}; do
  if [[ -f "$DB_PATH" ]]; then
    if xcrun swift "$CHECKER" "$DB_PATH" >/dev/null 2>&1; then
      echo "App smoke passed"
      exit 0
    fi
  fi
  sleep 0.25
done

echo "App smoke failed" >&2
cat /tmp/session-search-app-smoke.log >&2 || true
exit 1
