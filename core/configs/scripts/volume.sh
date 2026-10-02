#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    up)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ 2>/dev/null || true
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null || true
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 {up|down|mute}"
        exit 1
        ;;
esac

VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2 * 100)}' || echo "0")
if command -v notify-send &>/dev/null; then
    notify-send -t 1500 -h string:x-canonical-private-synchronous:volume "Volume" "${VOL}%" || true
fi
