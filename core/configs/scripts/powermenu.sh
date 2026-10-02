#!/usr/bin/env bash
# ==============================================================================
# Wayfire Clean Modern Power Menu (Rofi-Wayland & Systemd)
# ==============================================================================

set -euo pipefail

uptime_info=$(uptime -p 2>/dev/null | sed -e 's/up //g' || echo "active")

options="󰌾  Lock\n󰍃  Logout\n󰒲  Suspend\n󰑐  Reboot\n󰐥  Shutdown"

chosen=$(printf "$options" | rofi -dmenu \
    -p "Power (${uptime_info})" \
    -theme-str '
        window { width: 360px; height: 285px; border-radius: 14px; border: 2px solid #7aa2f7; background-color: #1a1b26; }
        mainbox { padding: 14px; background-color: #1a1b26; }
        inputbar { children: [prompt]; background-color: #1a1b26; margin: 0px 0px 10px 0px; }
        prompt { background-color: #7aa2f7; text-color: #1a1b26; font-weight: bold; padding: 6px 12px; border-radius: 6px; }
        listview { columns: 1; lines: 5; spacing: 6px; background-color: #1a1b26; }
        element { padding: 8px 14px; border-radius: 8px; background-color: #1a1b26; text-color: #c0caf5; font: "JetBrainsMono Nerd Font 11"; }
        element selected { background-color: #24283b; text-color: #7aa2f7; font-weight: bold; }
        element-text { background-color: inherit; text-color: inherit; }
    ' 2>/dev/null || true)

case "$chosen" in
    *"Lock"*)
        hyprlock
        ;;
    *"Logout"*)
        wayfiremsg exit 2>/dev/null || killall wayfire 2>/dev/null || true
        ;;
    *"Suspend"*)
        systemctl suspend
        ;;
    *"Reboot"*)
        systemctl reboot
        ;;
    *"Shutdown"*)
        systemctl poweroff
        ;;
esac
