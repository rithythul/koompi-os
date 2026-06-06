#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# KOOMPI OS — archiso profile definition.  *** SKELETON ***
# Mirrors the structure of Arch's official `releng` profile but trimmed to the
# minimum KOOMPI needs.  Everything here is build-scaffolding: art, the signed
# [koompi] repo, the Zig installer binary, and the systemd-boot/syslinux bootloader
# config dirs are NOT yet present (see README.md "What is stubbed").
#
# This file is sourced by mkarchiso; every variable below is consumed there.

iso_name="koompi"                       # base name of the output .iso file
# Release-era codename slot.  docs/naming.md: era v1 == "Naga".  Bump per era.
codename="naga"
# Volume label burned into the ISO9660 filesystem.  Upper-cased codename + YYYYMM
# so each monthly snapshot is distinguishable.  Keep <= 32 chars, [A-Z0-9_] only.
iso_label="KOOMPI_${codename^^}_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="KOOMPI <https://koompi.org>"   # appears in ISO metadata
iso_application="KOOMPI OS Live/Install (${codename^})"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="koompi"                    # in-ISO dir holding the squashfs + kernels
buildmodes=('iso')                      # produce a bootable ISO (not netboot)
# Boot methods to assemble.  BIOS via syslinux, UEFI via systemd-boot.
# NOTE: systemd-boot for the *live* ISO is fine; the *installed* target uses GRUB
# (grub-btrfs needs GRUB) — that is the installer's job, not this profile's.
# NOTE: each mode requires a matching config dir in this profile that the SKELETON
# does NOT yet ship (efiboot/loader/, syslinux/) — see README.md.
bootmodes=(
  'bios.syslinux.mbr'                   # legacy BIOS, isohybrid MBR
  'bios.syslinux.eltorito'              # legacy BIOS, El Torito
  'uefi-x64.systemd-boot.esp'           # UEFI, systemd-boot from the ESP
  'uefi-x64.systemd-boot.eltorito'      # UEFI, systemd-boot via El Torito
)
arch="x86_64"                           # only target (spec: Arch x86_64 only)
pacman_conf="pacman.conf"               # the pacman.conf in THIS dir (injects [koompi])
airootfs_image_type="squashfs"          # live root filesystem image format
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '-19')

# File permissions/ownership applied to airootfs paths.
# Format:  ["/path"]="UID:GID:MODE"  (octal MODE).  Paths absent here keep the
# permissions they have on disk in airootfs/.
declare -A file_permissions=(
  ["/root"]="0:0:750"                                   # private root home
  ["/root/.automated_script.sh"]="0:0:755"              # live-session autostart stub
  ["/usr/local/bin/koompi-installer"]="0:0:755"         # Zig installer (built from installer/, see packages.x86_64)
  ["/etc/gshadow"]="0:0:0400"
  ["/etc/shadow"]="0:0:0400"
)
