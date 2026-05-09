#!/usr/bin/env python3
import json
import time
from datetime import datetime, timezone
from pathlib import Path

SESSION_DIR = Path.home() / ".codex" / "sessions" / "sound-test"
SESSION_PATH = SESSION_DIR / "permission-alert-test.jsonl"
CALL_ID = "codex-sound-test-permission"


def timestamp():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def append_event(event):
    SESSION_DIR.mkdir(parents=True, exist_ok=True)
    with SESSION_PATH.open("a") as handle:
        handle.write(json.dumps(event) + "\n")


append_event({
    "timestamp": timestamp(),
    "type": "response_item",
    "payload": {
        "type": "function_call",
        "name": "request_user_input",
        "call_id": CALL_ID,
        "arguments": "{}",
    },
})

print("Permission alert test started. You should hear the permission sound now and again every 5 seconds.")
time.sleep(12)

append_event({
    "timestamp": timestamp(),
    "type": "response_item",
    "payload": {
        "type": "function_call_output",
        "call_id": CALL_ID,
        "output": "resolved",
    },
})

print("Permission alert test resolved. The repeated sound should stop.")
