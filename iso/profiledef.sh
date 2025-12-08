#!/usr/bin/env bash
# KOOMPI OS ISO Profile Definition

iso_name="koompi-os"
iso_label="KOOMPI_OS_$(date +%Y%m)"
iso_publisher="SmallWorld <https://koompi.org>"
iso_application="KOOMPI OS Live/Installer"
iso_version="$(date +%Y.%m)"
install_dir="koompi"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/usr/local/bin/koompi-install"]="0:0:755"
  ["/usr/local/bin/koompi-shell"]="0:0:755"
  ["/usr/local/bin/koompi-daemon"]="0:0:755"
)
