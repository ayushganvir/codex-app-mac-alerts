#!/bin/sh
set -eu

INSTALL_DIR="$HOME/.codex/notifications"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
WATCHER_LABEL="com.codex-app-mac-alerts.sound-watcher"
TOGGLE_LABEL="com.codex-app-mac-alerts.menu-toggle"
WATCHER_PLIST="$LAUNCH_AGENT_DIR/$WATCHER_LABEL.plist"
TOGGLE_PLIST="$LAUNCH_AGENT_DIR/$TOGGLE_LABEL.plist"
USER_ID=$(id -u)

launchctl bootout "gui/$USER_ID" "$WATCHER_PLIST" >/dev/null 2>&1 || true
launchctl bootout "gui/$USER_ID" "$TOGGLE_PLIST" >/dev/null 2>&1 || true

rm -f "$WATCHER_PLIST" "$TOGGLE_PLIST"
rm -rf "$INSTALL_DIR/CodexAlerts.app"
rm -f "$INSTALL_DIR/codex_app_sound_watcher.py" \
  "$INSTALL_DIR/codex_app_sound_watcher.state.json" \
  "$INSTALL_DIR/codex_app_sound_watcher.log" \
  "$INSTALL_DIR/codex_app_sound_watcher.stdout.log" \
  "$INSTALL_DIR/codex_app_sound_watcher.stderr.log" \
  "$INSTALL_DIR/codex_alerts_toggle.stdout.log" \
  "$INSTALL_DIR/codex_alerts_toggle.stderr.log" \
  "$INSTALL_DIR/alerts_enabled"

echo "Uninstalled Codex app mac alerts."
