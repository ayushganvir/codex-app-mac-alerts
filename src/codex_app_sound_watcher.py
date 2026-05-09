#!/usr/bin/env python3
import glob
import json
import os
import subprocess
import threading
import time
from pathlib import Path

HOME = Path.home()
SESSIONS_DIR = HOME / ".codex" / "sessions"
NOTIFICATIONS_DIR = HOME / ".codex" / "notifications"
STATE_PATH = NOTIFICATIONS_DIR / "codex_app_sound_watcher.state.json"
LOG_PATH = NOTIFICATIONS_DIR / "codex_app_sound_watcher.log"
ENABLED_PATH = NOTIFICATIONS_DIR / "alerts_enabled"

SOUNDS = {
    "end": "/System/Library/Sounds/Glass.aiff",
    "permission": "/System/Library/Sounds/Basso.aiff",
}

PERMISSION_REPEAT_SECONDS = 5
MAX_REPEAT_SECONDS = 120
POLL_SECONDS = 1.0
SESSION_RESCAN_SECONDS = 5.0

state_lock = threading.Lock()
state = {
    "permission_loop": False,
    "permission_loop_started_at": 0.0,
    "pending_permissions": set(),
}


def log(message):
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a") as handle:
            handle.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")
    except Exception:
        pass


def alerts_enabled():
    try:
        return ENABLED_PATH.read_text().strip() != "0"
    except FileNotFoundError:
        return True
    except Exception:
        return True


def play(sound_key):
    if not alerts_enabled():
        stop_waiting_loops()
        return

    path = SOUNDS[sound_key]
    subprocess.Popen(
        ["/usr/bin/afplay", path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def repeat_loop(flag_name, sound_key, interval):
    started_at_key = f"{flag_name}_started_at"
    while True:
        with state_lock:
            enabled = state[flag_name]
            started_at = state[started_at_key]

        if enabled and time.monotonic() - started_at >= MAX_REPEAT_SECONDS:
            with state_lock:
                state[flag_name] = False
                if flag_name == "permission_loop":
                    state["pending_permissions"].clear()
            log(f"{flag_name} stopped after {MAX_REPEAT_SECONDS} seconds")
        elif enabled and alerts_enabled():
            play(sound_key)
        elif enabled:
            stop_waiting_loops()

        time.sleep(interval)


def stop_waiting_loops():
    with state_lock:
        state["permission_loop"] = False
        state["permission_loop_started_at"] = 0.0
        state["pending_permissions"].clear()


def handle_start():
    if not alerts_enabled():
        stop_waiting_loops()
    else:
        stop_waiting_loops()


def play_end_once():
    if not alerts_enabled():
        stop_waiting_loops()
        return

    stop_waiting_loops()
    play("end")


def start_permission_loop(call_id=None):
    if not alerts_enabled():
        stop_waiting_loops()
        return

    with state_lock:
        state["permission_loop"] = True
        if not state["permission_loop_started_at"]:
            state["permission_loop_started_at"] = time.monotonic()
        if call_id:
            state["pending_permissions"].add(call_id)

    play("permission")


def resolve_permission(call_id=None):
    with state_lock:
        if call_id:
            state["pending_permissions"].discard(call_id)
        if not state["pending_permissions"]:
            state["permission_loop"] = False
            state["permission_loop_started_at"] = 0.0


def latest_session_files(limit=20):
    files = glob.glob(str(SESSIONS_DIR / "**" / "*.jsonl"), recursive=True)
    files.sort(key=lambda item: os.path.getmtime(item), reverse=True)
    return files[:limit]


def load_offsets():
    if not STATE_PATH.exists():
        return {}
    try:
        with STATE_PATH.open() as handle:
            raw = json.load(handle)
        return {path: int(offset) for path, offset in raw.get("offsets", {}).items()}
    except Exception:
        return {}


def save_offsets(offsets):
    tmp = STATE_PATH.with_suffix(".tmp")
    payload = {"offsets": offsets}
    with tmp.open("w") as handle:
        json.dump(payload, handle)
    tmp.replace(STATE_PATH)


def is_permission_request(payload):
    name = payload.get("name", "")
    args = payload.get("arguments", "")

    if name in {"request_user_input", "request_plugin_install"}:
        return True
    if "sandbox_permissions" in args and "require_escalated" in args:
        return True
    if "justification" in args and "Do you want" in args:
        return True

    return False


def handle_event(event):
    payload = event.get("payload") or {}
    event_type = event.get("type")
    payload_type = payload.get("type")

    if not alerts_enabled():
        stop_waiting_loops()
        return

    if event_type == "event_msg" and payload_type in {"task_started", "user_message"}:
        handle_start()
        log(f"start event: {payload_type}")
        return

    if event_type == "event_msg" and payload_type == "task_complete":
        play_end_once()
        log("end event: task_complete")
        return

    if event_type == "event_msg" and payload_type in {"turn_aborted", "thread_rolled_back"}:
        stop_waiting_loops()
        log(f"stop event: {payload_type}")
        return

    if event_type == "response_item" and payload_type == "function_call":
        if is_permission_request(payload):
            start_permission_loop(payload.get("call_id"))
            log(f"permission wait started: {payload.get('name')} {payload.get('call_id')}")
        return

    if event_type == "response_item" and payload_type == "function_call_output":
        resolve_permission(payload.get("call_id"))


def read_new_events(path, offsets):
    last_offset = offsets.get(path, 0)
    try:
        size = os.path.getsize(path)
    except OSError:
        return False

    if size < last_offset:
        last_offset = 0
    if size == last_offset:
        return False

    with open(path, "r", encoding="utf-8") as handle:
        handle.seek(last_offset)
        for line in handle:
            try:
                handle_event(json.loads(line))
            except Exception as exc:
                log(f"parse error in {path}: {exc}")
        offsets[path] = handle.tell()

    return True


def main():
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not ENABLED_PATH.exists():
        ENABLED_PATH.write_text("1\n")

    offsets = load_offsets()

    # Start from the end of existing files so installation does not replay old alerts.
    if not offsets:
        for path in latest_session_files(limit=100):
            try:
                offsets[path] = os.path.getsize(path)
            except OSError:
                pass
        save_offsets(offsets)

    threading.Thread(
        target=repeat_loop,
        args=("permission_loop", "permission", PERMISSION_REPEAT_SECONDS),
        daemon=True,
    ).start()

    log("watcher started")
    watched_files = latest_session_files()
    next_rescan_at = 0.0

    while True:
        now = time.monotonic()
        if now >= next_rescan_at:
            watched_files = latest_session_files()
            next_rescan_at = now + SESSION_RESCAN_SECONDS

        changed = False
        for path in watched_files:
            changed = read_new_events(path, offsets) or changed

        if changed:
            save_offsets(offsets)

        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
