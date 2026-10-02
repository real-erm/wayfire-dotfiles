#!/usr/bin/env bash
# ==============================================================================
# Wayfire / Waybar Power Menu Helper
# Toggles wlogout if active, or falls back to fuzzel dmenu
# ==============================================================================

set -euo pipefail

# 1. If wlogout is already running, toggle it off
if pidof wlogout &>/dev/null; then
    pkill -x wlogout 2>/dev/null || true
    exit 0
fi

# 2. Try wlogout if installed
if command -v wlogout &>/dev/null; then
    wlogout -b 4 -c 0 -r 0 -m 0 \
        --layout "${HOME}/.config/wlogout/layout" \
        --css "${HOME}/.config/wlogout/style.css" &
    exit 0
fi

# 3. Fallback to fuzzel dmenu overlay if wlogout is unavailable
if command -v fuzzel &>/dev/null; then
    chosen=$(printf "  Lock\n  Logout\n  Reboot\n  Shutdown\n  Suspend" | fuzzel --dmenu -p "Power: " -l 5 -w 18 2>/dev/null || true)
    case "$chosen" in
        *"Lock"*)
            hyprlock ;;
        *"Logout"*)
            wayfiremsg exit 2>/dev/null || killall wayfire 2>/dev/null || true ;;
        *"Reboot"*)
            systemctl reboot ;;
        *"Shutdown"*)
            systemctl poweroff ;;
        *"Suspend"*)
            systemctl suspend ;;
    esac
fi
