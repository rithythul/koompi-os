# KOOMPI OS

**The operating system that teaches, protects, and connects.**

[![Build ISO](https://github.com/koompi/koompi-os/actions/workflows/build-iso.yml/badge.svg)](https://github.com/koompi/koompi-os/actions/workflows/build-iso.yml)
[![Rust](https://img.shields.io/badge/rust-stable-orange.svg)](https://www.rust-lang.org/)
[![Python](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

KOOMPI OS is a Linux distribution built on Arch Linux, designed for education with AI-powered assistance, immutable system architecture, and offline-first capabilities.

## 🎯 Branch Strategy

| Branch          | Purpose                                       |
| --------------- | --------------------------------------------- |
| `main`          | Base OS: daemon, snapshots, packages, AI, CLI |
| `koompi-shell`  | Custom Rust compositor (Smithay + Iced)       |
| `koompi-kde`    | KDE Plasma integration                        |
| `koompi-apps`   | File manager, chat, utilities                 |
| `koompi-edu`    | Classroom mesh networking, teacher/student    |
| `koompi-office` | Office suite                                  |
| `koompi-docs`   | Whitepapers, architecture vision, roadmap     |

## 📊 Development Status

| Phase                  | Status       | Progress                                  |
| ---------------------- | ------------ | ----------------------------------------- |
| Bootable Foundation    | ✅ Complete  | ISO build, Btrfs, bootloader              |
| Core Daemon            | ✅ Complete  | D-Bus, snapshot, package integration      |
| Package Management     | 🟡 In Progress | Pacman ✓, AUR pending, Flatpak partial  |
| Snapshot & Immutability| 🟡 In Progress | Basic operations ✓, auto-rollback pending|
| AI Integration         | ✅ Complete  | Gemini API, offline KB, voice recognition |
| CLI Tool               | 🟡 In Progress | Structure ✓, core commands pending      |
| Testing & Quality      | 🔴 Not Started| Rust tests, Python tests, CI/CD          |

## ✨ Features

### Core System (`main` branch)

- 🔒 **Immutable System** - Btrfs snapshots with automatic rollback
- 🤖 **AI Assistant** - Powered by Google Gemini API + offline SQLite knowledge base
- 📦 **Smart Package Management** - Pacman + AUR + Flatpak with auto-snapshots
- ⚡ **Minimal Footprint** - Headless base for servers or custom builds
- �️ **Self-Healing** - Auto-rollback on 3 failed boots (planned)

### Desktop Environments

- 🎨 **Custom Shell** (`koompi-shell`) - Rust compositor with Smithay + Iced
- 🖥️ **KDE Edition** (`koompi-kde`) - Full Plasma desktop experience

### Applications & Tools

- 📁 **KOOMPI Apps** (`koompi-apps`) - File manager, chat, utilities
- 📝 **Office Suite** (`koompi-office`) - Productivity applications
- 🎓 **Education Tools** (`koompi-edu`) - Classroom mesh networking, teacher/student mode

## 🚀 Quick Start

### Download

Get the latest release from [Releases](https://github.com/koompi/koompi-os/releases):

- `koompi-os-base-*.iso` - Minimal headless edition (main branch)
- `koompi-os-kde-*.iso` - KDE Plasma edition (coming soon)

### After Boot

```bash
# Default Login: koompi / koompi

# Set up AI assistant
koompi ai setup

# Install packages with auto-snapshot
koompi install firefox

# Update system
koompi update

# Create manual snapshot
koompi snapshot create "before-upgrade"

# Ask AI for help
koompi ai "how do I install KDE desktop?"
koompi ai "what is the Windows equivalent of grep?"
```

### Build from Source

```bash
# Clone the repository
git clone https://github.com/koompi/koompi-os.git
cd koompi-os

# Build base ISO
./scripts/build-iso.sh

# For feature branches (when available)
git checkout koompi-kde && ./scripts/build-iso.sh
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
