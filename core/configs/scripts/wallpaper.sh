#!/usr/bin/env bash
# ==============================================================================
# Unified Wallpaper Synchronization: Desktop (PCManFM-Qt / Hyprpaper) + ReGreet
# ==============================================================================

set -euo pipefail

WALLPAPER="${1:-}"

if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    echo "Usage: $(basename "$0") /path/to/wallpaper.image"
    exit 1
fi

WALLPAPER="$(realpath "$WALLPAPER")"

# 1. Update PCManFM-Qt live desktop surface & persistent config
if command -v pcmanfm-qt &>/dev/null; then
    pcmanfm-qt -w "${WALLPAPER}" --wallpaper-mode=zoom 2>/dev/null || true
    
    PCMANFM_CONF="${HOME}/.config/pcmanfm-qt/default/settings.conf"
    mkdir -p "$(dirname "$PCMANFM_CONF")"
    if [[ -f "$PCMANFM_CONF" ]]; then
        if grep -q "^Wallpaper=" "$PCMANFM_CONF"; then
            sed -i "s|^Wallpaper=.*|Wallpaper=${WALLPAPER}|" "$PCMANFM_CONF"
        else
            sed -i "/^\[Desktop\]/a Wallpaper=${WALLPAPER}" "$PCMANFM_CONF"
        fi
        if grep -q "^WallpaperMode=" "$PCMANFM_CONF"; then
            sed -i "s|^WallpaperMode=.*|WallpaperMode=zoom|" "$PCMANFM_CONF"
        else
            sed -i "/^\[Desktop\]/a WallpaperMode=zoom" "$PCMANFM_CONF"
        fi
    fi
fi

# 2. Update hyprpaper configuration
HYPR_CONF="${HOME}/.config/hypr/hyprpaper.conf"
if [[ -f "$HYPR_CONF" ]]; then
    cat > "$HYPR_CONF" << EOF
ipc = on
preload = ${WALLPAPER}
wallpaper = ,${WALLPAPER}
EOF
fi

# 3. Synchronize to system ReGreet / greetd background
if [[ -w /usr/share/backgrounds/default.jpg ]]; then
    cp -f "${WALLPAPER}" /usr/share/backgrounds/default.jpg 2>/dev/null || true
elif sudo -n true 2>/dev/null; then
    sudo mkdir -p /usr/share/backgrounds /etc/greetd
    sudo cp -f "${WALLPAPER}" /usr/share/backgrounds/default.jpg 2>/dev/null || true
    sudo cp -f "${WALLPAPER}" /etc/greetd/wallpaper.png 2>/dev/null || true
fi

echo "Wallpaper successfully synchronized: ${WALLPAPER}"
