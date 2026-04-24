#!/bin/bash
# Install SessionSearch as a login item via LaunchAgent.
# Ad-hoc signed apps can't use SMAppService.mainApp.register(), so we install
# a plist directly.

set -euo pipefail

LABEL="com.neonwatty.SessionSearch"
APP_PATH="${HOME}/Applications/SessionSearch.app"
EXEC_PATH="${APP_PATH}/Contents/MacOS/SessionSearch"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [ ! -x "${EXEC_PATH}" ]; then
  echo "error: ${EXEC_PATH} not found or not executable" >&2
  echo "run 'make install' first" >&2
  exit 1
fi

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "${PLIST_PATH}" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${EXEC_PATH}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
PLISTEOF

pkill -x SessionSearch 2>/dev/null || true

launchctl unload "${PLIST_PATH}" 2>/dev/null || true
launchctl load "${PLIST_PATH}"

echo "installed LaunchAgent: ${PLIST_PATH}"
echo "SessionSearch will launch at login."
echo "to uninstall: launchctl unload \"${PLIST_PATH}\" && rm \"${PLIST_PATH}\""
