#!/usr/bin/env bash
# ==============================================================================
# Extras Module: Web Browser Installation & Default Handler Setup
# ==============================================================================

set -euo pipefail

install_browser_extras() {
    log_step "EXTRAS: Web Browser Setup"

    local choice="1"
    if [[ -t 0 ]]; then
        printf "\n${COLOR_WHITE}Select Primary Web Browser to Install:${COLOR_RESET}\n"
        printf "  [1] ${COLOR_GREEN}LibreWolf${COLOR_RESET} (Official Arch [extra] - Privacy Hardened, Recommended)\n"
        printf "  [2] Firefox (Official Arch [extra])\n"
        printf "  [3] Chromium (Official Arch [extra])\n"
        printf "  [4] Skip browser installation\n"
        read -rp "Enter choice [1-4] (default: 1): " user_choice
        choice="${user_choice:-1}"
    fi

    local browser_pkg=""
    local desktop_entry=""

    case "$choice" in
        1)
            browser_pkg="librewolf"
            desktop_entry="librewolf.desktop"
            ;;
        2)
            browser_pkg="firefox"
            desktop_entry="firefox.desktop"
            ;;
        3)
            browser_pkg="chromium"
            desktop_entry="chromium.desktop"
            ;;
        4)
            log_info "Skipping web browser installation."
            return 0
            ;;
        *)
            log_warn "Invalid selection. Defaulting to LibreWolf."
            browser_pkg="librewolf"
            desktop_entry="librewolf.desktop"
            ;;
    esac

    log_info "Installing web browser: ${browser_pkg} via paru..."
    paru -S --needed --noconfirm "$browser_pkg"

    if [[ -n "$desktop_entry" ]] && command -v xdg-settings &>/dev/null; then
        log_info "Registering ${desktop_entry} as default XDG web browser..."
        xdg-settings set default-web-browser "$desktop_entry" 2>/dev/null || true
    fi

    log_success "Browser installation and configuration complete: ${browser_pkg}"
}
