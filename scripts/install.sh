#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL_DIR="$HOME/.codex/notifications"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/CodexAlerts.app"
APP_INSTALL_DIR="$INSTALL_DIR/CodexAlerts.app"
WATCHER_LABEL="com.codex-app-mac-alerts.sound-watcher"
TOGGLE_LABEL="com.codex-app-mac-alerts.menu-toggle"
WATCHER_PLIST="$LAUNCH_AGENT_DIR/$WATCHER_LABEL.plist"
TOGGLE_PLIST="$LAUNCH_AGENT_DIR/$TOGGLE_LABEL.plist"
USER_ID=$(id -u)
MODULE_CACHE="/private/tmp/codex-app-mac-alerts-module-cache"

if [ ! -d /Applications/Codex.app ]; then
  echo "Codex Desktop was not found at /Applications/Codex.app" >&2
  exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc was not found. Install Xcode Command Line Tools first: xcode-select --install" >&2
  exit 1
fi

if [ ! -x /usr/bin/python3 ]; then
  echo "/usr/bin/python3 was not found." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$LAUNCH_AGENT_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$MODULE_CACHE"

cp "$ROOT_DIR/resources/CodexAlerts-Info.plist" "$APP_DIR/Contents/Info.plist"
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" swiftc "$ROOT_DIR/src/CodexAlerts.swift" -o "$APP_DIR/Contents/MacOS/CodexAlerts" -framework AppKit
cp "$ROOT_DIR/src/codex_app_sound_watcher.py" "$INSTALL_DIR/codex_app_sound_watcher.py"
rm -rf "$APP_INSTALL_DIR"
ditto "$APP_DIR" "$APP_INSTALL_DIR"

if [ ! -f "$INSTALL_DIR/alerts_enabled" ]; then
  printf '1\n' > "$INSTALL_DIR/alerts_enabled"
fi

cat > "$WATCHER_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$WATCHER_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$INSTALL_DIR/codex_app_sound_watcher.py</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$INSTALL_DIR/codex_app_sound_watcher.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$INSTALL_DIR/codex_app_sound_watcher.stderr.log</string>
</dict>
</plist>
EOF

cat > "$TOGGLE_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$TOGGLE_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP_INSTALL_DIR/Contents/MacOS/CodexAlerts</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$INSTALL_DIR/codex_alerts_toggle.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$INSTALL_DIR/codex_alerts_toggle.stderr.log</string>
</dict>
</plist>
EOF

chmod 700 "$INSTALL_DIR" "$INSTALL_DIR/codex_app_sound_watcher.py" "$APP_INSTALL_DIR/Contents/MacOS/CodexAlerts"
chmod 600 "$INSTALL_DIR/alerts_enabled"
touch "$INSTALL_DIR/codex_app_sound_watcher.log" \
  "$INSTALL_DIR/codex_app_sound_watcher.stdout.log" \
  "$INSTALL_DIR/codex_app_sound_watcher.stderr.log" \
  "$INSTALL_DIR/codex_alerts_toggle.stdout.log" \
  "$INSTALL_DIR/codex_alerts_toggle.stderr.log"
chmod 600 "$INSTALL_DIR"/*.log

launchctl bootout "gui/$USER_ID" "$WATCHER_PLIST" >/dev/null 2>&1 || true
launchctl bootout "gui/$USER_ID" "$TOGGLE_PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$USER_ID" "$WATCHER_PLIST"
launchctl bootstrap "gui/$USER_ID" "$TOGGLE_PLIST"
launchctl kickstart -k "gui/$USER_ID/$WATCHER_LABEL"
launchctl kickstart -k "gui/$USER_ID/$TOGGLE_LABEL"

echo "Installed Codex app mac alerts."
echo "Alerts are enabled. Open Codex Desktop to see the menu bar toggle."
