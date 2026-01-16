#!/usr/bin/env bash
# KOOMPI OS KDE Edition - ISO Profile Definition
# Pre-installed KDE Plasma desktop with KOOMPI branding

iso_name="koompi-os"
iso_label="KOOMPI_$(date +%Y%m)"
iso_publisher="KOOMPI <https://koompi.com>"
iso_application="KOOMPI OS - KDE Plasma Edition"
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
