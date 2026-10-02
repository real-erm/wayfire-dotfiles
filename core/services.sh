#!/usr/bin/env bash
# ==============================================================================
# Core Module: System Services, Display Manager & Environment Setup
# ==============================================================================

set -euo pipefail

configure_system_services() {
    log_step "STEP 5: Services, Environment & Display Manager Configuration"

    log_info "Deploying Wayland environment variables to /etc/environment..."
    local env_vars=(
        "XDG_CURRENT_DESKTOP=Wayfire"
        "XDG_SESSION_TYPE=wayland"
        "XDG_SESSION_DESKTOP=Wayfire"
        "MOZ_ENABLE_WAYLAND=1"
        "QT_QPA_PLATFORM=wayland"
        "ELECTRON_OZONE_PLATFORM_HINT=auto"
    )

    for var in "${env_vars[@]}"; do
        local key="${var%%=*}"
        if grep -q "^${key}=" /etc/environment 2>/dev/null; then
            sudo sed -i "s|^${key}=.*|${var}|" /etc/environment
        else
            echo "${var}" | sudo tee -a /etc/environment >/dev/null
        fi
    done
    log_success "Wayland session environment variables configured in /etc/environment."

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

    log_info "Enabling systemd system services..."
    sudo systemctl enable greetd.service
    sudo systemctl enable NetworkManager.service
    sudo systemctl enable bluetooth.service

    log_info "Configuring user-level audio services..."
    systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

    log_info "Configuring greetd and regreet display manager..."
    # Ensure greeter user exists with video and render group permissions
    sudo useradd -M -G video,render greeter 2>/dev/null || sudo usermod -aG video,render greeter

    # Create minimal Wayfire session for greetd greeter
    sudo mkdir -p /etc/greetd
    cat << 'EOF' | sudo tee /etc/greetd/wayfire-greeter.ini >/dev/null
[core]
plugins = autostart
close_top_view = none

[autostart]
greeter = sh -c 'regreet; wayfiremsg exit || killall wayfire'
EOF

    # Configure greetd default session to launch regreet under minimal wayfire
    cat << 'EOF' | sudo tee /etc/greetd/config.toml >/dev/null
[terminal]
vt = 1

[default_session]
command = "wayfire --config /etc/greetd/wayfire-greeter.ini"
user = "greeter"
EOF

    # Configure ReGreet GTK settings
    cat << 'EOF' | sudo tee /etc/greetd/regreet.toml >/dev/null
[GTK]
application_prefer_dark_theme = true
cursor_theme_name = "Papirus"
font_name = "JetBrainsMono Nerd Font 10"
icon_theme_name = "Papirus-Dark"
theme_name = "Adwaita-dark"

[commands]
reboot = ["systemctl", "reboot"]
poweroff = ["systemctl", "poweroff"]
EOF

    # Ensure greeter permissions on home and runtime folders to prevent GTK cache initialization crashes
    sudo mkdir -p /var/lib/greetd /var/log/greetd /var/cache/regreet
    sudo chown -R greeter:greeter /var/lib/greetd /var/log/greetd /var/cache/regreet 2>/dev/null || true
    sudo chmod 755 /var/lib/greetd 2>/dev/null || true

    log_success "Display manager and service units enabled."
}
