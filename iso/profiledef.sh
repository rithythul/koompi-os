#!/usr/bin/env bash
# KOOMPI OS Base Edition - ISO Profile Definition
# This is the minimal base ISO - no desktop environment included
# For KDE edition, see the koompi-kde branch

iso_name="koompi-os-base"
iso_label="KOOMPI_$(date +%Y%m)"
iso_publisher="KOOMPI <https://koompi.com>"
iso_application="KOOMPI OS Base - Minimal Arch + AI CLI"
iso_version="$(date +%Y.%m)"
install_dir="koompi"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')

# File permissions for KOOMPI tools
file_permissions=(
  ["/usr/local/bin/koompi"]="0:0:755"
  ["/usr/local/bin/koompi-desktop"]="0:0:755"
  ["/usr/local/bin/koompi-install"]="0:0:755"
  ["/usr/local/bin/koompi-snapshot"]="0:0:755"
  ["/usr/local/bin/koompi-update"]="0:0:755"
  ["/usr/local/bin/koompi-watchdog"]="0:0:755"
  ["/usr/local/bin/koompi-setup-btrfs"]="0:0:755"
  ["/usr/local/bin/koompi-security"]="0:0:755"
  ["/usr/local/bin/koompi-apply-config"]="0:0:755"
  ["/root/customize_airootfs.sh"]="0:0:755"
)
