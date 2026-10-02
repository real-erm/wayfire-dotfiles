#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    up)
        brightnessctl set 5%+ 2>/dev/null || true
        ;;
    down)
        brightnessctl set 5%- 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 {up|down}"
        exit 1
        ;;
esac

BRI=$(brightnessctl get 2>/dev/null || echo 0)
MAX=$(brightnessctl max 2>/dev/null || echo 1)
if (( MAX > 0 )); then
    PCT=$(( BRI * 100 / MAX ))
else
    PCT=0
fi

if command -v notify-send &>/dev/null; then
    notify-send -t 1500 -h string:x-canonical-private-synchronous:brightness "Brightness" "${PCT}%" || true
fi
