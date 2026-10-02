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

    # System-wide GTK3 configuration for window button layout
    log_info "Configuring system-wide GTK window controls..."
    sudo mkdir -p /etc/gtk-3.0
    cat << 'EOF' | sudo tee /etc/gtk-3.0/settings.ini >/dev/null
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-cursor-theme-name=Papirus
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=icon:minimize,maximize,close
EOF

    log_info "Enabling systemd system services..."
    sudo systemctl enable greetd.service
    sudo systemctl enable NetworkManager.service
    sudo systemctl enable bluetooth.service

    log_info "Configuring user-level audio services..."
    systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

    log_info "Configuring greetd and modern ReGreet display manager..."
    # Ensure greeter user exists with video and render group permissions
    sudo useradd -M -G video,render greeter 2>/dev/null || sudo usermod -aG video,render greeter

    # Create minimal Wayfire session for greetd greeter
    sudo mkdir -p /etc/greetd
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

    # Ensure a sleek greeter background exists in /etc/greetd/wallpaper.png
    if [[ ! -f /etc/greetd/wallpaper.png ]]; then
        if [[ -f "${SCRIPT_DIR}/wallpapers/default.png" ]]; then
            sudo cp "${SCRIPT_DIR}/wallpapers/default.png" /etc/greetd/wallpaper.png
        else
            printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\x18\x1b\x26\x00\x00\x00\x82\x00\x81\x1b\x9d\xe2\xb7\x00\x00\x00\x00IEND\xaeB`\x82' | sudo tee /etc/greetd/wallpaper.png >/dev/null || true
        fi
        sudo chmod 644 /etc/greetd/wallpaper.png 2>/dev/null || true
    fi

    # Configure modern ReGreet TOML settings
    cat << 'EOF' | sudo tee /etc/greetd/regreet.toml >/dev/null
[background]
path = "/etc/greetd/wallpaper.png"
fit = "Cover"

[appearance]
greeting_message = "Welcome to Arch Linux"

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

    # Configure modern ReGreet GTK4 CSS styling
    cat << 'EOF' | sudo tee /etc/greetd/regreet.css >/dev/null
/* ReGreet Modern Clean Theme */
window {
    background-color: #1a1b26;
}

#lock-box {
    background-color: rgba(36, 40, 59, 0.90);
    border: 1px solid rgba(122, 162, 247, 0.35);
    border-radius: 16px;
    padding: 32px 36px;
    box-shadow: 0 12px 36px rgba(0, 0, 0, 0.55);
}

#greeting {
    font-size: 20px;
    font-weight: 700;
    color: #7aa2f7;
    margin-bottom: 8px;
}

#clock {
    font-size: 32px;
    font-weight: 800;
    color: #c0caf5;
    margin-bottom: 12px;
}

entry {
    background-color: rgba(26, 27, 38, 0.85);
    color: #c0caf5;
    border: 1px solid #414868;
    border-radius: 8px;
    padding: 8px 12px;
    margin: 6px 0;
}

entry:focus {
    border-color: #7aa2f7;
    box-shadow: 0 0 0 2px rgba(122, 162, 247, 0.3);
}

button {
    background-color: #7aa2f7;
    color: #1a1b26;
    border-radius: 8px;
    font-weight: 700;
    padding: 8px 16px;
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
    border-radius: 8px;
    padding: 4px 8px;
}
EOF

    # Ensure greeter permissions on home and runtime folders to prevent GTK cache initialization crashes
    sudo mkdir -p /var/lib/greetd /var/log/greetd /var/cache/regreet
    sudo chown -R greeter:greeter /var/lib/greetd /var/log/greetd /var/cache/regreet /etc/greetd 2>/dev/null || true
    sudo chmod 755 /var/lib/greetd 2>/dev/null || true
    sudo chmod 644 /etc/greetd/wallpaper.png /etc/greetd/regreet.toml /etc/greetd/regreet.css 2>/dev/null || true

    log_success "Display manager, ReGreet styling, and service units enabled."
}
