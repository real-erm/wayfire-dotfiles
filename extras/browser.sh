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
        printf "  [1] ${COLOR_GREEN}LibreWolf${COLOR_RESET} (Official Arch extra/librewolf - Privacy Hardened, Recommended)\n"
        printf "  [2] ${COLOR_CYAN}Brave Origin${COLOR_RESET} (AUR aur/brave-origin-bin - Minimalist, Debloated)\n"
        printf "  [3] Skip (Proceed without installing a browser)\n"
        read -rp "Enter choice [1-3] (default: 1): " user_choice
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
            browser_pkg="brave-origin-bin"
            desktop_entry="brave-browser.desktop"
            ;;
        3)
            log_info "Skipping web browser installation as selected."
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

    # Detect desktop entry if brave-origin installed with an alternative filename
    if [[ "$browser_pkg" == "brave-origin-bin" ]]; then
        local found_dt
        found_dt=$(ls /usr/share/applications/*brave*.desktop 2>/dev/null | head -n1 | xargs -n1 basename 2>/dev/null || true)
        if [[ -n "$found_dt" ]]; then
            desktop_entry="$found_dt"
        fi
    fi

    if [[ -n "$desktop_entry" ]] && command -v xdg-settings &>/dev/null; then
        log_info "Registering ${desktop_entry} as default XDG web browser..."
        xdg-settings set default-web-browser "$desktop_entry" 2>/dev/null || true
    fi

    log_success "Browser installation and configuration complete: ${browser_pkg}"
}
