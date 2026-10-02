#!/usr/bin/env bash
# ==============================================================================
# Core Module: Dotfile Deployment & Unified Desktop Environment Configuration
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Browser File Download Fix (System-Wide: LibreWolf & Chromium/Brave)
# ------------------------------------------------------------------------------
setup_browser_download_fix() {
    log_info "Applying browser file download and XDG directory fixes..."

    # 1. Generate & synchronize standard XDG directories (creates ~/Downloads)
    if command -v xdg-user-dirs-update &>/dev/null; then
        xdg-user-dirs-update
    fi
    mkdir -p "${HOME}/Downloads" "${HOME}/Desktop" "${HOME}/Documents" "${HOME}/Pictures"
    chmod 755 "${HOME}/Downloads"

    # Export explicit XDG_DOWNLOAD_DIR in user-dirs.dirs
    mkdir -p "${HOME}/.config"
    if [[ ! -f "${HOME}/.config/user-dirs.dirs" ]] || ! grep -q "XDG_DOWNLOAD_DIR" "${HOME}/.config/user-dirs.dirs"; then
        cat << 'EOF' > "${HOME}/.config/user-dirs.dirs"
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF
    fi

    # 2. XDG Desktop Portals configuration to prevent Wayland file-picker hangs
    mkdir -p "${HOME}/.config/xdg-desktop-portal"
    cat << 'EOF' > "${HOME}/.config/xdg-desktop-portal/portals.conf"
[preferred]
default=gtk;wlr;
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
EOF

    sudo mkdir -p /etc/xdg-desktop-portal
    sudo cp -f "${HOME}/.config/xdg-desktop-portal/portals.conf" /etc/xdg-desktop-portal/portals.conf

    # 3. LibreWolf Staging Override: prevent saving downloads into temporary/staged directory
    mkdir -p "${HOME}/.librewolf"
    cat << 'EOF' > "${HOME}/.librewolf/librewolf.overrides.cfg"
// Disable staging downloads in tmp dir to eliminate file saving failures
defaultPref("browser.download.start_downloads_in_tmp_dir", false);
user_pref("browser.download.start_downloads_in_tmp_dir", false);
EOF

    sudo mkdir -p /etc/librewolf
    sudo cp -f "${HOME}/.librewolf/librewolf.overrides.cfg" /etc/librewolf/librewolf.overrides.cfg

    log_success "Browser download handlers, XDG download directories, and portals configured."
}

# ------------------------------------------------------------------------------
# Global Theming & Visual Consistency (GTK, GNOME, Qt, Kvantum, Thunar)
# ------------------------------------------------------------------------------
setup_theming() {
    log_info "Configuring unified global theming (GTK3/4, Qt, GNOME, Kvantum, Thunar)..."

    local config_dir="${HOME}/.config"
    mkdir -p "${config_dir}/gtk-3.0" "${config_dir}/gtk-4.0" "${config_dir}/qt5ct" \
             "${config_dir}/qt6ct" "${config_dir}/Kvantum"

    # 1. GTK3 & GTK4 Settings (Dark mode, Papirus-Dark icons, complete window buttons)
    local gtk_settings="[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-cursor-theme-name=Papirus
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=:minimize,maximize,close"

    echo "$gtk_settings" > "${config_dir}/gtk-3.0/settings.ini"
    echo "$gtk_settings" > "${config_dir}/gtk-4.0/settings.ini"

    sudo mkdir -p /etc/gtk-3.0
    echo "$gtk_settings" | sudo tee /etc/gtk-3.0/settings.ini >/dev/null

    # 2. GNOME / GSettings Settings (Window control buttons, dark color scheme)
    if command -v gsettings &>/dev/null; then
        log_info "Applying GNOME app button layout and dark preferences via gsettings..."
        gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 10' 2>/dev/null || true
        gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat' 2>/dev/null || true
        gsettings set org.gnome.desktop.peripherals.touchpad accel-profile 'flat' 2>/dev/null || true
    fi

    # 3. Qt5ct & Qt6ct Configuration (Align Qt applications with Kvantum / GTK)
    cat << 'EOF' > "${config_dir}/qt5ct/qt5ct.conf"
[Appearance]
style=kvantum-dark
icon_theme=Papirus-Dark
standard_dialogs=default

[Fonts]
general="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
fixed="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
EOF

    cat << 'EOF' > "${config_dir}/qt6ct/qt6ct.conf"
[Appearance]
style=kvantum-dark
icon_theme=Papirus-Dark
standard_dialogs=default

[Fonts]
general="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
fixed="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
EOF

    # 4. Kvantum Theme Engine
    cat << 'EOF' > "${config_dir}/Kvantum/kvantum.kvconfig"
[General]
theme=KvDark
EOF

    # 5. Thunar File Manager Theming (Ensure GTK icon/theme bindings apply cleanly)
    if command -v xfconf-query &>/dev/null; then
        xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark" --create -t string 2>/dev/null || true
        xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" --create -t string 2>/dev/null || true
    fi

    # 6. Wayfire Topbar (wf-panel / wf-shell) font & scale configuration to avoid blurriness
    cat << 'EOF' > "${config_dir}/wf-shell.ini"
[panel]
autohide = false
layer = top
position = top
minimal_height = 36
css_path = ""
widgets_left = menu
widgets_center = clock
widgets_right = volume network battery
EOF

    log_success "Global unified theming (GTK, GNOME, Qt, Kvantum, Thunar) applied."
}

# ------------------------------------------------------------------------------
# Wallpaper Management & Solid Fallback Generation
# ------------------------------------------------------------------------------
set_solid_color_wallpaper() {
    local out_file="$1"
    local color="${2:-#1a1b26}"
    log_info "Generating solid color background (${color})..."
    if command -v magick &>/dev/null; then
        magick -size 1920x1080 xc:"${color}" "${out_file}" 2>/dev/null || true
    elif command -v convert &>/dev/null; then
        convert -size 1920x1080 xc:"${color}" "${out_file}" 2>/dev/null || true
    fi

    if [[ ! -f "${out_file}" ]]; then
        # 1x1 PNG fallback
        printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\x18\x1b\x26\x00\x00\x00\x82\x00\x81\x1b\x9d\xe2\xb7\x00\x00\x00\x00IEND\xaeB`\x82' > "${out_file}" 2>/dev/null || true
    fi
}

setup_wallpaper() {
    local config_dir="$1"
    local wall_dest_dir="${HOME}/Pictures/wallpapers"
    local target_wallpaper="${wall_dest_dir}/default.png"
    mkdir -p "${wall_dest_dir}"

    local scan_dirs=("/wallpapers" "${SCRIPT_DIR}/wallpapers" "${SCRIPT_DIR}/wallpaper")
    local found_wallpapers=()
    local scan_dir=""

    for dir in "${scan_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r -d '' file; do
                found_wallpapers+=("$file")
            done < <(find "$dir" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.bmp" \) -print0 2>/dev/null || true)
            if (( ${#found_wallpapers[@]} > 0 )); then
                scan_dir="$dir"
                break
            fi
        fi
    done

    local selected_wallpaper=""
    local count=${#found_wallpapers[@]}

    if (( count == 0 )); then
        log_info "No custom wallpapers found in /wallpapers or repository. Setting solid color background automatically."
        set_solid_color_wallpaper "${target_wallpaper}" "#1a1b26"
        selected_wallpaper="${target_wallpaper}"
    elif (( count == 1 )); then
        local single_file="${found_wallpapers[0]}"
        local filename
        filename=$(basename "$single_file")
        log_info "Detected 1 wallpaper in ${scan_dir}: ${filename}"

        local choice="1"
        if [[ -t 0 ]]; then
            printf "\n${COLOR_WHITE}Wallpaper Configuration:${COLOR_RESET}\n"
            printf "  [1] Use wallpaper: ${COLOR_GREEN}%s${COLOR_RESET}\n" "$filename"
            printf "  [2] Set solid color background\n"
            read -rp "Enter choice [1/2] (default: 1): " user_choice
            choice="${user_choice:-1}"
        fi

        if [[ "$choice" == "2" ]]; then
            log_info "Setting solid color background as selected..."
            set_solid_color_wallpaper "${target_wallpaper}" "#1a1b26"
            selected_wallpaper="${target_wallpaper}"
        else
            log_info "Applying detected wallpaper: ${filename}"
            local ext="${single_file##*.}"
            target_wallpaper="${wall_dest_dir}/wallpaper.${ext}"
            cp -f "$single_file" "$target_wallpaper" 2>/dev/null || sudo cp -f "$single_file" "$target_wallpaper"
            sudo chown "${USER}:${USER}" "$target_wallpaper" 2>/dev/null || true
            chmod 644 "$target_wallpaper" 2>/dev/null || true
            selected_wallpaper="${target_wallpaper}"
        fi
    else
        log_info "Detected ${count} wallpapers in ${scan_dir}."
        local choice="1"
        if [[ -t 0 ]]; then
            printf "\n${COLOR_WHITE}Multiple Wallpapers Detected in %s:${COLOR_RESET}\n" "$scan_dir"
            for (( i=0; i<count; i++ )); do
                printf "  [%d] %s\n" "$(( i + 1 ))" "$(basename "${found_wallpapers[i]}")"
            done
            printf "  [%d] Set solid color background\n" "$(( count + 1 ))"

            read -rp "Select an option [1-$(( count + 1 ))] (default: 1): " user_choice
            choice="${user_choice:-1}"
        fi

        if [[ "$choice" -eq "$(( count + 1 ))" ]] 2>/dev/null; then
            log_info "Setting solid color background as selected..."
            set_solid_color_wallpaper "${target_wallpaper}" "#1a1b26"
            selected_wallpaper="${target_wallpaper}"
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            local picked_file="${found_wallpapers[$(( choice - 1 ))]}"
            local ext="${picked_file##*.}"
            target_wallpaper="${wall_dest_dir}/wallpaper.${ext}"
            log_info "Applying selected wallpaper: $(basename "$picked_file")"
            cp -f "$picked_file" "$target_wallpaper" 2>/dev/null || sudo cp -f "$picked_file" "$target_wallpaper"
            sudo chown "${USER}:${USER}" "$target_wallpaper" 2>/dev/null || true
            chmod 644 "$target_wallpaper" 2>/dev/null || true
            selected_wallpaper="${target_wallpaper}"
        else
            log_warn "Invalid selection. Defaulting to first wallpaper: $(basename "${found_wallpapers[0]}")"
            local picked_file="${found_wallpapers[0]}"
            local ext="${picked_file##*.}"
            target_wallpaper="${wall_dest_dir}/wallpaper.${ext}"
            cp -f "$picked_file" "$target_wallpaper" 2>/dev/null || sudo cp -f "$picked_file" "$target_wallpaper"
            sudo chown "${USER}:${USER}" "$target_wallpaper" 2>/dev/null || true
            chmod 644 "$target_wallpaper" 2>/dev/null || true
            selected_wallpaper="${target_wallpaper}"
        fi
    fi

    log_info "Configuring hyprpaper with wallpaper: ${selected_wallpaper}..."
    cat > "${config_dir}/hypr/hyprpaper.conf" << EOF
ipc = on
preload = ${selected_wallpaper}
wallpaper = ,${selected_wallpaper}
EOF

    # Sync wallpaper to ReGreet display manager and system backgrounds
    sudo mkdir -p /usr/share/backgrounds /etc/greetd
    sudo cp -f "${selected_wallpaper}" /usr/share/backgrounds/default.jpg 2>/dev/null || true
    sudo cp -f "${selected_wallpaper}" /etc/greetd/wallpaper.png 2>/dev/null || true
    sudo chmod 644 /usr/share/backgrounds/default.jpg /etc/greetd/wallpaper.png 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Master Dotfiles Deployment Pipeline
# ------------------------------------------------------------------------------
deploy_core_dotfiles() {
    log_step "STEP 6: Deploying Wayfire Dotfiles & Environment Configurations"

    local src_configs="${SCRIPT_DIR}/core/configs"
    local config_dir="${HOME}/.config"
    local wf_scripts="${config_dir}/wayfire/scripts"

    mkdir -p "${config_dir}/waybar" "${config_dir}/fuzzel" "${config_dir}/mako" \
             "${config_dir}/wlogout" "${config_dir}/hypr" "${config_dir}/foot" \
             "${config_dir}/alacritty" "${config_dir}/fish" "${wf_scripts}" \
             "${HOME}/Pictures/Screenshots"

    log_info "Deploying Wayfire and application configurations..."
    cp -f "${src_configs}/wayfire.ini" "${config_dir}/wayfire.ini"
    cp -f "${src_configs}/waybar/config.jsonc" "${config_dir}/waybar/config.jsonc"
    cp -f "${src_configs}/waybar/style.css" "${config_dir}/waybar/style.css"
    cp -f "${src_configs}/fuzzel/fuzzel.ini" "${config_dir}/fuzzel/fuzzel.ini"
    cp -f "${src_configs}/mako/config" "${config_dir}/mako/config"
    cp -f "${src_configs}/wlogout/layout" "${config_dir}/wlogout/layout"
    cp -f "${src_configs}/wlogout/style.css" "${config_dir}/wlogout/style.css"
    cp -f "${src_configs}/hypr/hyprlock.conf" "${config_dir}/hypr/hyprlock.conf"
    cp -f "${src_configs}/foot/foot.ini" "${config_dir}/foot/foot.ini"
    cp -f "${src_configs}/alacritty/alacritty.toml" "${config_dir}/alacritty/alacritty.toml"
    cp -f "${src_configs}/fish/config.fish" "${config_dir}/fish/config.fish"
    cp -f "${src_configs}/starship.toml" "${config_dir}/starship.toml"

    log_info "Deploying auxiliary helper scripts..."
    cp -f "${src_configs}/scripts/screenshot.sh" "${wf_scripts}/screenshot.sh"
    cp -f "${src_configs}/scripts/volume.sh" "${wf_scripts}/volume.sh"
    cp -f "${src_configs}/scripts/brightness.sh" "${wf_scripts}/brightness.sh"
    cp -f "${src_configs}/scripts/powermenu.sh" "${wf_scripts}/powermenu.sh"

    chmod +x "${wf_scripts}/screenshot.sh" "${wf_scripts}/volume.sh" \
             "${wf_scripts}/brightness.sh" "${wf_scripts}/powermenu.sh"

    # Apply global theming & browser download fixes
    setup_theming
    setup_browser_download_fix

    # Setup wallpaper
    setup_wallpaper "${config_dir}"

    # Lock down permissions safely
    chmod 700 "${config_dir}"
    sudo chown -R "${USER}:${USER}" "${config_dir}" "${HOME}/Pictures" "${HOME}/Downloads"

    log_success "Wayfire dotfiles, global theming, and desktop utilities successfully deployed."
}
