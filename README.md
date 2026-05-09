# codex-app-mac-alerts

Mac menu bar toggle and sound alerts for the Codex Desktop app.

This project adds local-only alert sounds for Codex Desktop events:

- prompt starts silently and stops any active repeat alert
- prompt ends, playing once
- permission or user-action prompts, repeating every 5 seconds until resolved or 2 minutes pass
- a menu bar toggle that appears only while Codex is running

The installer is portable and does not contain user-specific paths. It installs into the current user's home directory.

## Requirements

- macOS
- Codex Desktop app installed at `/Applications/Codex.app`
- Xcode Command Line Tools, for `swiftc`
- Python 3 at `/usr/bin/python3`

Check Swift:

```sh
swiftc --version
```

## Install

From this repo:

```sh
./scripts/install.sh
```

The installer:

- compiles the menu bar helper app
- installs files under `~/.codex/notifications`
- installs LaunchAgents under `~/Library/LaunchAgents`
- starts the alert watcher and menu bar helper
- enables alerts by default

When Codex Desktop is open, a menu bar item appears:

- `Codex Alerts: On`
- `Codex Alerts: Off`

Click it to toggle all alert sounds.

## Test

Run:

```sh
./scripts/test-permission-alert.sh
```

You should hear the permission alert immediately and then every 5 seconds. The test resolves itself after about 12 seconds.

## Uninstall

```sh
./scripts/uninstall.sh
```

This stops and removes both LaunchAgents and deletes the installed helper files.

## Configuration

Edit these constants in `src/codex_app_sound_watcher.py` before reinstalling:

```py
PERMISSION_REPEAT_SECONDS = 5
MAX_REPEAT_SECONDS = 120
```

Default sounds:

```py
SOUNDS = {
    "end": "/System/Library/Sounds/Glass.aiff",
    "permission": "/System/Library/Sounds/Basso.aiff",
}
```

After changes, run:

```sh
./scripts/install.sh
```

## Security And Performance

This is a local helper only:

- no network calls
- no shell evaluation of Codex logs
- no access outside the current user's Codex session/log files
- fixed allowlisted sound paths
- installed files are restricted to the current user

Performance behavior:

- the menu bar helper listens for macOS app launch/quit notifications instead of polling
- the watcher scans for new session files every 5 seconds
- active session files are checked once per second
- state is written only when new Codex events are seen
- repeating permission alerts stop automatically after 2 minutes

Typical idle usage should be near `0.0%` CPU. The watcher uses a small Python process, and the menu bar helper is a small AppKit process.

## Files Installed

```text
~/.codex/notifications/codex_app_sound_watcher.py
~/.codex/notifications/CodexAlerts.app
~/.codex/notifications/alerts_enabled
~/Library/LaunchAgents/com.codex-app-mac-alerts.sound-watcher.plist
~/Library/LaunchAgents/com.codex-app-mac-alerts.menu-toggle.plist
```

## Notes

This does not modify the Codex Desktop app bundle. That keeps the setup resilient across Codex updates and avoids breaking app signing.
