# This script is meant to be sourced.
# It's not for directly running.

function prepare_systemd_user_service(){
  if [[ ! -e "/usr/lib/systemd/user/ydotool.service" ]]; then
    x sudo ln -s /usr/lib/systemd/{system,user}/ydotool.service
  fi
}

function setup_user_group(){
  if [[ -z $(getent group i2c) ]] && [[ "$OS_GROUP_ID" != "fedora" ]]; then
    # On Fedora this is not needed. Tested with desktop computer with NVIDIA video card.
    x sudo groupadd i2c
  fi

  if [[ "$OS_GROUP_ID" == "fedora" ]]; then
    x sudo usermod -aG video,input "$(whoami)"
  else
    x sudo usermod -aG video,i2c,input "$(whoami)"
  fi
}
#####################################################################################
# These python packages are installed using uv into the venv (virtual environment). Once the folder of the venv gets deleted, they are all gone cleanly. So it's considered as setups, not dependencies.
showfun install-python-packages
v install-python-packages

showfun setup_user_group
v setup_user_group

if [[ ! -z $(systemctl --version) ]]; then
  # For Fedora, uinput is required for the virtual keyboard to function, and udev rules enable input group users to utilize it.
  if [[ "$OS_GROUP_ID" == "fedora" ]]; then
    v bash -c "echo uinput | sudo tee /etc/modules-load.d/uinput.conf"
    v bash -c 'echo SUBSYSTEM==\"misc\", KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"input\" | sudo tee /etc/udev/rules.d/99-uinput.rules'
  else
    v bash -c "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf"
  fi
  # TODO: find a proper way for enable Nix installed ydotool. When running `systemctl --user enable ydotool, it errors "Failed to enable unit: Unit ydotool.service does not exist".
  if [[ ! "${INSTALL_VIA_NIX}" == true ]]; then
    if [[ "$OS_GROUP_ID" == "fedora" ]]; then
      v prepare_systemd_user_service
    fi
    # When $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR are empty, it commonly means that the current user has been logged in with `su - user` or `ssh user@hostname`. In such case `systemctl --user enable <service>` is not usable. It should be `sudo systemctl --machine=$(whoami)@.host --user enable <service>` instead.
    if [[ ! -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
      v systemctl --user enable ydotool --now
    else
      v sudo systemctl --machine=$(whoami)@.host --user enable ydotool --now
    fi
  fi
  v sudo systemctl enable bluetooth --now
elif [[ ! -z $(openrc --version) ]]; then
  v bash -c "echo 'modules=i2c-dev' | sudo tee -a /etc/conf.d/modules"
  v sudo rc-update add modules boot
  v sudo rc-update add ydotool default
  v sudo rc-update add bluetooth default

  x sudo rc-service ydotool start
  x sudo rc-service bluetooth start
else
  printf "${STY_RED}"
  printf "====================INIT SYSTEM NOT FOUND====================\n"
  printf "${STY_RST}"
  pause
fi

if [[ "$OS_GROUP_ID" == "gentoo" ]]; then
  v sudo chown -R $(whoami):$(whoami) ~/.local/
fi

v gsettings set org.gnome.desktop.interface font-name 'Google Sans Flex Medium 11 @opsz=11,wght=500'
v gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
v kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly

#####################################################################################
# Fingerprint unlock (opt-in, per-machine).
# Never ships enrolled prints: templates live in /var/lib/fprint, outside this repo.
#
# Two surfaces, two mechanisms — both let you scan OR type, password always works:
#   - hyprlock: its NATIVE fingerprint (fprintd over D-Bus, in a thread parallel to
#     the password field) — configured in hyprlock.conf, NOT via pam_fprintd. A PAM
#     rule in /etc/pam.d/hyprlock is sequential and would block a typed password on
#     the reader, so we deliberately keep it out. Distro-independent.
#   - sudo: pam_fprintd as a 'sufficient' first auth rule (finger succeeds, else
#     falls through to the password — no lockout). sudo's PAM is sequential. Arch only.
# SDDM login stays password-only: its QtQuick greeter can't cancel the fprintd
# conversation, so fprintd in the shared system-auth stack hangs password login ~30s.

# Prepend pam_fprintd as the first auth rule in a PAM stack. Idempotent.
prepend_pam_fprintd(){
  local f=$1
  if [[ ! -f $f ]]; then
    log_warning "PAM file $f missing; skipping fingerprint there."
    return 0
  fi
  if grep -q pam_fprintd.so "$f"; then
    log_info "pam_fprintd already configured in $f."
    return 0
  fi
  x sudo cp "$f" "$f.koompi.bak"
  x sudo sed -i '0,/^auth/s//auth        sufficient  pam_fprintd.so\n&/' "$f"
}

# Strip pam_fprintd from a PAM stack (migration / cleanup). Idempotent.
strip_pam_fprintd(){
  local f=$1
  [[ -f $f ]] || return 0
  if grep -q pam_fprintd.so "$f"; then
    log_info "Removing pam_fprintd from $f."
    x sudo cp "$f" "$f.koompi.bak"
    x sudo sed -i '/pam_fprintd.so/d' "$f"
  fi
}

# Ensure hyprlock.conf enables native, parallel fingerprint (hyprlock >= 0.6).
# The shipped dotfile already carries this block; this is a safety net for installs
# whose hyprlock.conf predates it. Idempotent. User-owned file, no sudo.
enable_hyprlock_fingerprint(){
  local conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock.conf"
  if [[ ! -f $conf ]]; then
    log_warning "hyprlock.conf not found at $conf; skipping native fingerprint config."
    return 0
  fi
  if grep -q 'fingerprint {' "$conf"; then
    log_info "hyprlock native fingerprint already configured."
    return 0
  fi
  cat >> "$conf" <<'HYPRLOCK_FP'

# Fingerprint + password run in parallel: scan your finger OR type your password,
# whichever completes first unlocks. fprintd is reached directly (not pam_fprintd),
# so a typed password never blocks on the reader.
auth {
    pam {
        enabled = true
        module = hyprlock
    }
    fingerprint {
        enabled = true
        ready_message = Scan fingerprint or enter password
        present_message = Scanning fingerprint...
        retry_delay = 250
    }
}
HYPRLOCK_FP
  log_info "Enabled hyprlock native fingerprint in $conf."
}

enable_pam_fprintd(){
  # Arch only: sudo fingerprint via pam_fprintd, plus migrate older installs that put
  # fprintd in system-auth (slowed SDDM login) or in /etc/pam.d/hyprlock (blocked a
  # typed password — hyprlock now uses its own native fingerprint instead). Idempotent.
  strip_pam_fprintd /etc/pam.d/system-auth
  strip_pam_fprintd /etc/pam.d/hyprlock
  prepend_pam_fprintd /etc/pam.d/sudo
}

setup_fingerprint(){
  if ! command -v fprintd-enroll >/dev/null 2>&1; then
    log_warning "fprintd not installed; skipping fingerprint setup."
    return 0
  fi
  if ! fprintd-list "$(whoami)" 2>/dev/null | grep -q "Device at"; then
    log_info "No supported fingerprint reader detected; skipping fingerprint setup."
    return 0
  fi
  log_success "Fingerprint reader detected."
  local p=n
  if $ask; then
    echo -e "${STY_YELLOW}[$0]: Enroll a fingerprint now for lock screen / sudo?${STY_RST}"
    echo -e "${STY_YELLOW}Your password keeps working as a fallback. Prints stay on this machine only. [y/N]${STY_RST}"
    read -p "====> " p
  fi
  case $p in
    [yY])
      x fprintd-enroll "$(whoami)"
      if ! fprintd-list "$(whoami)" 2>/dev/null | grep -qE "#[0-9]+:"; then
        log_warning "No fingerprint was enrolled; leaving auth config untouched."
        return 0
      fi
      enable_hyprlock_fingerprint   # hyprlock native, parallel, distro-independent
      if [[ "$OS_GROUP_ID" == "arch" ]]; then
        enable_pam_fprintd
        log_success "Fingerprint enabled: hyprlock (scan or type) and sudo. SDDM login stays password-only for speed."
      else
        log_success "Fingerprint enabled for the hyprlock lock screen (scan or type)."
        log_warning "Non-Arch: to also use it for sudo, add 'auth sufficient pam_fprintd.so' to /etc/pam.d/sudo (Fedora: 'sudo authselect enable-feature with-fingerprint')."
      fi
      ;;
    *)
      log_info "Skipped fingerprint setup. Run './setup install-setups' later to enroll."
      ;;
  esac
}

showfun setup_fingerprint
setup_fingerprint
