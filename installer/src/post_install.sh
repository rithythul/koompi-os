#!/usr/bin/env bash
# post_install.sh — KOOMPI OS post-install chroot hook.
#
# ⚠️ SCAFFOLD — UNTESTED. Runs INSIDE the freshly pacstrapped target via
#    `arch-chroot /mnt`. Every btrfs / snapper / bootloader line is a REVIEW
#    point. Do NOT run on a live system.
#
# Responsibilities (the ~last 5% archinstall doesn't do for us):
#   1. snapper config for `/` (+ `/home`), wired to the existing @ / @home subvols
#   2. the read-only @baseline snapshot = "factory reset to original install"
#   3. snap-pac  (auto pre/post snapshot per pacman transaction)
#   4. grub-btrfs (bootable snapshot submenu in GRUB)
#   5. enable sddm.service (belt-and-suspenders: koompi-branding ships a preset
#      that already enables it — harmless to enable again)
#   6. write /etc/os-release (NOT shipped by any package — filesystem owns the
#      stock one; we overwrite with KOOMPI identity)
#
# Idempotent: safe to re-run. Each step checks before it acts.

set -euo pipefail

log() { printf '[koompi-installer] %s\n' "$*"; }

# ─────────────────────────────────────────────────────────────────────────────
# 0. Packages the post-install needs. archinstall pacstrapped the edition
#    metapackage already; these are the snapshot-tooling extras.
#    REVIEW: pin versions on the ISO if reproducibility matters.
# ─────────────────────────────────────────────────────────────────────────────
ensure_pkgs() {
  local want=(snapper snap-pac grub-btrfs inotify-tools)
  local missing=()
  for p in "${want[@]}"; do
    pacman -Qq "$p" &>/dev/null || missing+=("$p")
  done
  if ((${#missing[@]})); then
    log "installing: ${missing[*]}"
    # TODO/REVIEW: live ISO must have the [koompi] + base repos reachable here.
    pacman -S --noconfirm --needed "${missing[@]}"
  else
    log "snapshot tooling already present"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. snapper config for root. archinstall's btrfs layout already created the @
#    subvolume mounted at / and a .snapshots subvol — so we must NOT let
#    `snapper create-config` make its own (it would try to create
#    /.snapshots and fail / conflict). Create the config file, then point it at
#    the existing layout.
#    REVIEW: this is the fiddliest interaction with archinstall's layout.
# ─────────────────────────────────────────────────────────────────────────────
setup_snapper() {
  if snapper list-configs 2>/dev/null | grep -qw root; then
    log "snapper 'root' config already exists"
    return
  fi
  log "creating snapper 'root' config"
  # If archinstall already made /.snapshots, create-config refuses. Handle both.
  if mountpoint -q /.snapshots; then
    umount /.snapshots || true
  fi
  if [ -d /.snapshots ]; then
    rmdir /.snapshots 2>/dev/null || true
  fi
  snapper -c root create-config /
  # Re-establish the .snapshots subvol the way archinstall expects it. TODO:
  # confirm against the exact subvol set archinstall created (@.snapshots etc.).
  # REVIEW: remount /.snapshots from fstab if archinstall added an entry.
  systemctl enable --now snapper-timeline.timer snapper-cleanup.timer || true
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. The @baseline snapshot — a pinned, read-only "this is exactly how the OS
#    shipped" point. Factory reset = roll back to this. Created LAST among the
#    snapshot steps so it captures the finished install.
#    NOTE: a true read-only / un-prunable baseline needs snapper cleanup to skip
#    it. We tag it and set a userdata flag; REVIEW the exact pin mechanism for
#    your snapper version (some use `--read-only`, some a cleanup=number guard).
# ─────────────────────────────────────────────────────────────────────────────
pin_baseline() {
  if snapper -c root list 2>/dev/null | grep -q 'baseline'; then
    log "@baseline snapshot already pinned"
    return
  fi
  log "pinning @baseline snapshot (factory-reset point)"
  # TODO/REVIEW: real flags vary by snapper version. Intent is clear:
  #   single snapshot, descriptive, excluded from automatic cleanup.
  snapper -c root create \
    --type single \
    --cleanup-algorithm number \
    --userdata "important=yes,baseline=yes" \
    --description "KOOMPI @baseline (factory reset point)"
  # REVIEW: optionally set the snapshot subvol read-only:
  #   btrfs property set /.snapshots/<N>/snapshot ro true
}

# ─────────────────────────────────────────────────────────────────────────────
# 3 + 4. snap-pac is config-free once installed (pacman hooks). grub-btrfs needs
#         its daemon enabled and the GRUB menu regenerated.
# ─────────────────────────────────────────────────────────────────────────────
setup_grub_btrfs() {
  log "enabling grub-btrfs snapshot menu"
  systemctl enable grub-btrfsd.service || true
  # Regenerate GRUB so the snapshot submenu appears. archinstall installed GRUB;
  # we only refresh the config. TODO: confirm grub.cfg path for this target.
  if command -v grub-mkconfig &>/dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. Login manager. koompi-branding ships a systemd preset that enables
#    sddm.service; we enable explicitly too (idempotent belt-and-suspenders).
# ─────────────────────────────────────────────────────────────────────────────
enable_login() {
  log "enabling sddm.service"
  systemctl enable sddm.service || true
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. /etc/os-release — KOOMPI identity. Deliberately NOT a package (the
#    `filesystem` package owns the stock file); we overwrite in the target.
#    MUST stay byte-for-byte identical to the live ISO's os-release at
#    sdata/dist-arch/iso/koompi/airootfs/etc/os-release (era "Naga" = v1).
# ─────────────────────────────────────────────────────────────────────────────
write_os_release() {
  log "writing /etc/os-release"
  cat >/etc/os-release <<'EOF'
NAME="KOOMPI OS"
PRETTY_NAME="KOOMPI OS — Naga"
ID=koompi
ID_LIKE=arch
BUILD_ID=rolling
VERSION_CODENAME=naga
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://koompi.org/"
DOCUMENTATION_URL="https://koompi.org/docs/"
SUPPORT_URL="https://koompi.org/support/"
BUG_REPORT_URL="https://github.com/rithythul/koompi-hyprland/issues"
LOGO=koompi
EOF
}

main() {
  log "KOOMPI OS post-install hook starting (SCAFFOLD)"
  ensure_pkgs
  setup_snapper
  setup_grub_btrfs   # snap-pac is hook-only; grub-btrfs needs wiring
  pin_baseline       # AFTER tooling is in place, so the baseline is complete
  enable_login
  write_os_release
  log "post-install hook done"
}

main "$@"
