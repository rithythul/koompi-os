# shellcheck shell=bash
# Sourced by ./setup. Everything that is neither "install a package" nor "copy a
# file": the Python venv the colour pipeline runs in, the compiled global-menu
# daemon, group membership, kernel modules and user services.

# The shell's Python helpers run out of a venv rather than site-packages so an
# OS Python upgrade cannot break the desktop, and so the same requirements
# resolve identically on Arch, Fedora and Debian.
setup_python_venv() {
    step "Python environment"
    if ! have uv; then
        warn "uv not found; skipping the venv."
        warn "Wallpaper colour generation and thumbnails will not work until it exists."
        return 0
    fi
    run mkdir -p "$(dirname "$VENV_DIR")"
    # No --python pin: the venv must be built on the distro's own interpreter or
    # --system-site-packages cannot see the distro PyGObject and opencv, which
    # are taken from packages rather than built here.
    run uv venv --system-site-packages "$VENV_DIR"
    run uv pip install --python "$VENV_DIR/bin/python" \
        -r "$REPO_ROOT/sdata/uv/requirements.txt"
    ok "venv ready at $VENV_DIR"
}

# The global menu daemon is Zig source in the shell tree; zig-out/ is
# gitignored, so a fresh clone has no binary and the menu silently stays empty.
setup_global_menu() {
    step "Global menu daemon"
    local src="${XDG_CONFIG_HOME}/quickshell/koompi/scripts/global-menu"
    [[ -d "$src" ]] || { info "not installed, skipping"; return 0; }
    if ! have zig; then
        warn "zig not found; the global menu will be empty until it is built."
        warn "Install zig, then re-run: ./setup install --only-setups"
        return 0
    fi
    ( cd "$src" && run zig build -Doptimize=ReleaseSafe )
    ok "global-menu-daemon built"
}

# ddcutil needs i2c to talk to external monitors; ydotool and the on-screen
# keyboard need uinput. Both are group + module questions, not package ones.
setup_groups_and_modules() {
    step "Groups, kernel modules and udev"
    local groups=(video input)
    if getent group i2c >/dev/null 2>&1; then
        groups+=(i2c)
    elif [[ "$OS_GROUP_ID" != fedora ]]; then
        run sudo groupadd i2c
        groups+=(i2c)
    fi
    run sudo usermod -aG "$(IFS=,; echo "${groups[*]}")" "$(id -un)"
    info "group changes take effect at your next login"

    sudo_write /etc/modules-load.d/koompi.conf $'i2c-dev\nuinput'
    sudo_write /etc/udev/rules.d/99-koompi-uinput.rules \
        'SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", GROUP="input"'
    run sudo udevadm control --reload-rules
}

# ydotool ships a system unit on most distros but the shell drives it as a user
# service; link it into the user manager where the distro has not.
setup_services() {
    step "User services"
    have systemctl || { warn "no systemd; start ydotool yourself"; return 0; }

    if [[ ! -e /usr/lib/systemd/user/ydotool.service ]] \
       && [[ -e /usr/lib/systemd/system/ydotool.service ]]; then
        run sudo ln -sf /usr/lib/systemd/system/ydotool.service \
                        /usr/lib/systemd/user/ydotool.service
    fi
    if [[ -e /usr/lib/systemd/user/ydotool.service ]]; then
        run systemctl --user enable --now ydotool
    else
        warn "no ydotool user service found; input synthesis will not work"
    fi
    if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
        run sudo systemctl enable --now bluetooth
    fi
}

# GTK apps read their font and dark-mode preference from gsettings, not from
# ~/.config/koompi/config.json, so the defaults have to be pushed once.
setup_toolkit_defaults() {
    step "Toolkit defaults"
    if have gsettings; then
        run gsettings set org.gnome.desktop.interface font-name 'Google Sans Flex Medium 11 @opsz=11,wght=500'
        run gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    else
        warn "gsettings not found; GTK apps keep their stock font and light theme"
    fi
    if have fc-cache; then
        run fc-cache -f
    fi
    if have update-desktop-database; then
        run update-desktop-database "${XDG_DATA_HOME}/applications" 2>/dev/null || true
    fi
}

setup_system_session() {
    step "System login session"

    # Display managers discover sessions before a user session exists, so most
    # of them do not scan ~/.local/share/wayland-sessions. Keep that user copy
    # as a fallback, but register KOOMPI system-wide for GDM, SDDM and friends.
    local launcher=/usr/local/bin/koompi-session
    local entry=/usr/share/wayland-sessions/koompi.desktop
    local launcher_src="$REPO_ROOT/dots/.local/bin/koompi-session"
    local entry_src="$REPO_ROOT/dots/.local/share/wayland-sessions/koompi.desktop"
    local install_launcher=true

    if [[ -x /usr/bin/koompi-session ]]; then
        launcher=/usr/bin/koompi-session
        install_launcher=false
        ok "packaged /usr/bin/koompi-session present"
    fi

    if $install_launcher && [[ -e "$launcher" ]] \
       && ! grep -q "koompi-session - launch the KOOMPI" "$launcher" 2>/dev/null; then
        warn "$launcher exists and is not KOOMPI-managed; not overwriting it"
        return 0
    fi
    if [[ -e "$entry" ]] && ! grep -q '^X-KOOMPI-Managed=true$' "$entry" 2>/dev/null; then
        warn "$entry exists and is not KOOMPI-managed; not overwriting it"
        return 0
    fi

    local staged_entry
    staged_entry="$(mktemp)"
    sed "s|^Exec=/usr/bin/koompi-session$|Exec=${launcher}|" "$entry_src" > "$staged_entry"

    if $install_launcher; then
        run sudo install -Dm755 "$launcher_src" "$launcher"
    fi
    run sudo install -Dm644 "$staged_entry" "$entry"
    rm -f "$staged_entry"

    if [[ "$DRY_RUN" != true && -x "$launcher" && -f "$entry" ]]; then
        mkdir -p "$(dirname "$SYSTEM_MANIFEST")"
        if $install_launcher; then
            printf '%s\n%s\n' "$launcher" "$entry" > "$SYSTEM_MANIFEST"
        else
            printf '%s\n' "$entry" > "$SYSTEM_MANIFEST"
        fi
        ok "KOOMPI is registered alongside the host desktop"
    fi
}

run_setups() {
    setup_python_venv
    setup_global_menu
    setup_groups_and_modules
    setup_services
    setup_toolkit_defaults
    setup_system_session
}
