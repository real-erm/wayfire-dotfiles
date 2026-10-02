#!/usr/bin/env bash
# ==============================================================================
# Core Module: Repository & Microarchitecture Configuration
# ==============================================================================

set -euo pipefail

detect_microarch() {
    local ld_help=""
    if [[ -x /lib64/ld-linux-x86-64.so.2 ]]; then
        ld_help=$(/lib64/ld-linux-x86-64.so.2 --help 2>/dev/null || true)
    fi

    if echo "$ld_help" | grep -q "x86-64-v4 (supported"; then
        echo "v4"
    elif echo "$ld_help" | grep -q "x86-64-v3 (supported"; then
        echo "v3"
    elif echo "$ld_help" | grep -q "x86-64-v2 (supported"; then
        echo "v2"
    else
        # Fallback to /proc/cpuinfo flags
        local cpu_flags
        cpu_flags=$(grep -m1 '^flags' /proc/cpuinfo || true)
        if echo "$cpu_flags" | grep -qw 'avx512f' && echo "$cpu_flags" | grep -qw 'avx512bw' && echo "$cpu_flags" | grep -qw 'avx512vl'; then
            echo "v4"
        elif echo "$cpu_flags" | grep -qw 'avx2' && echo "$cpu_flags" | grep -qw 'bmi2' && echo "$cpu_flags" | grep -qw 'fma'; then
            echo "v3"
        elif echo "$cpu_flags" | grep -qw 'sse4_2' && echo "$cpu_flags" | grep -qw 'popcnt'; then
            echo "v2"
        else
            echo "v1"
        fi
    fi
}

configure_repositories() {
    log_step "STEP 2: Microarchitecture Detection & Repository Mirror Configuration"

    local march
    march=$(detect_microarch)
    log_info "Detected CPU Microarchitecture Level: x86-64-${march}"

    # 1. Synchronize package databases prior to invoking paru for keyrings
    log_info "Synchronizing pacman package databases before installing keyrings..."
    sudo pacman -Sy

    # 2. Build and install official ALHP keyring packages if microarchitecture > v1
    if [[ "$march" != "v1" ]]; then
        log_info "Installing ALHP keyrings/mirrorlist via paru from AUR for x86-64-${march}..."
        paru -S --needed --noconfirm alhp-keyring alhp-mirrorlist || log_warn "ALHP package install returned non-zero; verifying fallback mirrors."
        sudo pacman-key --populate alhp 2>/dev/null || true

        # Ensure /etc/pacman.d/alhp-mirrorlist exists with active servers
        if [[ ! -s /etc/pacman.d/alhp-mirrorlist ]]; then
            log_info "Creating default ALHP mirrorlist fallback in /etc/pacman.d/alhp-mirrorlist..."
            sudo mkdir -p /etc/pacman.d
            cat << 'EOF' | sudo tee /etc/pacman.d/alhp-mirrorlist >/dev/null
Server = https://alhp.bht-berlin.de/$repo/os/$arch
Server = https://mirror.cachyos.org/ALHP/$repo/os/$arch
EOF
        elif ! grep -q "^Server" /etc/pacman.d/alhp-mirrorlist; then
            log_info "Activating default ALHP mirror in /etc/pacman.d/alhp-mirrorlist..."
            sudo sed -i '0,/^#Server/s/^#//' /etc/pacman.d/alhp-mirrorlist
        fi
    fi

    # 3. Attempt BlackArch keyring and mirrorlist installation
    log_info "Attempting BlackArch keyring installation..."
    paru -S --needed --noconfirm blackarch-keyring blackarch-mirrorlist 2>/dev/null || true
    sudo pacman-key --populate blackarch 2>/dev/null || true

    if [[ ! -s /etc/pacman.d/blackarch-mirrorlist ]]; then
        log_info "Configuring default mirror in /etc/pacman.d/blackarch-mirrorlist..."
        echo "Server = https://blackarch.org/blackarch/\$repo/os/\$arch" | sudo tee /etc/pacman.d/blackarch-mirrorlist >/dev/null
    fi

    # Backup /etc/pacman.conf
    local backup_conf="/etc/pacman.conf.bak.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/pacman.conf "$backup_conf"
    log_info "Backup created at ${backup_conf}"

    # Build ALHP configuration block to inject ABOVE [core]
    local alhp_block=""
    if [[ "$march" != "v1" && -s /etc/pacman.d/alhp-mirrorlist ]]; then
        alhp_block="# ALHP (Arch Linux Hardened Packages - x86-64-${march})
[core-x86-64-${march}]
Include = /etc/pacman.d/alhp-mirrorlist

[extra-x86-64-${march}]
Include = /etc/pacman.d/alhp-mirrorlist"

        if grep -q "^\[multilib\]" /etc/pacman.conf; then
            alhp_block="${alhp_block}

[multilib-x86-64-${march}]
Include = /etc/pacman.d/alhp-mirrorlist"
        fi
    fi

    # Inject ALHP ABOVE [core] using secure mktemp and ENVIRON to prevent awk multiline escaping issues
    if [[ -n "$alhp_block" ]] && ! grep -q "core-x86-64-${march}" /etc/pacman.conf; then
        log_info "Injecting ALHP repositories ABOVE [core] in /etc/pacman.conf..."
        local tmp_conf
        tmp_conf=$(mktemp -p /tmp pacman.conf.XXXXXX)
        CLEANUP_PATHS+=("$tmp_conf")

        sudo env ALHP_BLOCK="$alhp_block" awk '
            !inserted && /^[[:space:]]*\[core\]/ {
                print ENVIRON["ALHP_BLOCK"] "\n"
                inserted = 1
            }
            { print }
        ' /etc/pacman.conf | sudo tee "$tmp_conf" >/dev/null

        sudo cp "$tmp_conf" /etc/pacman.conf
        rm -f "$tmp_conf"
    else
        log_info "ALHP repository entries already present or architecture is v1. Skipping injection."
    fi

    # Inject BlackArch repository only if blackarch keys/keyring are present to prevent pacman signature failures
    if sudo pacman-key --list-keys blackarch &>/dev/null || pacman -Q blackarch-keyring &>/dev/null; then
        if ! grep -q "^\[blackarch\]" /etc/pacman.conf; then
            log_info "Injecting BlackArch repository with 'Usage = Sync Search' into /etc/pacman.conf..."
            cat << 'EOF' | sudo tee -a /etc/pacman.conf >/dev/null

# BlackArch Linux Repository (Restricted to Sync & Search to avoid conflicts)
[blackarch]
Usage = Sync Search
Include = /etc/pacman.d/blackarch-mirrorlist
EOF
        else
            log_info "BlackArch repository entry already present in /etc/pacman.conf."
        fi
    else
        log_warn "BlackArch keyring not detected in pacman keyring. Skipping [blackarch] repository injection."
    fi

    log_success "Repository configuration and mirror injection completed."
}

verify_repository_sync() {
    log_step "STEP 3: Repository Synchronization Verification"

    log_info "Synchronizing pacman package databases (pacman -Sy)..."
    if sudo pacman -Sy; then
        log_success "Package databases synchronized successfully."
    else
        log_error "Repository synchronization failed."
        log_error "Check your network configuration, /etc/pacman.conf syntax, or pacman-key status."
        exit 1
    fi
}
