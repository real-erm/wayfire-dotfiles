#!/usr/bin/env bash
# ==============================================================================
# Wayfire Clean Modern Power Menu (wlogout)
# ==============================================================================

set -euo pipefail

# If wlogout is currently open, toggle it off
if pgrep -x wlogout &>/dev/null; then
    killall wlogout 2>/dev/null || true
    exit 0
fi

# Launch wlogout if available
if command -v wlogout &>/dev/null; then
    exec wlogout -b 6 -c 16 -r 16 -m 320
fi

# Clean Zenity / Yad fallback if wlogout is unavailable
if command -v yad &>/dev/null; then
    action=$(yad --entry --title="Power Menu" --text="Choose an action:" \
        --entry-text="Lock" "Logout" "Suspend" "Reboot" "Shutdown" 2>/dev/null || true)
    case "$action" in
        "Lock") hyprlock ;;
        "Logout") wayfiremsg exit 2>/dev/null || killall wayfire 2>/dev/null || true ;;
        "Suspend") systemctl suspend ;;
        "Reboot") systemctl reboot ;;
        "Shutdown") systemctl poweroff ;;
    esac
fi
