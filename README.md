# KOOMPI OS - Base Edition

**The minimal, immutable Linux foundation - build your perfect system.**

[![Build ISO](https://github.com/rithythul/koompi-os/actions/workflows/build-iso.yml/badge.svg)](https://github.com/rithythul/koompi-os/actions/workflows/build-iso.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

KOOMPI OS Base is a minimal, CLI-only Arch Linux-based system designed for users who want to choose their own desktop environment. It provides the stable, snapshot-based foundation - you add what you want.

## 🎯 Key Features

### 🔒 Immutable Foundation
- Btrfs snapshots for instant rollback
- Automatic snapshot before updates
- Boot failure watchdog with auto-recovery
- Use `koompi-snapshot` to manage system states

### 🛠️ Choose Your Desktop
After installation, use `koompi-desktop` to install:

| Type | Options |
|------|---------|
| **KOOMPI Editions** | Tiling (Hyprland), KDE, GNOME |
| **Community** | XFCE, Cinnamon, MATE, i3, Sway, etc. |

### 📦 Unified Package Manager
```bash
koompi install <package>    # Repos + AUR
koompi remove <package>
koompi search <query>
koompi update               # Safe update with snapshot
```

### 🛡️ Security Ready
- UFW Firewall, AppArmor, Fail2ban included
- Secure Boot support via sbctl
- `koompi-security` for one-command hardening

## 🚀 Quick Start

### 1. Installation
Boot the ISO and run:
```bash
koompi-install
```
Follow the TUI prompts.

### 2. Install a Desktop
```bash
koompi-desktop
```
Select from KOOMPI editions or community desktops.

### 3. Manage Your System
```bash
koompi update                    # Update with snapshot
koompi-snapshot list             # View snapshots
koompi-snapshot rollback <id>    # Restore previous state
```

## 🗂️ Branches

| Branch | Description |
|--------|-------------|
| `baseOS` | **This branch** - Minimal CLI, choose your DE |
| `koompi-kde` | KDE Plasma Edition - Ready to use |

## 🛠️ Building from Source

```bash
# Clone & checkout
git clone https://github.com/rithythul/koompi-os.git
cd koompi-os
git checkout baseOS

# Build ISO
sudo ./scripts/build-iso.sh clean && sudo ./scripts/build-iso.sh all

# Test in VM
./scripts/test-vm.sh out/koompi-os-*.iso
```

## 📄 License
MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Links
- Website: https://koompi.com
- Documentation: https://docs.koompi.com
