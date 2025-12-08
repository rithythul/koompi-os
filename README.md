# KOOMPI OS

**The operating system that teaches, protects, and connects.**

[![Build ISO](https://github.com/koompi/koompi-os/actions/workflows/build-iso.yml/badge.svg)](https://github.com/koompi/koompi-os/actions/workflows/build-iso.yml)
[![Rust](https://img.shields.io/badge/rust-stable-orange.svg)](https://www.rust-lang.org/)
[![Python](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

KOOMPI OS is a Linux distribution built on Arch Linux, designed for education with AI-powered assistance, immutable system architecture, and offline-first capabilities.

## Features

- 🔒 **Immutable System** - Btrfs snapshots with automatic rollback
- 🚀 **KOOMPI Shell** - Custom Rust-based Wayland compositor (Smithay + Iced)
- 🤖 **Cloud AI** - Powered by Google Gemini API (low RAM usage)
- 🎨 **Hybrid UI** - Best of Windows, macOS, and Mobile interfaces
- 🎤 **Voice Control** - Khmer and English voice recognition
- 📡 **Classroom Mesh** - Offline P2P file sharing for schools
- 📦 **Smart Updates** - AI-tested, staged rollouts

## Quick Start

### Download ISO

Get the latest release from [Releases](https://github.com/koompi/koompi-os/releases).

### Build from Source

```bash
# Clone the repository
git clone https://github.com/koompi/koompi-os.git
cd koompi-os

# Install build dependencies (Arch Linux)
sudo pacman -S archiso rust python python-pip

# Build the ISO
./scripts/build-iso.sh

# Output: out/koompi-os-YYYY.MM-x86_64.iso
```

### Test in VM

```bash
./scripts/test-vm.sh
```

### Flash to USB

```bash
sudo dd if=out/koompi-os-*.iso of=/dev/sdX bs=4M status=progress
```

## Project Structure

```
koompi-os/
├── rust/                   # Core system components (Rust)
│   ├── koompi-daemon/      # Main system service
│   ├── koompi-shell/       # Custom Wayland compositor
│   ├── koompi-snapshots/   # Btrfs snapshot manager
│   ├── koompi-packages/    # Package management
│   ├── koompi-mesh/        # Classroom networking
│   └── koompi-ffi/         # Python bindings
├── python/                 # AI and user-facing tools
│   ├── koompi-ai/          # LLM and voice integration
│   ├── koompi-cli/         # Command-line interface
│   └── koompi-chat/        # Desktop chat application
├── iso/                    # archiso build profile
├── installer/              # Calamares installer config
├── packages/               # PKGBUILD definitions
├── configs/                # Desktop customization
└── scripts/                # Build and test scripts
```

## Development

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
rustup component add clippy rustfmt

# Setup Python
python -m venv .venv
source .venv/bin/activate
pip install -e python/koompi-ai -e python/koompi-cli -e python/koompi-chat
pip install -r requirements-dev.txt

# Build Rust components
cd rust && cargo build --release

# Run tests
cargo test
pytest python/
```

### Building Packages

```bash
# Build all custom packages
./scripts/build-packages.sh

# Packages output to: packages/repo/
```

## Architecture

| Component | Language | Purpose |
|-----------|----------|---------|
| koompi-daemon | Rust | System service, D-Bus API |
| koompi-shell | Rust | Wayland Compositor & UI |
| koompi-snapshots | Rust | Btrfs operations, rollback |
| koompi-packages | Rust | Package management |
| koompi-mesh | Rust | P2P classroom networking |
| koompi-ai | Python | Gemini API, voice recognition |
| koompi-cli | Python | User CLI |
| koompi-chat | Python+Qt | Desktop AI assistant |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- Website: https://koompi.org
- Documentation: https://docs.koompi.org
- Discord: [KOOMPI Community](https://discord.gg/koompi)
