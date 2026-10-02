#!/usr/bin/env bash
# ==============================================================================
# Post-Install Module: Display Manual Tasks and User Instructions
# ==============================================================================

set -euo pipefail

display_postinstall_instructions() {
    local instructions_file="${SCRIPT_DIR}/postinstall/instructions.txt"
    printf "\n"
    if [[ -f "$instructions_file" ]]; then
        printf "${COLOR_CYAN}${COLOR_BOLD}"
        cat "$instructions_file"
        printf "${COLOR_RESET}\n"
    else
        log_warn "Instructions file not found at ${instructions_file}."
    fi
}
