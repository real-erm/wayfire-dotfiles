#!/usr/bin/env bash
# ==============================================================================
# Arch Linux Production Post-Install Setup Suite (Modular Entrypoint)
# Compositor: Wayfire (Wayland Desktop Environment)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER="${USER:-$(id -un)}"
HOME="${HOME:-$(getent passwd "$USER" | cut -d: -f6)}"

# ------------------------------------------------------------------------------
# Terminal Color Palette & Styling
# ------------------------------------------------------------------------------
declare -r COLOR_RESET="\033[0m"
declare -r COLOR_BOLD="\033[1m"
declare -r COLOR_RED="\033[1;31m"
declare -r COLOR_GREEN="\033[1;32m"
declare -r COLOR_YELLOW="\033[1;33m"
declare -r COLOR_BLUE="\033[1;34m"
declare -r COLOR_MAGENTA="\033[1;35m"
declare -r COLOR_CYAN="\033[1;36m"
declare -r COLOR_WHITE="\033[1;37m"

# ------------------------------------------------------------------------------
# Logging & Diagnostic Functions
# ------------------------------------------------------------------------------
log_info() {
    printf "${COLOR_BLUE}[INFO]${COLOR_RESET} %s\n" "$*"
}

log_step() {
    printf "\n${COLOR_CYAN}${COLOR_BOLD}==> %s${COLOR_RESET}\n" "$*"
}

log_success() {
    printf "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} %s\n" "$*"
}

log_warn() {
    printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} %s\n" "$*" >&2
}

log_error() {
    printf "${COLOR_RED}[ERROR]${COLOR_RESET} %s\n" "$*" >&2
}

# ------------------------------------------------------------------------------
# Process Management & Dynamic Cleanup Hooks
# ------------------------------------------------------------------------------
SUDO_PID=""
declare -a CLEANUP_PATHS=()

cleanup() {
    local exit_code=$?

    # Terminate background sudo keep-alive daemon
    if [[ -n "${SUDO_PID:-}" ]] && kill -0 "$SUDO_PID" 2>/dev/null; then
        kill "$SUDO_PID" 2>/dev/null || true
    fi

    # Clean tracked dynamic temporary files and directories safely
    if (( ${#CLEANUP_PATHS[@]} > 0 )); then
        for path in "${CLEANUP_PATHS[@]}"; do
            if [[ -n "$path" && -e "$path" ]]; then
                rm -rf "$path" 2>/dev/null || sudo rm -rf "$path" 2>/dev/null || true
            fi
        done
    fi

    if [[ $exit_code -ne 0 ]]; then
        printf "\n${COLOR_RED}${COLOR_BOLD}Pipeline failed at line %s with exit code %s.${COLOR_RESET}\n" \
            "${BASH_LINENO[0]}" "$exit_code" >&2
    fi
}
trap cleanup EXIT INT TERM ERR

# ------------------------------------------------------------------------------
# Startup Banner
# ------------------------------------------------------------------------------
display_banner() {
    printf "${COLOR_CYAN}${COLOR_BOLD}"
    cat << 'EOF'
 ▐██  ▐██ ▐██████ ▐██ ▐██ ▐██████ ▐██ ▐██████ ▐██████      ▐██████ ▐██████ ▐██████ ▐██████ ▐██ ▐██    ▐██████ ▐██████      ▐█████▄ ▐██ ▐██      ▐██████ ▐██████ ▐██  ▐██
▐██  ▐██ ▐██ ▐██ ▐██ ▐██ ▐██     ▐██ ▐██ ▐██ ▐██          ▐██ ▐██ ▐██ ▐██   ▐██   ▐██     ▐██ ▐██    ▐██     ▐██          ▐██  ▐█ ▐██ ▐██      ▐██     ▐██ ▐██ ▐███▐███
▐██  ▐██ ▐██████ ▐██████ ▐████   ▐██ ▐██████ ▐████        ▐██  ▐█ ▐██ ▐██   ▐██   ▐████   ▐██ ▐██    ▐████   ▐██████      ▐██████ ▐██████      ▐████   ▐██████ ▐██▐█▐██
▐██▐█▐██ ▐██ ▐██   ▐██   ▐██     ▐██ ▐██▐██  ▐██          ▐██ ▐██ ▐██ ▐██   ▐██   ▐██     ▐██ ▐██    ▐██         ▐██      ▐██  ▐█   ▐██        ▐██     ▐██▐██  ▐██  ▐██
 ▐█████  ▐██ ▐██   ▐██   ▐██     ▐██ ▐██ ▐██ ▐██████      ▐██████ ▐██████   ▐██   ▐██     ▐██ ▐█████ ▐██████ ▐██████      ▐█████▀   ▐██        ▐██████ ▐██ ▐██ ▐██  ▐██
EOF
    printf "${COLOR_RESET}\n"
    printf "${COLOR_WHITE}${COLOR_BOLD}        :: ARCH LINUX AUTOMATED POST-INSTALLATION & WAYFIRE SUITE ::        ${COLOR_RESET}\n\n"
}

# ------------------------------------------------------------------------------
# Privilege Safety Validation
# ------------------------------------------------------------------------------
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script MUST NOT be executed directly as root."
        log_error "Please run as a regular user with sudo privileges: ./main.sh"
        exit 1
    fi

    log_info "Verifying sudo permissions for user '${USER}'..."
    if ! sudo -v; then
        log_error "User '${USER}' does not possess valid sudo privileges. Aborting."
        exit 1
    fi

    # Maintain sudo credential cache in the background
    (while true; do sudo -n true; sleep 45; kill -0 "$$" || exit; done 2>/dev/null) &
    SUDO_PID=$!
    log_success "Sudo privileges confirmed and keep-alive daemon initiated."
}

# ------------------------------------------------------------------------------
# Interactive Confirmation Prompt
# ------------------------------------------------------------------------------
confirm_execution() {
    printf "${COLOR_WHITE}System Profile:${COLOR_RESET}\n"
    printf "  - Target User : ${COLOR_GREEN}%s${COLOR_RESET}\n" "$USER"
    printf "  - Kernel      : %s\n" "$(uname -r)"
    printf "  - Architecture: %s\n" "$(uname -m)"
    printf "  - Hostname    : %s\n\n" "$(uname -n)"

    read -rp "Proceed with the automated installation pipeline? [y/N]: " confirmation
    case "${confirmation,,}" in
        y|yes)
            log_info "User confirmed. Launching post-install pipeline..."
            ;;
        *)
            log_warn "Execution cancelled by user."
            exit 0
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Full System Upgrade Routine
# ------------------------------------------------------------------------------
perform_system_upgrade() {
    local phase="$1"
    log_step "Executing Full System Upgrade (${phase})"
    log_info "Synchronizing databases and upgrading all packages via paru -Syu --noconfirm..."
    if command -v paru &>/dev/null; then
        paru -Syu --noconfirm
    else
        sudo pacman -Syu --noconfirm
    fi
    log_success "Full system upgrade (${phase}) completed successfully."
}

# ------------------------------------------------------------------------------
# Source Modular Subsystems
# ------------------------------------------------------------------------------
source "${SCRIPT_DIR}/core/repos.sh"
source "${SCRIPT_DIR}/core/packages.sh"
source "${SCRIPT_DIR}/core/services.sh"
source "${SCRIPT_DIR}/core/dotfiles.sh"
source "${SCRIPT_DIR}/extras/browser.sh"
source "${SCRIPT_DIR}/postinstall/display_summary.sh"

# ------------------------------------------------------------------------------
# Master Orchestration
# ------------------------------------------------------------------------------
main() {
    display_banner
    check_privileges
    confirm_execution

    # Step 1: Toolchain & AUR Helper (paru)
    build_paru_helper

    # Step 2: Microarchitecture & Repository Configuration (ALHP, BlackArch)
    configure_repositories

    # Step 3: Verify Repository Synchronization
    verify_repository_sync

    # Full System Upgrade #1: Post-Repository Setup
    perform_system_upgrade "Post-Repository Configuration"

    # Step 4: Core System Packages & Shell Configuration
    install_system_packages

    # Step 5: Extras (Web Browser Selection & Installation)
    install_browser_extras

    # Step 6: System Services, Display Manager & Wayland Environment
    configure_system_services

    # Step 7: Core Dotfiles & Wallpaper Deployment
    deploy_core_dotfiles

    # Full System Upgrade #2: Script Finale
    perform_system_upgrade "Final System Upgrade"

    printf "\n"
    log_success "================================================================="
    log_success " Arch Linux Automated Post-Installation Pipeline Finished!       "
    log_success " Wayfire Compositor & Desktop Suite Ready for First Login.       "
    log_success "================================================================="

    # Step 8: Display Post-Install Manual Checklist
    display_postinstall_instructions

    printf "\n${COLOR_YELLOW}Recommendation: Reboot your system now via 'sudo reboot'.${COLOR_RESET}\n"
}

main "$@"
