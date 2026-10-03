#!/usr/bin/env bash
# ==============================================================================
# Wayfire macOS Frosted Glass Power Menu (wlogout)
# ==============================================================================

set -euo pipefail

# If wlogout is currently open, toggle it off
if pgrep -x wlogout &>/dev/null; then
    killall wlogout 2>/dev/null || true
    exit 0
fi

# Detect display geometry dynamically
read -r screen_w screen_h < <(python3 -c "
import socket, struct, json, glob, sys, os
runtime = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
socks = glob.glob(f'{runtime}/wayfire-*.socket')
w, h = 1280, 1024
if socks:
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(socks[0])
        msg = json.dumps({'method': 'window-rules/list-outputs'}).encode('utf-8')
        s.sendall(struct.pack('<I', len(msg)) + msg)
        resp_len = struct.unpack('<I', s.recv(4))[0]
        data = json.loads(s.recv(resp_len).decode('utf-8'))
        if data and isinstance(data, list) and len(data) > 0:
            geom = data[0].get('geometry', {})
            w = int(geom.get('width', 1280))
            h = int(geom.get('height', 1024))
    except Exception:
        pass
print(f'{w} {h}')
")

# Target button geometry (macOS squircles: ~115px wide x ~124px high)
# 6 buttons with 14px column spacing -> total menu width ~ 760px
menu_w=760
menu_h=124

margin_x=$(( (screen_w - menu_w) / 2 ))
margin_y=$(( (screen_h - menu_h) / 2 ))

# Fallback bounds check
(( margin_x < 50 )) && margin_x=50
(( margin_y < 50 )) && margin_y=50

# Launch wlogout with calculated margins for perfect macOS squircle proportions
if command -v wlogout &>/dev/null; then
    exec wlogout -b 6 -c 14 -r 0 -T "$margin_y" -B "$margin_y" -L "$margin_x" -R "$margin_x"
fi

# Fallback dialog if wlogout is unavailable
if command -v yad &>/dev/null; then
    action=$(yad --entry --title="Power Menu" --text="Choose an action:" \
        --entry-text="Lock" "Log Out" "Sleep" "Hibernate" "Restart" "Shut Down" 2>/dev/null || true)
    case "$action" in
        "Lock") hyprlock ;;
        "Log Out") wayfiremsg exit 2>/dev/null || killall wayfire 2>/dev/null || true ;;
        "Sleep") systemctl suspend ;;
        "Hibernate") systemctl hibernate ;;
        "Restart") systemctl reboot ;;
        "Shut Down") systemctl poweroff ;;
    esac
fi
