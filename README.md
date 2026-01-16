# KOOMPI OS - KDE Plasma Edition

**The beautiful, immutable Linux desktop for everyone.**

[![Build ISO](https://github.com/rithythul/koompi-os/actions/workflows/build-iso.yml/badge.svg)](https://github.com/rithythul/koompi-os/actions/workflows/build-iso.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

KOOMPI OS KDE Edition is a fully pre-configured KDE Plasma desktop built on an immutable Arch Linux foundation. It combines the beauty and power of KDE Plasma with KOOMPI's snapshot-based stability.

## 🎯 Key Features

### 🖥️ Beautiful Desktop
- **KDE Plasma** desktop environment pre-installed
- **KOOMPI Branding**: Custom wallpaper, menu icon, top panel layout
- **Windows-style** window decoration (buttons on right)
- **Clean Konsole** with hidden toolbars and JetBrains Mono font

### 🔒 Immutable & Stable
- Btrfs snapshots for instant rollback
- Automatic snapshot before updates
- Boot failure watchdog with auto-recovery

### 🛠️ Easy Installation
- **Calamares** graphical installer (from live USB)
- **koompi-install** TUI installer (alternative)
- Btrfs with proper subvolumes configured automatically

### 📦 Pre-installed Apps
- Firefox browser
- Dolphin, Konsole, Kate, Spectacle, Gwenview, Okular
- Full KDE suite (system settings, KWallet, etc.)

### 🛡️ Security Ready
- UFW Firewall, AppArmor, Fail2ban included
- Secure Boot support via sbctl

## 🚀 Quick Start

### Installation
1. Boot the ISO from USB
2. Click **"Install KOOMPI OS"** on desktop (or run `calamares`)
3. Follow the graphical installer

### After First Boot
```bash
# Install packages
koompi install <package>

# Update system (with automatic snapshot)
koompi update

# Rollback if needed
koompi-snapshot list
koompi-snapshot rollback <id>
```

## 🗂️ Branches

| Branch | Description |
|--------|-------------|
| `koompi-kde` | **This branch** - KDE Plasma Edition |
| `baseOS` | Minimal base - CLI only, choose your own DE |

## 🛠️ Building from Source

```bash
# Clone & checkout
git clone https://github.com/rithythul/koompi-os.git
cd koompi-os
git checkout koompi-kde

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
