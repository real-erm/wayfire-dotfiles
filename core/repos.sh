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

    # 0. Fix IPv6 unexpected EOF connection drops (prefer IPv4 for reliable AUR & mirrors)
    if [[ -f /etc/gai.conf ]]; then
        log_info "Configuring /etc/gai.conf to prioritize IPv4 over broken IPv6 routes..."
        sudo sed -i 's/^#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/' /etc/gai.conf 2>/dev/null || true
    fi

    # 1. Synchronize package databases before any AUR operations
    log_info "Synchronizing pacman package databases..."
    sudo pacman -Sy

    # -------------------------------------------------------------------------
    # ALHP Setup (only for x86-64-v2 and above)
    # -------------------------------------------------------------------------
    local alhp_ready=false
    if [[ "$march" != "v1" ]]; then
        log_info "Setting up ALHP repositories for x86-64-${march}..."

        # Install alhp-mirrorlist first (does not require signing keys)
        log_info "Installing alhp-mirrorlist from AUR..."
        paru -S --needed --noconfirm alhp-mirrorlist 2>/dev/null || log_warn "alhp-mirrorlist AUR install failed."

        # Ensure mirrorlist file exists with active servers (create fallback if AUR package failed)
        if [[ ! -s /etc/pacman.d/alhp-mirrorlist ]]; then
            log_info "Creating default ALHP mirrorlist fallback in /etc/pacman.d/alhp-mirrorlist..."
            sudo mkdir -p /etc/pacman.d
            cat << 'MIRROREOF' | sudo tee /etc/pacman.d/alhp-mirrorlist > /dev/null
Server = https://alhp.krautflare.de/$repo/os/$arch/
Server = https://alhp.harting.dev/$repo/os/$arch
Server = https://alhp2.harting.dev/$repo/os/$arch
MIRROREOF
        elif ! grep -q "^Server" /etc/pacman.d/alhp-mirrorlist; then
            log_info "Activating default ALHP mirror in /etc/pacman.d/alhp-mirrorlist..."
            sudo sed -i '0,/^#Server/s/^#//' /etc/pacman.d/alhp-mirrorlist
        fi

        # Ensure Cloudflare mirror is prioritized and failing cdn.alhp.dev disabled
        if [[ -f /etc/pacman.d/alhp-mirrorlist ]]; then
            log_info "Prioritizing Cloudflare mirror and disabling failing cdn.alhp.dev in ALHP mirrorlist..."
            sudo sed -i 's|^Server = https://cdn.alhp.dev|#Server = https://cdn.alhp.dev|' /etc/pacman.d/alhp-mirrorlist 2>/dev/null || true
            sudo sed -i '/krautflare/d' /etc/pacman.d/alhp-mirrorlist 2>/dev/null || true
            sudo sed -i '1i Server = https://alhp.krautflare.de/$repo/os/$arch/' /etc/pacman.d/alhp-mirrorlist 2>/dev/null || true
        fi

        # Install alhp-keyring (separate call for better error isolation)
        log_info "Installing alhp-keyring from AUR..."
        if paru -S --needed --noconfirm alhp-keyring 2>/dev/null; then
            log_success "alhp-keyring installed successfully via paru."
        else
            log_warn "alhp-keyring paru build failed. Attempting manual build with --skippgpcheck..."
            # Fallback: clone PKGBUILD directly and build with relaxed PGP source verification
            local kr_build_dir
            kr_build_dir=$(mktemp -d -p /tmp alhp-kr-XXXXXX)
            CLEANUP_PATHS+=("$kr_build_dir")
            if git clone --depth 1 https://aur.archlinux.org/alhp-keyring.git "${kr_build_dir}/alhp-keyring" 2>/dev/null; then
                if (cd "${kr_build_dir}/alhp-keyring" && makepkg -si --noconfirm --skippgpcheck 2>&1); then
                    log_success "alhp-keyring built and installed via manual fallback."
                else
                    log_warn "alhp-keyring manual build also failed."
                fi
            else
                log_warn "Failed to clone alhp-keyring from AUR."
            fi
            rm -rf "$kr_build_dir" 2>/dev/null || true
        fi

        # Populate ALHP keyring in pacman-key
        sudo pacman-key --populate alhp 2>/dev/null || true

        # Verify ALHP keyring is present before allowing repository injection
        if pacman -Q alhp-keyring &>/dev/null || sudo pacman-key --list-keys alhp &>/dev/null; then
            alhp_ready=true
            log_success "ALHP keyring verified in pacman-key trust database."
        else
            log_warn "ALHP keyring could NOT be verified. ALHP repositories will NOT be injected into pacman.conf."
            log_warn "You can retry manually later with: paru -S alhp-keyring"
        fi
    fi

    # -------------------------------------------------------------------------
    # BlackArch Setup
    # -------------------------------------------------------------------------
    log_info "Attempting BlackArch keyring installation..."
    paru -S --needed --noconfirm blackarch-keyring blackarch-mirrorlist 2>/dev/null || true
    sudo pacman-key --populate blackarch 2>/dev/null || true

    if [[ ! -s /etc/pacman.d/blackarch-mirrorlist ]]; then
        log_info "Configuring default mirror in /etc/pacman.d/blackarch-mirrorlist..."
        echo 'Server = https://blackarch.org/blackarch/$repo/os/$arch' | sudo tee /etc/pacman.d/blackarch-mirrorlist > /dev/null
    fi

    # -------------------------------------------------------------------------
    # Inject repositories into /etc/pacman.conf
    # -------------------------------------------------------------------------

    # Backup existing pacman.conf
    local backup_conf="/etc/pacman.conf.bak.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/pacman.conf "$backup_conf"
    log_info "Backup created at ${backup_conf}"

    # Build ALHP configuration block (only if keyring is verified)
    local alhp_block=""
    if [[ "$alhp_ready" == true ]] && [[ -s /etc/pacman.d/alhp-mirrorlist ]]; then
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

    # Inject ALHP block ABOVE [core] using root-owned mktemp to avoid
    # fs.protected_regular permission denials on sticky-bit /tmp
    if [[ -n "$alhp_block" ]] && ! grep -q "core-x86-64-${march}" /etc/pacman.conf; then
        log_info "Injecting ALHP repositories ABOVE [core] in /etc/pacman.conf..."
        local tmp_conf
        tmp_conf=$(sudo mktemp -p /tmp pacman.conf.XXXXXX)
        CLEANUP_PATHS+=("$tmp_conf")

        sudo env ALHP_BLOCK="$alhp_block" awk '
            !inserted && /^[[:space:]]*\[core\]/ {
                print ENVIRON["ALHP_BLOCK"] "\n"
                inserted = 1
            }
            { print }
        ' /etc/pacman.conf | sudo tee "$tmp_conf" > /dev/null

        sudo cp "$tmp_conf" /etc/pacman.conf
        sudo rm -f "$tmp_conf"
        log_success "ALHP repositories injected into /etc/pacman.conf."
    else
        if [[ "$march" == "v1" ]]; then
            log_info "Microarchitecture is v1, no ALHP optimization available."
        elif [[ "$alhp_ready" != true ]]; then
            log_warn "Skipping ALHP injection due to missing keyring."
        else
            log_info "ALHP repository entries already present. Skipping injection."
        fi
    fi

    # Inject BlackArch repository (only if keys are verified)
    if sudo pacman-key --list-keys blackarch &>/dev/null || pacman -Q blackarch-keyring &>/dev/null; then
        if ! grep -q "^\[blackarch\]" /etc/pacman.conf; then
            log_info "Injecting BlackArch repository with 'Usage = Sync Search' into /etc/pacman.conf..."
            cat << 'EOF' | sudo tee -a /etc/pacman.conf > /dev/null

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
