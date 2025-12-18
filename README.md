# KOOMPI OS

**The operating system that teaches, protects, and connects.**

[![Build ISO](https://github.com/koompi/koompi-os/actions/workflows/build-iso.yml/badge.svg)](https://github.com/koompi/koompi-os/actions/workflows/build-iso.yml)
[![Rust](https://img.shields.io/badge/rust-stable-orange.svg)](https://www.rust-lang.org/)
[![Python](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

KOOMPI OS is a Linux distribution built on Arch Linux, designed for education with AI-powered assistance, immutable system architecture, and offline-first capabilities.

## 🎯 Branch Strategy

| Branch         | Description                               | Desktop              | Target Users             |
| -------------- | ----------------------------------------- | -------------------- | ------------------------ |
| `main`         | **Base Edition** - Minimal Arch + AI CLI  | None (install later) | Advanced users, servers  |
| `koompi-kde`   | **KDE Edition** - Full desktop experience | KDE Plasma           | General users, education |
| `koompi-gnome` | GNOME Edition (planned)                   | GNOME                | Coming soon              |

## ✨ Features

### All Editions

- 🔒 **Immutable System** - Btrfs snapshots with automatic rollback
- 🤖 **AI Assistant** - Powered by Google Gemini API
- 📦 **Smart Package Management** - Pacman + AUR + Flatpak
- 🖥️ **Cross-Platform Knowledge** - Learn Linux, Windows, macOS

### Base Edition (main branch)

- ⚡ **Minimal** - ~500MB ISO, boots to CLI
- 🛠️ **Build Your Own** - Install only what you need
- 💬 **AI CLI** - Natural language: `koompi help me install KDE`

### KDE Edition (koompi-kde branch)

- 🎨 **Full Desktop** - KDE Plasma with KOOMPI theming
- 📡 **Classroom Mesh** - P2P file sharing for schools
- 🎤 **Voice Control** - Khmer and English recognition
- 🖥️ **Calamares Installer** - Graphical installation

## 🚀 Quick Start

### Download

Get the latest release from [Releases](https://github.com/koompi/koompi-os/releases):

- `koompi-os-base-*.iso` - Minimal CLI edition
- `koompi-os-kde-*.iso` - Full KDE desktop

### After Boot (Base Edition)

```bash
# Login: koompi / koompi

# Set up AI (optional but recommended)
koompi-setup-ai

# Ask for help naturally
koompi help me install firefox
koompi how do I update the system
koompi what is the windows equivalent of grep

# Install a desktop (if desired)
koompi desktop kde    # Full KDE Plasma
koompi desktop gnome  # GNOME
koompi desktop xfce   # Lightweight XFCE
```

### Build from Source

```bash
# Clone the repository
git clone https://github.com/koompi/koompi-os.git
cd koompi-os

# Build Base Edition (main branch)
./scripts/build-iso.sh

# Build KDE Edition
git checkout koompi-kde
./scripts/build-iso.sh
```

## 🗂️ Project Structure

```
koompi-os/
├── iso/                    # archiso build profile
│   ├── packages.x86_64     # Package list (minimal for base)
│   ├── airootfs/           # Overlay files for live ISO
│   └── profiledef.sh       # Build configuration
├── rust/                   # Core system components (Rust)
│   ├── daemon/             # Main system service
│   ├── snapshots/          # Btrfs snapshot manager
│   ├── packages/           # Package management
│   ├── mesh/               # Classroom networking
│   └── ffi/                # Python bindings (PyO3)
├── python/                 # AI and user-facing tools
│   ├── koompi-ai/          # LLM integration (Gemini)
│   ├── koompi-cli/         # Command-line interface
│   └── koompi-chat/        # Desktop chat application
├── packages/               # PKGBUILD definitions
├── scripts/                # Build and test scripts
└── docs/                   # Documentation & whitepapers
```

## 🔧 Development

### Prerequisites

- Arch Linux (or Arch-based distro) for building
- Rust (latest stable)
- Python 3.12+
- archiso package

### Setup Development Environment

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable

# Setup Python
python -m venv .venv
source .venv/bin/activate
pip install -e python/koompi-ai -e python/koompi-cli -e python/koompi-chat

# Build Rust components
cd rust && cargo build --release

# Run tests
cargo test
pytest python/
```

## 🏗️ Architecture

### Layered CLI Design

```
┌─────────────────────────────────────────────────────────┐
│  Layer 3: koompi-chat (Qt6 GUI)                         │
│  • Rich graphical interface                             │
│  • For desktop users                                    │
├─────────────────────────────────────────────────────────┤
│  Layer 2: koompi-cli (Python + Click + Rich)            │
│  • Natural language: "koompi help me install firefox"   │
│  • AI-powered assistance                                │
│  • Beautiful terminal output                            │
├─────────────────────────────────────────────────────────┤
│  Layer 1: /usr/local/bin/koompi (Bash)                  │
│  • Always works, even if Python broken                  │
│  • Emergency recovery commands                          │
│  • Routes to Python when available                      │
└─────────────────────────────────────────────────────────┘
```

### AI Knowledge Base

The KOOMPI AI assistant has comprehensive knowledge of:

- **Arch Linux** - pacman, AUR, PKGBUILD, systemd
- **KOOMPI OS** - Btrfs snapshots, immutability, rollback
- **Linux in general** - Ubuntu, Fedora, file systems, commands
- **Windows** - PowerShell, CMD equivalents for Linux users
- **macOS** - Homebrew, terminal, for transitioning users
- **Programming** - Python, Rust, JavaScript, and more

### Component Overview

| Component        | Language  | Purpose                      |
| ---------------- | --------- | ---------------------------- |
| koompi-daemon    | Rust      | System service, D-Bus API    |
| koompi-snapshots | Rust      | Btrfs operations, rollback   |
| koompi-packages  | Rust      | Package management           |
| koompi-mesh      | Rust      | P2P classroom networking     |
| koompi-ffi       | Rust      | Python bindings (PyO3)       |
| koompi-ai        | Python    | Gemini API, offline fallback |
| koompi-cli       | Python    | CLI with natural language    |
| koompi-chat      | Python+Qt | Desktop AI assistant         |

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Links

- Website: https://koompi.org
- Documentation: https://docs.koompi.org
- Discord: [KOOMPI Community](https://discord.gg/koompi)
