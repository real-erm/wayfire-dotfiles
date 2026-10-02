#!/usr/bin/env bash
set -euo pipefail
SHOT_DIR="${HOME}/Pictures/Screenshots"
mkdir -p "$SHOT_DIR"
FILE="${SHOT_DIR}/screenshot_$(date +%Y%m%d_%H%M%S).png"

case "${1:-area}" in
    full)
        grim "$FILE"
        wl-copy < "$FILE" 2>/dev/null || true
        if command -v notify-send &>/dev/null; then
            notify-send -t 2000 -i "$FILE" "Screenshot Taken" "Full screen saved to ${FILE} and copied to clipboard." || true
        fi
        ;;
    area)
        # Handle slurp cancellation (Esc key) gracefully without throwing errors
        GEOM=$(slurp 2>/dev/null || true)
        if [[ -z "$GEOM" ]]; then
            exit 0
        fi
        if grim -g "$GEOM" "$FILE" 2>/dev/null; then
            wl-copy < "$FILE" 2>/dev/null || true
            if command -v notify-send &>/dev/null; then
                notify-send -t 2000 -i "$FILE" "Screenshot Taken" "Area saved to ${FILE} and copied to clipboard." || true
            fi
        fi
        ;;
    edit)
        GEOM=$(slurp 2>/dev/null || true)
        if [[ -z "$GEOM" ]]; then
            exit 0
        fi
        if command -v swappy &>/dev/null; then
            grim -g "$GEOM" - | swappy -f -
        else
            grim -g "$GEOM" "$FILE" 2>/dev/null || true
            wl-copy < "$FILE" 2>/dev/null || true
            if command -v notify-send &>/dev/null; then
                notify-send -t 2000 -i "$FILE" "Screenshot Taken" "Saved to ${FILE} and copied to clipboard." || true
            fi
        fi
        ;;
    gui)
        choice=$(printf "Area Screenshot\nFull Screenshot\nAnnotate / Edit Screenshot" | (rofi -dmenu -p "Screenshot" || fuzzel --dmenu -p "Screenshot: ") 2>/dev/null || true)
        case "$choice" in
            "Area Screenshot") "$0" area ;;
            "Full Screenshot") "$0" full ;;
            "Annotate / Edit Screenshot") "$0" edit ;;
        esac
        ;;
    *)
        echo "Usage: $0 {full|area|edit|gui}"
        exit 1
        ;;
esac
