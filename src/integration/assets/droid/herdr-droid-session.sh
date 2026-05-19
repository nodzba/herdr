#!/bin/sh
# installed by herdr
# safe to edit. this hook only activates inside herdr-managed panes.
# HERDR_INTEGRATION_ID=droid
# HERDR_INTEGRATION_VERSION=1

set -eu

hook_input_file="$(mktemp "${TMPDIR:-/tmp}/herdr-droid-hook.XXXXXX")" || exit 0
trap 'rm -f "$hook_input_file"' EXIT HUP INT TERM
cat >"$hook_input_file" 2>/dev/null || true

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_SOCKET_PATH:-}" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

HERDR_HOOK_INPUT_FILE="$hook_input_file" python3 - <<'PY'
import json
import os
import socket
import time

pane_id = os.environ.get("HERDR_PANE_ID")
socket_path = os.environ.get("HERDR_SOCKET_PATH")
hook_input_file = os.environ.get("HERDR_HOOK_INPUT_FILE")

if not pane_id or not socket_path:
    raise SystemExit(0)

hook_input = {}
if hook_input_file:
    try:
        with open(hook_input_file, encoding="utf-8") as handle:
            content = handle.read()
        if content.strip():
            hook_input = json.loads(content)
    except Exception:
        hook_input = {}

event = hook_input.get("hook_event_name", "")
session_id = hook_input.get("session_id", "")

if event == "SessionStart" and session_id:
    request = {
        "id": f"herdr:droid:{int(time.time() * 1000)}",
        "method": "pane.set_droid_session",
        "params": {
            "pane_id": pane_id,
            "session_id": session_id,
        },
    }
elif event == "SessionEnd":
    request = {
        "id": f"herdr:droid:{int(time.time() * 1000)}",
        "method": "pane.set_droid_session",
        "params": {
            "pane_id": pane_id,
            "session_id": "",
        },
    }
else:
    raise SystemExit(0)

try:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(0.5)
    client.connect(socket_path)
    client.sendall((json.dumps(request) + "\n").encode())
    try:
        client.recv(4096)
    except Exception:
        pass
    client.close()
except Exception:
    pass
PY
