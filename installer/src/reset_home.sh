#!/usr/bin/env bash
# reset_home.sh — KOOMPI Full Factory Reset: offline wipe + reseed of @home.
#
# ⚠️ SCAFFOLD — UNTESTED. This DELETES the @home subvolume. Every btrfs line is a
#    REVIEW point. Do NOT run on a system with data you care about.
#
# /home cannot be replaced while it is mounted, so the wipe is done OFFLINE at
# boot — ordered before home.mount — by koompi-factory-reset-home.service. Two
# entry points:
#
#   arm <N> — run from the live desktop by `koompi-restore --full`, AFTER the
#          snapper rollback, passing the rollback's NEW snapshot number N. Drops a
#          marker (containing N) on the btrfs TOP-LEVEL subvolume (subvolid=5).
#          `snapper rollback` (root config, @ only) never touches the top-level
#          subvol, so the marker SURVIVES the @ rollback that reboots us into the
#          baseline.
#
#   run  — run at boot by the unit (BEFORE home.mount, so @home is NOT mounted).
#          If the marker exists, it confirms the running root subvol is the
#          baseline snapshot N from the marker (ASYMMETRIC-RESET GUARD, below);
#          only then does it replace @home with a fresh empty subvolume, reseed
#          each user's home from /etc/skel, and clear the marker. No marker ⇒
#          no-op (so the unit can be enabled in the baseline and fire every boot
#          harmlessly); marker present but subvol mismatch ⇒ SKIP + keep marker.
#
# Idempotent. The marker (holding N) is the single source of "do it now".

set -euo pipefail

MARKER_NAME="koompi-reset-home.flag"
TOP=/run/koompi-btrfs-top   # transient mount of the btrfs top-level subvol

log() { printf '[koompi-reset-home] %s\n' "$*"; }

# The block device backing / — strip findmnt's trailing "[/@]" subvol suffix.
# REVIEW: confirm this resolves to the bare partition (e.g. /dev/nvme0n1p2) for
# the pinned archinstall layout, incl. the LUKS-mapped case.
root_dev() { findmnt -no SOURCE / | sed 's/\[.*\]//'; }

# Path of the currently-mounted root subvolume, relative to the btrfs top level.
# On a correct rollback this is ".snapshots/<N>/snapshot"; on a no-op boot that
# stayed on old @ (the open GRUB rootflags leg) it is "@". Used by the
# asymmetric-reset guard in run(). REVIEW(VM): confirm the exact first-line format
# of `btrfs subvolume show /` on the target btrfs-progs.
# Capture the whole output then take line 1 in-shell — piping to `head` would
# close the pipe early, SIGPIPE btrfs, and (under pipefail) lose the value.
running_root_subvol() {
  local out
  out="$(btrfs subvolume show / 2>/dev/null)" || true
  printf '%s\n' "${out%%$'\n'*}"
}

mount_top() {
  mkdir -p "$TOP"
  mountpoint -q "$TOP" || mount -o subvolid=5 "$(root_dev)" "$TOP"
}
# sync before dropping the mount so the marker write / rm and any @home writes are
# durable across an abrupt power cut (this deployment loses power often).
umount_top() {
  if mountpoint -q "$TOP"; then
    sync
    umount "$TOP" || true
  fi
}

# arm <N> — N is the rollback's new snapshot number (snapper rollback
# --print-number). run() will only wipe if the next boot is actually running
# snapshot N. For manual dev testing without a real rollback: pass "any" to
# bypass the guard (NEVER in production); no arg writes an empty marker, which
# run() treats as unverified and SKIPS (the safe default).
arm() {
  local want="${1:-}"
  mount_top
  printf '%s\n' "$want" > "$TOP/$MARKER_NAME"
  umount_top
  if [ -n "$want" ]; then
    log "armed — /home erased on next boot ONLY IF it boots baseline snapshot #$want"
  else
    log "armed with EMPTY target — run() will SKIP the wipe (safe). Pass N, or 'any' for dev."
  fi
}

# ASYMMETRIC-RESET GUARD — the core safety mechanism for --full.
# History: the /home wipe used to be gated ONLY on the marker existing, with
# nothing confirming the boot had landed on the rolled-back @baseline. Combined
# with the KNOWN-OPEN GRUB rootflags=subvol=@ leg (10_linux can boot old @ despite
# the rollback), that could DELETE every user's /home while the system stayed
# un-reset — total data loss, no reset.
# Fix (IMPLEMENTED; ⚠️ detection still VM-UNVERIFIED): koompi-restore arms the
# marker AFTER the rollback, writing the rollback's snapshot number N into it.
# run() only wipes if the RUNNING root subvol is snapshot N. If old @ booted (the
# GRUB leg bit, or any other reason), it won't match → we SKIP the wipe, KEEP the
# marker, and log loudly, so a later correct boot can finish the job. This makes
# --full fail SAFE even while the GRUB leg is open. It does NOT *fix* the no-op
# boot — closing the GRUB leg is still required for --full to actually succeed
# (roadmap B4).
run() {
  mount_top
  if [ ! -e "$TOP/$MARKER_NAME" ]; then
    umount_top
    return 0
  fi

  # ── asymmetric-reset guard: only wipe if we booted the baseline snapshot N ──
  local want running running_num
  want="$(tr -d '[:space:]' < "$TOP/$MARKER_NAME" 2>/dev/null)" || want=""
  running="$(running_root_subvol)" || running=""
  running_num="$(printf '%s' "$running" | sed -nE 's#.*\.snapshots/([0-9]+)/snapshot.*#\1#p')" || running_num=""

  if [ "$want" = "any" ]; then
    log "DEV OVERRIDE: marker='any' — skipping the baseline-identity guard. Not for production."
  elif printf '%s' "$want" | grep -qE '^[0-9]+$' && [ "$want" = "$running_num" ]; then
    log "verified running baseline snapshot #$want — performing offline /home reset"
  else
    log "ASYMMETRIC-STATE GUARD: running root subvol '$running' (snapshot #${running_num:-unknown})"
    log "  != rolled-back baseline #${want:-<empty>}. SKIPPING /home wipe and KEEPING the marker"
    log "  so a correct boot can complete it. (Most likely the open GRUB rootflags=subvol=@ leg.)"
    umount_top
    return 0
  fi

  # SAFETY: the unit is ordered Before=home.mount, but guard anyway. Deleting a
  # mounted subvolume would fail; refuse loudly rather than risk a half-state.
  if mountpoint -q /home; then
    log "ABORT: /home is mounted; refusing to replace @home"
    umount_top
    return 0
  fi

  # Replace the @home subvolume with a fresh empty one. REVIEW: the name "@home"
  # is the archinstall layout (see archinstall.zig disk_config). btrfs refuses to
  # delete a subvol in use; at this boot stage it is not mounted.
  # Idempotent recreate: a prior run could have been cut mid-delete or between
  # delete and create, leaving a remnant — so delete any remnant first (ignoring
  # "not found"), THEN create. If create still fails, errexit aborts with the
  # marker KEPT, so the next boot retries rather than leaving /home half-built.
  btrfs subvolume delete "$TOP/@home" 2>/dev/null || true
  btrfs subvolume create "$TOP/@home"
  chmod 0755 "$TOP/@home"

  # Reseed each real user's home from /etc/skel. The guard above guarantees we
  # are running the rolled-back baseline, so /etc/passwd IS the baseline's — we
  # read it for UID>=1000 human accounts. REVIEW: this recreates home CONTENTS
  # only; the accounts themselves already exist in the baseline.
  while IFS=: read -r user _ uid gid _ home _; do
    [ "$uid" -ge 1000 ] && [ "$uid" -lt 60000 ] || continue
    [ "$home" = "/home/$user" ] || continue
    install -d -m 0700 "$TOP/@home/$user"
    cp -aT /etc/skel "$TOP/@home/$user" 2>/dev/null || true
    chown -R "$uid:$gid" "$TOP/@home/$user"
    log "reseeded /home/$user"
  done < /etc/passwd

  rm -f "$TOP/$MARKER_NAME"
  umount_top
  log "offline /home reset complete"
}

case "${1:-run}" in
  arm) arm "${2:-}" ;;
  run) run ;;
  *) echo "usage: $0 {arm <snapshot-number>|run}" >&2; exit 2 ;;
esac
