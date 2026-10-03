#!/usr/bin/env bash
# ==============================================================================
# Core Module: System Services, Display Manager & Environment Setup
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Centralized Environment Variables (Idempotent)
# ------------------------------------------------------------------------------
setup_environment() {
    log_info "Deploying centralized Wayland & theme environment variables..."

    local env_vars=(
        "GDK_BACKEND=wayland,x11"
        "QT_QPA_PLATFORM=wayland;xcb"
        "QT_QPA_PLATFORMTHEME=qt5ct"
        "QT_STYLE_OVERRIDE=kvantum"
        "GTK_THEME=Adwaita:dark"
        "XCURSOR_THEME=Bibata-Modern-Classic"
        "XCURSOR_SIZE=24"
        "MOZ_ENABLE_WAYLAND=1"
        "XDG_CURRENT_DESKTOP=Wayfire"
        "XDG_SESSION_TYPE=wayland"
        "XDG_SESSION_DESKTOP=Wayfire"
        "XDG_DOWNLOAD_DIR=${HOME}/Downloads"
        "ELECTRON_OZONE_PLATFORM_HINT=auto"
    )

    # 1. System-wide (/etc/environment)
    for var in "${env_vars[@]}"; do
        local key="${var%%=*}"
        if grep -q "^${key}=" /etc/environment 2>/dev/null; then
            sudo sed -i "s|^${key}=.*|${var}|" /etc/environment
        else
            echo "${var}" | sudo tee -a /etc/environment >/dev/null
        fi
    done

    # 2. User-session (~/.config/environment.d/10-wayland.conf)
    mkdir -p "${HOME}/.config/environment.d"
    cat << 'EOF' > "${HOME}/.config/environment.d/10-wayland.conf"
# Centralized Wayland & UI Theming Environment Variables
GDK_BACKEND=wayland,x11
QT_QPA_PLATFORM=wayland;xcb
QT_QPA_PLATFORMTHEME=qt5ct
QT_STYLE_OVERRIDE=kvantum
GTK_THEME=Adwaita:dark
XCURSOR_THEME=Bibata-Modern-Classic
XCURSOR_SIZE=24
MOZ_ENABLE_WAYLAND=1
XDG_CURRENT_DESKTOP=Wayfire
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=Wayfire
XDG_DOWNLOAD_DIR=$HOME/Downloads
ELECTRON_OZONE_PLATFORM_HINT=auto
EOF

    log_success "Environment variables configured in /etc/environment and ~/.config/environment.d/10-wayland.conf."
}

# ------------------------------------------------------------------------------
# SDDM Astronaut Theme Configuration
# ------------------------------------------------------------------------------
setup_sddm_astronaut() {
    log_info "Configuring SDDM and Astronaut theme aesthetics..."

    local theme_name="sddm-astronaut-theme"
    local theme_dir="/usr/share/sddm/themes/${theme_name}"
    local theme_repo="https://github.com/Keyitdev/sddm-astronaut-theme.git"

    sudo mkdir -p "/usr/share/sddm/themes" "/etc/sddm.conf.d" "/usr/share/backgrounds" "/usr/share/fonts"

    # Clone or update SDDM Astronaut theme
    if [[ -d "${theme_dir}/.git" ]]; then
        log_info "Updating existing SDDM Astronaut theme repository..."
        sudo git -C "${theme_dir}" pull --rebase 2>/dev/null || true
    elif [[ -d "/tmp/sddm-astronaut-theme" ]]; then
        log_info "Deploying SDDM Astronaut theme from local cache..."
        sudo rm -rf "${theme_dir}"
        sudo cp -r /tmp/sddm-astronaut-theme "${theme_dir}"
    else
        log_info "Cloning SDDM Astronaut theme repository..."
        sudo rm -rf "${theme_dir}"
        sudo git clone --depth 1 "${theme_repo}" "${theme_dir}"
    fi

    # Install custom fonts bundled with Astronaut theme
    if [[ -d "${theme_dir}/Fonts" ]]; then
        log_info "Installing Astronaut theme fonts to /usr/share/fonts..."
        sudo cp -r "${theme_dir}/Fonts"/* /usr/share/fonts/ 2>/dev/null || true
        sudo fc-cache -f /usr/share/fonts 2>/dev/null || true
    fi

    # Ensure system wallpaper is provisioned at /usr/share/backgrounds/default.jpg
    local wp_src="/usr/share/backgrounds/default.jpg"
    if [[ ! -f "${wp_src}" ]]; then
        if [[ -f "${SCRIPT_DIR}/wallpapers/wallhaven-n6qdqq.jpg" ]]; then
            sudo cp -f "${SCRIPT_DIR}/wallpapers/wallhaven-n6qdqq.jpg" "${wp_src}"
        elif [[ -f "${SCRIPT_DIR}/wallpapers/default.png" ]]; then
            sudo cp -f "${SCRIPT_DIR}/wallpapers/default.png" "${wp_src}"
        elif [[ -f "${SCRIPT_DIR}/wallpaper/default.png" ]]; then
            sudo cp -f "${SCRIPT_DIR}/wallpaper/default.png" "${wp_src}"
        elif [[ -f "${theme_dir}/Backgrounds/astronaut.png" ]]; then
            sudo cp -f "${theme_dir}/Backgrounds/astronaut.png" "${wp_src}"
        fi
        sudo chmod 644 "${wp_src}" 2>/dev/null || true
    fi

    # Auto-trim letterboxes from wallpaper using ImageMagick
    if [[ -f "${wp_src}" && -d "${theme_dir}/Backgrounds" ]]; then
        if command -v magick &>/dev/null; then
            magick "${wp_src}" -fuzz 10% -trim +repage /tmp/sddm_clean_wp.jpg 2>/dev/null || cp -f "${wp_src}" /tmp/sddm_clean_wp.jpg
        else
            cp -f "${wp_src}" /tmp/sddm_clean_wp.jpg
        fi
        sudo cp -f /tmp/sddm_clean_wp.jpg "${theme_dir}/Backgrounds/default.jpg"
        sudo cp -f /tmp/sddm_clean_wp.jpg "${theme_dir}/Backgrounds/astronaut.png" 2>/dev/null || true
        sudo chmod 644 "${theme_dir}/Backgrounds/default.jpg" "${theme_dir}/Backgrounds/astronaut.png" 2>/dev/null || true
        rm -f /tmp/sddm_clean_wp.jpg
    fi

    # Fix Astronaut theme configuration (eliminate blur smudges, fix button visibility & contrast)
    if [[ -f "${theme_dir}/Themes/astronaut.conf" ]]; then
        sudo sed -i 's|^Background=.*|Background="Backgrounds/default.jpg"|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^CropBackground=.*|CropBackground="true"|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^PartialBlur=.*|PartialBlur="false"|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^FullBlur=.*|FullBlur="false"|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^HaveFormBackground=.*|HaveFormBackground="false"|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^BypassSystemButtonsChecks=.*|BypassSystemButtonsChecks="true"|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^ScreenWidth=.*|ScreenWidth=""|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^ScreenHeight=.*|ScreenHeight=""|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^LoginButtonBackgroundColor=.*|LoginButtonBackgroundColor="#3b82f6"|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^LoginButtonTextColor=.*|LoginButtonTextColor="#ffffff"|' "${theme_dir}/Themes/astronaut.conf"
        sudo sed -i 's|^SystemButtonsIconsColor=.*|SystemButtonsIconsColor="#ffffff"|' "${theme_dir}/Themes/astronaut.conf"
    fi

    # Fix upstream Main.qml dynamic scaling bug (prevents letterboxing / stretching on non-1080p displays)
    if [[ -f "${theme_dir}/Main.qml" ]]; then
        sudo sed -i 's|^[[:space:]]*height: config.ScreenHeight.*|    anchors.fill: parent|' "${theme_dir}/Main.qml"
        sudo sed -i '/^[[:space:]]*width: config.ScreenWidth.*/d' "${theme_dir}/Main.qml"
    fi

    # Fix login button high-contrast visibility in Components/Input.qml
    if [[ -f "${theme_dir}/Components/Input.qml" ]]; then
        sudo sed -i 's/color: config.LoginButtonTextColor/color: "#ffffff"/' "${theme_dir}/Components/Input.qml"
        sudo sed -i 's/opacity: 0.5/opacity: 1.0/' "${theme_dir}/Components/Input.qml"
        sudo sed -i 's/opacity: 0.2/opacity: 0.95/' "${theme_dir}/Components/Input.qml"
    fi

    # Ensure metadata.desktop points to Themes/astronaut.conf
    if [[ -f "${theme_dir}/metadata.desktop" ]]; then
        sudo sed -i 's|^ConfigFile=.*|ConfigFile=Themes/astronaut.conf|' "${theme_dir}/metadata.desktop"
    fi

    # Configure SDDM master configuration
    cat << 'EOF' | sudo tee /etc/sddm.conf >/dev/null
[Theme]
Current=sddm-astronaut-theme
EOF

    # Configure virtual keyboard support
    cat << 'EOF' | sudo tee /etc/sddm.conf.d/virtualkbd.conf >/dev/null
[General]
InputMethod=qtvirtualkeyboard
EOF

    # Disable conflicting display managers and enable SDDM
    sudo systemctl disable greetd.service lightdm.service gdm.service lxdm.service 2>/dev/null || true
    sudo systemctl enable sddm.service 2>/dev/null || true

    log_success "SDDM Astronaut theme and service successfully configured."
}

# ------------------------------------------------------------------------------
# System & User Services Orchestration
# ------------------------------------------------------------------------------
setup_services() {
    log_info "Creating Wayfire session desktop entry in /usr/share/wayland-sessions/wayfire.desktop..."
    sudo mkdir -p /usr/share/wayland-sessions
    cat << 'EOF' | sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null
[Desktop Entry]
Name=Wayfire
Comment=Wayfire Compositor
Exec=wayfire
Type=Application
DesktopNames=Wayfire
EOF

    # Configure Polkit power management rules so poweroff/reboot/suspend succeed without password/timeout
    log_info "Configuring Polkit power management rules..."
    sudo mkdir -p /etc/polkit-1/rules.d
    cat << 'EOF' | sudo tee /etc/polkit-1/rules.d/48-allow-power-management.rules >/dev/null
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.reboot" ||
         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
         action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
         action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
         action.id == "org.freedesktop.login1.hibernate" ||
         action.id == "org.freedesktop.login1.hibernate-multiple-sessions") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
    sudo chmod 644 /etc/polkit-1/rules.d/48-allow-power-management.rules 2>/dev/null || true

    log_info "Enabling systemd system services..."
    sudo systemctl enable sddm.service
    sudo systemctl enable NetworkManager.service
    sudo systemctl enable bluetooth.service

    log_info "Configuring user-level audio services..."
    systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

    log_success "Systemd services and Polkit authorization rules configured."
}

# ------------------------------------------------------------------------------
# Master Service Module Driver
# ------------------------------------------------------------------------------
configure_system_services() {
    log_step "STEP 6: Services, Environment & Display Manager Configuration"
    setup_environment
    setup_services
    setup_sddm_astronaut
    log_success "System services, environment, and display manager successfully deployed."
}
