#!/usr/bin/env bash
# ==============================================================================
# Wayfire Clipboard Management Utility (CopyQ / wl-clipboard + cliphist)
# ==============================================================================

set -euo pipefail

pick_clipboard() {
    # If CopyQ GUI client is running, toggle its main window or menu
    if command -v copyq &>/dev/null && copyq ping &>/dev/null; then
        copyq toggle 2>/dev/null || copyq menu 2>/dev/null || true
        return 0
    fi

    # Fallback to cliphist picker with available dmenu launcher
    local selected=""
    if command -v rofi &>/dev/null; then
        selected=$(cliphist list 2>/dev/null | rofi -dmenu -p "Clipboard" 2>/dev/null || true)
    elif command -v fuzzel &>/dev/null; then
        selected=$(cliphist list 2>/dev/null | fuzzel --dmenu -p "Clipboard: " 2>/dev/null || true)
    elif command -v wofi &>/dev/null; then
        selected=$(cliphist list 2>/dev/null | wofi --dmenu -p "Clipboard" 2>/dev/null || true)
    fi

    if [[ -n "$selected" ]]; then
        echo "$selected" | cliphist decode | wl-copy
        if command -v notify-send &>/dev/null; then
            notify-send -t 1500 -h string:x-canonical-private-synchronous:clipboard "Clipboard" "Copied item to clipboard." || true
        fi
    fi
}

wipe_clipboard() {
    if command -v copyq &>/dev/null && copyq ping &>/dev/null; then
        copyq wipe 2>/dev/null || true
    fi
    cliphist wipe 2>/dev/null || true
    wl-copy -c 2>/dev/null || true
    if command -v notify-send &>/dev/null; then
        notify-send -t 1500 -h string:x-canonical-private-synchronous:clipboard "Clipboard" "Clipboard history wiped." || true
    fi
}

case "${1:-pick}" in
    pick)
        pick_clipboard
        ;;
    wipe)
        wipe_clipboard
        ;;
    *)
        echo "Usage: $0 {pick|wipe}"
        exit 1
        ;;
esac
