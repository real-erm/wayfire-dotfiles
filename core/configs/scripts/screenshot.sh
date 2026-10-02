#!/usr/bin/env bash
set -euo pipefail
SHOT_DIR="${HOME}/Pictures/Screenshots"
mkdir -p "$SHOT_DIR"
FILE="${SHOT_DIR}/screenshot_$(date +%Y%m%d_%H%M%S).png"

case "${1:-full}" in
    full)
        grim "$FILE"
        ;;
    area)
        # Handle slurp cancellation (Esc key) gracefully without throwing errors
        GEOM=$(slurp 2>/dev/null || true)
        if [[ -z "$GEOM" ]]; then
            exit 0
        fi
        if ! grim -g "$GEOM" "$FILE" 2>/dev/null; then
            exit 0
        fi
        ;;
    *)
        echo "Usage: $0 {full|area}"
        exit 1
        ;;
esac

wl-copy < "$FILE" 2>/dev/null || true
if command -v notify-send &>/dev/null; then
    notify-send "Screenshot Captured" "Saved to ${FILE} and copied to clipboard." -i "$FILE" || true
fi
