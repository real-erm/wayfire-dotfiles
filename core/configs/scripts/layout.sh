#!/usr/bin/env bash
# ==============================================================================
# Wayfire Keyboard Layout Manager & Waybar Indicator
# Native Wayfire IPC integration (US / Arabic layout detection & toggling)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/wf-kbd"
if [[ ! -x "$BIN" ]] && [[ -x "${HOME}/.config/wayfire/scripts/wf-kbd" ]]; then
    BIN="${HOME}/.config/wayfire/scripts/wf-kbd"
fi

get_layout_ipc() {
    if [[ -x "$BIN" ]]; then
        "$BIN"
        return
    fi

    # Python IPC fallback
    python3 -c "
import socket, struct, json, glob, sys, os
runtime = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
socks = glob.glob(f'{runtime}/wayfire-*.socket')
if not socks:
    print('US')
    sys.exit(0)
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(socks[0])
    msg = b'{\"method\": \"wayfire/get-keyboard-state\"}'
    s.sendall(struct.pack('<I', len(msg)) + msg)
    resp_len = struct.unpack('<I', s.recv(4))[0]
    data = json.loads(s.recv(resp_len).decode('utf-8'))
    idx = data.get('layout-index', 0)
    print('AR' if idx == 1 else 'US')
except Exception:
    print('US')
"
}

toggle_layout_ipc() {
    if [[ -x "$BIN" ]]; then
        "$BIN" toggle
        return
    fi

    # Python IPC fallback
    python3 -c "
import socket, struct, json, glob, sys, os, subprocess
runtime = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
socks = glob.glob(f'{runtime}/wayfire-*.socket')
if not socks:
    sys.exit(0)
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(socks[0])
    msg = b'{\"method\": \"wayfire/get-keyboard-state\"}'
    s.sendall(struct.pack('<I', len(msg)) + msg)
    resp_len = struct.unpack('<I', s.recv(4))[0]
    data = json.loads(s.recv(resp_len).decode('utf-8'))
    curr_idx = data.get('layout-index', 0)
    next_idx = 1 if curr_idx == 0 else 0

    t_msg = json.dumps({'method': 'wayfire/set-keyboard-state', 'data': {'layout-index': next_idx}}).encode('utf-8')
    s.sendall(struct.pack('<I', len(t_msg)) + t_msg)
    resp_len = struct.unpack('<I', s.recv(4))[0]
    s.recv(resp_len)
    s.close()

    label = 'Arabic (العربية)' if next_idx == 1 else 'English (US)'
    subprocess.run(['notify-send', '-t', '1200', '-h', 'string:x-canonical-private-synchronous:layout', 'Keyboard Layout', f'Switched to: {label}'], check=False)
    subprocess.run(['pkill', '-RTMIN+8', 'waybar'], check=False)
    print('AR' if next_idx == 1 else 'US')
except Exception:
    pass
"
}

case "${1:-get}" in
    get)
        get_layout_ipc
        ;;
    toggle)
        toggle_layout_ipc
        ;;
    *)
        echo "Usage: $0 {get|toggle}"
        exit 1
        ;;
esac
