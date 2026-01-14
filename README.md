# KOOMPI OS Base Edition

**The immutable, snapshot-based Linux foundation for education and enterprise.**

[![Build ISO](https://github.com/koompi/koompi-os/actions/workflows/build-iso.yml/badge.svg)](https://github.com/koompi/koompi-os/actions/workflows/build-iso.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

KOOMPI OS Base is a minimal, immutable Arch Linux-based operating system designed for stability and recoverability. It boots to a CLI environment and allows users to install their preferred desktop environment or use it as a robust server foundation.

> **Note:** The AI-powered tools (`koompi-cli`, `koompi-ai`) are developed in a separate repository and can be installed via AUR/PyPI. This repository focuses on the core OS architecture.

## 🎯 Key Features

- **🔒 Pragmatic Immutability**
  - Read-only root filesystem with overlayfs for configuration
  - Btrfs snapshots for instant rollback
  - Use `koompi-snapshot` to manage system states

- **🔄 Safe Atomic Updates**
  - Updates are wrapped in pre/post snapshots
  - Automatic rollback on boot failure (Watchdog)
  - Unified `koompi` command for package management

- **🛠️ TUI Installers**
  - `koompi-install`: User-friendly text-based system installer
  - `koompi-desktop`: Easy installation of KDE, GNOME, Hyprland, and more
  - `koompi-setup-btrfs`: Automatic Btrfs subvolume handling

- **✨ KOOMPI Branding**
  - Custom boot splash and prompt
  - Optimized configs for performance
  - Khmer language support out-of-the-box

- **🛡️ Integrated Security**
  - `koompi-security`: One-command system hardening
  - UFW Firewall, AppArmor, and Fail2ban pre-configured
  - Secure Boot management via `sbctl`

## 🚀 Quick Start

### 1. Installation
Boot the ISO and run:
```bash
koompi-install
```
Follow the TUI prompts to partition, select locale, set passwords, and install.

### 2. After First Boot
Login with the user you created.

**Install a Desktop Environment:**
```bash
koompi-desktop
```
Choose from:
- **KOOMPI Editions**: **Tiling (Hyprland)** - Now pre-installed for instant setup! 🚀
- **Community**: KDE, GNOME, XFCE, Cinnamon, i3, Sway, etc.

**Manage Packages:**
```bash
koompi install firefox    # Install from repos or AUR
koompi remove firefox
koompi search browser
```

**System Update:**
```bash
koompi update
# Or
koompi upgrade
```
*Creates a snapshot -> Updates system ->Updates bootloader -> Cleans old snapshots*

**Manage Snapshots:**
```bash
koompi-snapshot list
koompi-snapshot create "Before experiment"
koompi-snapshot rollback <id>
```

## 🗂️ Project Structure

```
koompi-os/
├── iso/                    # archiso build profile
│   ├── packages.x86_64     # Core package list
│   ├── airootfs/           # Live system overlay
│   │   ├── etc/            # System configs (motd, issue, etc)
│   │   └── usr/local/bin/  # Core scripts (koompi-*)
│   └── profiledef.sh       # ISO definition
├── scripts/                # Build helper scripts
└── docs/                   # Documentation
```

## 🛠️ Building from Source

Requirements: Arch Linux (or derivative), `archiso` package.

```bash
# 1. Clone the repository
git clone https://github.com/koompi/koompi-os.git
cd koompi-os

# 2. Build the ISO
sudo ./scripts/build-iso.sh

# 3. Test in VM (Requires QEMU)
./scripts/test-vm.sh out/koompi-os-base-*.iso
```

## 📄 License
MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Links
- Website: https://koompi.com
- Documentation: https://docs.koompi.com
- Community: [Discord](https://discord.gg/koompi)
