#!/usr/bin/env bash
# ==============================================================================
# Wayfire Keyboard Layout Manager & Waybar Indicator
# Supports US / Arabic toggling and status reporting
# ==============================================================================

set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/wayfire_current_layout"

get_layout() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "US"
    fi
}

toggle_layout() {
    local current
    current=$(get_layout)
    if [[ "$current" == "US" ]]; then
        echo "AR" > "$STATE_FILE"
        if command -v notify-send &>/dev/null; then
            notify-send -t 1500 -h string:x-canonical-private-synchronous:layout "Keyboard Layout" "Switched to: Arabic (العربية)" || true
        fi
    else
        echo "US" > "$STATE_FILE"
        if command -v notify-send &>/dev/null; then
            notify-send -t 1500 -h string:x-canonical-private-synchronous:layout "Keyboard Layout" "Switched to: English (US)" || true
        fi
    fi

    # Trigger layout group switch via wtype if available
    if command -v wtype &>/dev/null; then
        wtype -M alt -k shift_l -m alt 2>/dev/null || true
    fi
}

case "${1:-get}" in
    get)
        get_layout
        ;;
    toggle)
        toggle_layout
        ;;
    *)
        echo "Usage: $0 {get|toggle}"
        exit 1
        ;;
esac
