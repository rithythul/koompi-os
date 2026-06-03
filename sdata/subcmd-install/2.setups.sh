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
# Fingerprint login/unlock (opt-in, per-machine).
# Never ships enrolled prints: templates live in /var/lib/fprint, outside this repo.
# 'sufficient' placement means a fingerprint succeeds login but failure/absence
# always falls through to the password — no lockout risk.

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

enable_pam_fprintd(){
  # Arch only. Fingerprint for sudo + lock screen (hyprlock) ONLY — never SDDM.
  # SDDM's QtQuick greeter can't cancel the fprintd PAM conversation, so with
  # fprintd in the shared system-auth stack a password login blocks ~30s waiting
  # for the reader to time out. We therefore add fprintd directly to the sudo and
  # hyprlock stacks instead of system-auth (which sddm/tty login include). Idempotent.
  local sa=/etc/pam.d/system-auth
  if grep -q pam_fprintd.so "$sa"; then
    # Migrate older installs that put fprintd in system-auth: strip it so SDDM login is fast again.
    log_info "Removing pam_fprintd from $sa (was slowing SDDM login)."
    x sudo cp "$sa" "$sa.koompi.bak"
    x sudo sed -i '/pam_fprintd.so/d' "$sa"
  fi
  prepend_pam_fprintd /etc/pam.d/sudo
  prepend_pam_fprintd /etc/pam.d/hyprlock
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
        log_warning "No fingerprint was enrolled; leaving PAM untouched."
        return 0
      fi
      if [[ "$OS_GROUP_ID" == "arch" ]]; then
        enable_pam_fprintd
        log_success "Fingerprint enabled for lock screen and sudo (SDDM login stays password-only for speed)."
      else
        log_success "Fingerprint enrolled — the lock screen will use it."
        log_warning "Non-Arch: to also use it for login/sudo, add 'auth sufficient pam_fprintd.so' to your PAM stack (Fedora: 'sudo authselect enable-feature with-fingerprint')."
      fi
      ;;
    *)
      log_info "Skipped fingerprint setup. Run './setup install-setups' later to enroll."
      ;;
  esac
}

showfun setup_fingerprint
setup_fingerprint
