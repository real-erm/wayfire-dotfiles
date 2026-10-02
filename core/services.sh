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
# Modern ReGreet Greeter Aesthetics
# ------------------------------------------------------------------------------
setup_regreet() {
    log_info "Configuring greetd and ReGreet GTK greeter aesthetics..."

    # Ensure greeter user exists with video and render group permissions
    sudo useradd -M -G video,render greeter 2>/dev/null || sudo usermod -aG video,render greeter

    # Minimal Wayfire session for greeter (Mouse acceleration adjustments excluded)
    sudo mkdir -p /etc/greetd /usr/share/backgrounds
    cat << 'EOF' | sudo tee /etc/greetd/wayfire-greeter.ini >/dev/null
[core]
plugins = autostart
close_top_view = none

[autostart]
greeter = sh -c 'regreet --style /etc/greetd/regreet.css; wayfiremsg exit || killall wayfire'
EOF

    # Configure greetd default session to launch regreet under minimal wayfire
    cat << 'EOF' | sudo tee /etc/greetd/config.toml >/dev/null
[terminal]
vt = 1

[default_session]
command = "wayfire --config /etc/greetd/wayfire-greeter.ini"
user = "greeter"
EOF

    # Ensure system wallpaper is provisioned at /usr/share/backgrounds/default.jpg
    if [[ ! -f /usr/share/backgrounds/default.jpg ]]; then
        if [[ -f "${SCRIPT_DIR}/wallpapers/default.png" ]]; then
            sudo cp -f "${SCRIPT_DIR}/wallpapers/default.png" /usr/share/backgrounds/default.jpg
        elif [[ -f "${SCRIPT_DIR}/wallpaper/default.png" ]]; then
            sudo cp -f "${SCRIPT_DIR}/wallpaper/default.png" /usr/share/backgrounds/default.jpg
        else
            printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\x18\x1b\x26\x00\x00\x00\x82\x00\x81\x1b\x9d\xe2\xb7\x00\x00\x00\x00IEND\xaeB`\x82' | sudo tee /usr/share/backgrounds/default.jpg >/dev/null || true
        fi
        sudo chmod 644 /usr/share/backgrounds/default.jpg 2>/dev/null || true
    fi

    # Configure modern ReGreet TOML settings with custom clock and background path
    cat << 'EOF' | sudo tee /etc/greetd/regreet.toml >/dev/null
[background]
path = "/usr/share/backgrounds/default.jpg"
fit = "Cover"

[clock]
format = "%H:%M ~ %A, %B %d"

[appearance]
greeting_message = "Welcome to Arch Linux"

[GTK]
application_prefer_dark_theme = true
cursor_theme_name = "Papirus"
font_name = "JetBrainsMono Nerd Font 11"
icon_theme_name = "Papirus-Dark"
theme_name = "Adwaita-dark"

[commands]
reboot = ["systemctl", "reboot"]
poweroff = ["systemctl", "poweroff"]
EOF

    # Configure modern glassmorphic ReGreet GTK4 CSS styling
    cat << 'EOF' | sudo tee /etc/greetd/regreet.css >/dev/null
/* ReGreet Modern Clean Glassmorphism Aesthetic */
window {
    background-color: #1a1b26;
}

#lock-box {
    background-color: rgba(36, 40, 59, 0.88);
    border: 1px solid rgba(122, 162, 247, 0.4);
    border-radius: 18px;
    padding: 36px 42px;
    box-shadow: 0 16px 40px rgba(0, 0, 0, 0.6);
}

#greeting {
    font-size: 22px;
    font-weight: 700;
    color: #7aa2f7;
    margin-bottom: 8px;
}

#clock {
    font-size: 34px;
    font-weight: 800;
    color: #c0caf5;
    margin-bottom: 16px;
    letter-spacing: 0.5px;
}

entry {
    background-color: rgba(26, 27, 38, 0.85);
    color: #c0caf5;
    border: 1px solid #414868;
    border-radius: 10px;
    padding: 10px 14px;
    margin: 8px 0;
    font-size: 14px;
}

entry:focus {
    border-color: #7aa2f7;
    box-shadow: 0 0 0 2px rgba(122, 162, 247, 0.35);
}

button {
    background-color: #7aa2f7;
    color: #1a1b26;
    border-radius: 10px;
    font-weight: 700;
    padding: 10px 20px;
    border: none;
    transition: all 0.2s ease-in-out;
}

button:hover {
    background-color: #89b4fa;
}

combo {
    background-color: rgba(26, 27, 38, 0.85);
    color: #c0caf5;
    border: 1px solid #414868;
    border-radius: 10px;
    padding: 6px 12px;
}
EOF

    # Ensure greeter permissions on home and runtime folders
    sudo mkdir -p /var/lib/greetd /var/log/greetd /var/cache/regreet
    sudo chown -R greeter:greeter /var/lib/greetd /var/log/greetd /var/cache/regreet /etc/greetd 2>/dev/null || true
    sudo chmod 755 /var/lib/greetd 2>/dev/null || true
    sudo chmod 644 /etc/greetd/regreet.toml /etc/greetd/regreet.css 2>/dev/null || true

    log_success "ReGreet styling, clock format, and greeter session configured."
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
    sudo systemctl enable greetd.service
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
    log_step "STEP 5: Services, Environment & Display Manager Configuration"
    setup_environment
    setup_services
    setup_regreet
    log_success "System services, environment, and display manager successfully deployed."
}
