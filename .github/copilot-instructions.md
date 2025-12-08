# KOOMPI OS AI Coding Guidelines

## Project Overview

KOOMPI OS is an **immutable, AI-powered Linux distribution** built on Arch Linux, designed for education with offline-first capabilities. The system uses **Btrfs snapshots** for automatic rollback and combines **Rust core services** with **Python AI/tooling**.

## Architecture Essentials

### Multi-Language Design Pattern

- **Rust** (`rust/`): System-critical components requiring memory safety and performance
  - `koompi-daemon`: Main system service with D-Bus API
  - `koompi-shell`: Custom Wayland compositor (Smithay) & UI (Iced)
  - `koompi-snapshots`: Btrfs snapshot/rollback management
  - `koompi-packages`: Unified package manager (Pacman/AUR/Flatpak)
  - `koompi-mesh`: Classroom P2P networking
  - `koompi-ffi`: PyO3 Python bindings

- **Python** (`python/`): AI integration and user-facing tools
  - `koompi-ai`: AI integration using **Google Gemini API** (cloud-first)
  - `koompi-cli`: Rich CLI using `koompi_core` FFI bindings
  - `koompi-chat`: Qt-based AI assistant

### Cross-Language Communication

Python calls Rust via `koompi_core` module (PyO3 FFI). Pattern:
```python
import koompi_core
snapshot_id = koompi_core.create_snapshot("name", "description")
```

Rust implementations wrap async operations in blocking tokio runtime for Python compatibility (see [koompi-ffi/src/lib.rs](rust/koompi-ffi/src/lib.rs)).

### Immutable System Design

System root is read-only Btrfs snapshot (`@root-current`). Updates create new snapshots. User data (`/home`, `/var`) on separate read-write subvolumes. See [snapshot manager](rust/koompi-snapshots/src/lib.rs).

**Critical**: Always create pre-operation snapshots for system-modifying actions (package installs, updates).

## Development Workflows

### Building Components

```bash
# Rust components
cd rust && cargo build --release
cargo test  # Run Rust tests

# Python packages (editable install for dev)
python -m venv .venv && source .venv/bin/activate
pip install -e python/koompi-ai -e python/koompi-cli

# Full ISO build (requires root, archiso)
sudo ./scripts/build-iso.sh
```

**Important**: [build-iso.sh](scripts/build-iso.sh) orchestrates multi-stage build: Rust → Python → custom packages → archiso. Each stage can be run independently: `./scripts/build-iso.sh rust|python|packages|iso`.

### Testing in VM

Use [scripts/test-vm.sh](scripts/test-vm.sh) to launch built ISO in QEMU for validation.

### D-Bus Service Architecture

The daemon exposes methods via D-Bus at `org.koompi.Daemon`. See [dbus.rs](rust/koompi-daemon/src/dbus.rs) for interface definition. Methods return JSON-serialized results for cross-process compatibility.

Start daemon: `koompid --foreground --log-level debug` (requires systemd service normally).

## Code Standards

- **Rust**:
  - Formatter: `rustfmt`
  - Linter: `clippy`
  - Error Handling: `thiserror` (lib) + `anyhow` (app)
  - Async: `tokio` runtime
- **Python**:
  - Formatter: `black` (line length 88)
  - Linter: `ruff`, `mypy`
  - Docstrings: Google style
  - Type Hints: Required (PEP 484)

## Project-Specific Conventions

### Error Handling

- **Rust**: Use `thiserror` for error enums, `anyhow` for application errors
- **Python**: Let exceptions propagate from FFI; catch at CLI boundary with rich error formatting

### Logging

- **Rust**: `tracing` crate with structured logging (`tracing::info!(snapshot_id = %id, "message")`)
- **Python**: Standard `logging` module

### Configuration

- Daemon config: `/etc/koompi/daemon.toml` (see [service.rs](rust/koompi-daemon/src/service.rs) for schema)
- AI config: API keys managed via secure storage (see [llm.py](python/koompi-ai/koompi_ai/llm.py))

### Intent Classification

The AI assistant uses **rule-based pattern matching** before calling Gemini API. Add new intents to [intent.py](python/koompi-ai/koompi_ai/intent.py) `PATTERNS` dict with regex patterns. Supports Khmer language patterns.

### Snapshot Lifecycle

1. **Creation**: `SnapshotManager::create()` checks space, applies retention policy, creates readonly snapshot
2. **Types**: `PreUpdate`, `PreInstall`, `Manual`, `Scheduled`, `PreRollback`
3. **Retention**: Configurable max count (default 10), oldest deleted first
4. **Rollback**: Creates `PreRollback` snapshot first, updates bootloader, requires reboot

See [lib.rs](rust/koompi-snapshots/src/lib.rs) for full flow.

### Package Manager Backend Selection

`PackageManager::install()` auto-detects backend:
1. Check Pacman (official repos) first
2. Try Flatpak (sandboxed apps)
3. Fall back to AUR (community packages)

Override with explicit `Backend` parameter. Always creates pre-install snapshot.

## Common Patterns

### Async Rust → Python FFI

```rust
#[pyfunction]
fn my_function() -> PyResult<String> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async {
        // async Rust code here
    })
}
```

### CLI Command Structure

New CLI commands in [main.py](python/koompi-cli/koompi_cli/main.py):
```python
@cli.group()
def mygroup():
    """Group description."""
    pass

@mygroup.command("action")
def my_action():
    """Action description."""
    import koompi_core
    # Use FFI bindings
```

### AI Query with Fallback

```python
from koompi_ai import query

response = await query(prompt, use_cloud_fallback=True)
# response.text, response.source ("local"/"cloud"), response.confidence
```

## Critical Files

- [Cargo.toml](rust/Cargo.toml): Workspace-level Rust dependencies
- [profiledef.sh](iso/profiledef.sh): archiso build configuration
- [packages.x86_64](iso/packages.x86_64): ISO package manifest
- [daemon.toml](iso/airootfs/etc/koompi/daemon.toml): Default daemon config
- [Part2-Architecture.md](papers/KOOMPI-OS-Whitepaper-Part2-Architecture.md): Comprehensive architecture reference

## ISO Packaging

The `iso/` directory follows archiso structure:
- `airootfs/`: Files copied to live system (overlay)
- `packages.x86_64`: Packages installed in ISO
- `profiledef.sh`: Build metadata and permissions

Custom packages built separately and added to local repo before ISO build.

## Classroom Mesh Networking

Uses Avahi (mDNS) for discovery, Syncthing for P2P file sync. Teacher device broadcasts, students peer-sync. Offline-capable (no internet required). Implementation in [koompi-mesh](rust/koompi-mesh).

## When Adding Features

1. **System operations**: Implement in Rust crate, expose via FFI
2. **AI/NLP features**: Implement in `koompi-ai`, add intent patterns
3. **User commands**: Add to `koompi-cli` using FFI bindings
4. **ISO changes**: Update `packages.x86_64` and `airootfs/` overlay

## Testing Strategy

- **Rust**: `cargo test` (Unit 60%, Integration 30%). Use `proptest` for property-based testing.
- **Python**: `pytest` with `pytest-cov`. Target >80% coverage.
- **System**: Build ISO and test in VM with [test-vm.sh](scripts/test-vm.sh) (E2E 10%).
- **Manual**: Run daemon in foreground, test D-Bus calls with `busctl`.

## AI Agent Instructions

- **General**: Follow code standards strictly. Write comprehensive tests. Document all public functions. Use type hints always.
- **Package Development**: Reference requirement IDs (e.g., CORE-001) if available. Check dependencies. TDD approach.
- **ISO Building**: Use `archiso` as base. Test in VM before hardware. Verify package installation.
- **AI Features**: Use **Gemini API**. Handle slow internet gracefully (retries, caching). No local LLM required.
- **Classroom Features**: Verify offline operation. Ensure teacher controls work. Handle network interruptions.
- **UI/UX**: Implement **Hybrid Design Strategy** using **Rust (Smithay + Iced)**:
  - **Shell**: Custom Wayland compositor built with `Smithay`.
  - **Toolkit**: `Iced` for high-performance, type-safe UI components.
  - **Layout**: Bottom panel with App Drawer + Centered task manager.
  - **Launcher**: Rich grid of icons (App Drawer).
  - **Search**: Center-screen "Spotlight-style" search (Super key).
  - **Theme**: Auto-switch (Day/Night) default, customizable. **Abstract/Geometric** default wallpaper.
  - **Icons**: **Uniform Squircle shape** for a friendly, modern, and consistent look.
  - **Typography**: **Roboto** (English) + **Noto Sans Khmer** (Khmer) for optimal legibility.
  - **Boot**: Animated **KOOMPI logo assembly**.
  - **Cursor**: High-visibility **Black arrow with white border** (better for projectors).
  - **Sound**: Custom sound theme (Startup, Notifications) to reinforce brand identity.
  - **Window Mgmt**: Strong snapping/tiling support.
  - **Unified Experience**: Same visual design for all roles (Student/Teacher/Dev), differentiated only by permissions/apps.
  - **Lockdown**: Use **KOOMPI Shell Kiosk Mode** for student sessions (unbreakable Rust-based lock).
