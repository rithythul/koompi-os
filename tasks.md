# KOOMPI OS Development Tasks

**Goal:** Build a fully functional, immutable Linux OS with a custom Rust-based desktop shell.
**Priority:** Shell functionality first (like KDE/macOS/Windows), then AI/Mesh features.
**Strategy:** Build a complete desktop experience before adding advanced features.
**Reference:** See `papers/` for full architecture and roadmap details.

---

## 🟢 Phase 1: Bootable Foundation (Milestone M1) ✅
**Objective:** A bootable ISO that runs our custom Rust binary.
**Status:** COMPLETE

### Day 1-4: ISO & Boot
- [x] **Task 1.1**: Fix `rust/koompi-shell/Cargo.toml` dependencies.
- [x] **Task 1.2**: Write minimal `src/main.rs` with tracing.
- [x] **Task 2.1**: Configure `scripts/build-iso.sh` with `mkarchiso`.
- [x] **Task 3.1**: Boot ISO in QEMU, verify login.
- [x] **Task 4.1**: Create systemd service for auto-start shell.

---

## 🟢 Phase 2: Wayland Compositor Core (KOOMPI Shell) ✅
**Objective:** A working Wayland compositor that can run applications.
**Status:** COMPLETE (winit backend) - Alt+Tab/Workspaces deferred to Phase 7

### Day 5-6: Smithay Foundation
- [x] **Task 5.1**: Initialize Smithay `winit` backend.
- [x] **Task 5.2**: Handle keyboard/mouse input events.
- [ ] **Task 5.3**: Switch to DRM/KMS backend for real hardware. (Phase 7)

### Day 7-8: XDG Shell & Window Management
- [x] **Task 7.1**: Implement `XdgShell` support.
- [x] **Task 7.2**: Launch terminal as a window.
- [x] **Task 7.3**: Implement window focus (click-to-focus).
- [x] **Task 7.4**: Implement window movement (drag title bar).
- [x] **Task 7.5**: Implement window resizing (drag edges/corners).
- [x] **Task 7.6**: Implement window minimize/maximize/close.
- [x] **Task 7.7**: Implement window snapping (half-screen left/right).

### Day 9-10: Multi-Window & Workspaces
- [x] **Task 9.1**: Support multiple windows simultaneously.
- [x] **Task 9.2**: Implement window stacking (z-order).
- [ ] **Task 9.3**: Implement Alt+Tab window switcher. (Phase 7)
- [ ] **Task 9.4**: Implement virtual workspaces. (Phase 7)

---

## 🟢 Phase 3: Desktop Shell UI (Panel + Launcher) ✅
**Objective:** A complete desktop UI like KDE/GNOME/macOS.
**Status:** COMPLETE (basic UI) - Search/.desktop launcher deferred to Phase 7

### Day 11-12: Top Panel (macOS Style)
- [x] **Task 11.1**: Create tiny-skia based panel (top, 40px height).
- [x] **Task 11.2**: KOOMPI menu button (left side).
- [ ] **Task 11.3**: Task manager (running apps in panel). (Phase 7)
- [x] **Task 11.4**: System tray: clock, battery, wifi, volume.
- [x] **Task 11.5**: Panel always-on-top rendering.

### Day 13-14: Application Launcher
- [x] **Task 13.1**: Popup app launcher (KOOMPI button click).
- [ ] **Task 13.2**: Search bar with fuzzy matching. (Phase 7)
- [ ] **Task 13.5**: Launch apps from `.desktop` files. (Phase 7)

### Day 15-16: Window Decorations
- [x] **Task 15.1**: Server-side window decorations (title bar).
- [x] **Task 15.2**: Close/Maximize/Minimize buttons.
- [x] **Task 15.3**: Resize handles on window edges.

---

## 🟢 Phase 4: Wayland Client Protocol ✅
**Objective:** Real applications can connect and display windows.
**Status:** COMPLETE

### Day 17-18: Core Protocols
- [x] **Task 17.1**: wl_compositor protocol.
- [x] **Task 17.2**: xdg_shell protocol (xdg_wm_base).
- [x] **Task 17.3**: wl_shm (shared memory buffers).
- [x] **Task 17.4**: wl_seat (keyboard/pointer input).
- [x] **Task 17.5**: wl_output (monitor info to clients).
- [x] **Task 17.6**: Render actual client surface textures.
- [x] **Task 17.7**: zwp_linux_dmabuf_v1 (GPU buffer sharing).
- [x] **Task 17.8**: on_commit_buffer_handler for buffer import.
- [x] **Task 17.9**: Add keyboard + pointer to wl_seat.

### Day 19-20: Client Testing
- [x] **Task 19.1**: Test with `wayland-info` tool.
- [x] **Task 19.2**: Run kitty terminal successfully.

---

## 🟢 Phase 5: System Integration ✅
**Objective:** Core OS functionality for daily use.
**Status:** COMPLETE

### Day 21-22: Settings & Configuration
- [x] **Task 21.1**: Settings app (Iced-based koompi-settings).
- [x] **Task 21.2**: Display settings (resolution, scaling).
- [x] **Task 21.3**: Appearance (wallpaper, theme, fonts).
- [x] **Task 21.4**: Sound settings (volume, output device).
- [x] **Task 21.5**: Network settings (WiFi connection).

### Day 23-24: File Manager
- [x] **Task 23.1**: Basic file browser (koompi-files).
- [x] **Task 23.2**: Navigate directories.
- [x] **Task 23.3**: Open files with default apps.

### Day 25-26: Notifications & Popups
- [x] **Task 25.1**: Notification daemon (notifications.rs).
- [x] **Task 25.2**: Toast notifications (top-right).
- [x] **Task 25.3**: Volume/brightness OSD.
- [x] **Task 25.4**: Screenshot tool (PrtSc key).

### Day 27-28: Login & Lock Screen
- [x] **Task 27.1**: Login screen (greetd + tuigreet).
- [x] **Task 27.2**: Lock screen (Super+L).
- [x] **Task 27.3**: Power menu (Ctrl+Alt+Del).

---

## 🟣 Phase 6: Core System Services
**Objective:** Immutability, snapshots, and package management.
**Status:** PARTIAL (code exists, needs UI integration)

### Day 29-30: Daemon & D-Bus
- [x] **Task 29.1**: `koompi-daemon` with D-Bus interface.
- [x] **Task 29.2**: `GetSystemStats()` method.
- [ ] **Task 29.3**: Integrate daemon with shell.

### Day 31-32: Btrfs Snapshots
- [x] **Task 31.1**: `koompi-snapshots` Btrfs wrapper.
- [x] **Task 31.2**: `create_snapshot()` and `rollback()`.
- [ ] **Task 31.3**: Snapshot manager UI in Settings.

### Day 33-34: Package Manager
- [x] **Task 33.1**: `koompi-packages` (Pacman/Flatpak wrapper).
- [x] **Task 33.2**: `install_package()` with pre-install snapshot.
- [ ] **Task 33.3**: Software Center UI.

---

## ⚫ Phase 7: Polish & Production
**Objective:** Make it feel like a finished product.
**Status:** NOT STARTED

### Theming & Branding
- [ ] KOOMPI default theme (dark mode)
- [ ] Custom cursor (black with white border)
- [ ] Boot splash animation
- [ ] Sound theme

### DRM Backend & Real Hardware
- [ ] Switch from winit to DRM/KMS backend
- [ ] Multi-monitor support
- [ ] Hardware cursor

### Deferred Features
- [ ] Alt+Tab window switcher
- [ ] Virtual workspaces
- [ ] Task manager in panel
- [ ] .desktop file launcher

---

## 📋 Current Focus: Phase 6 - Core System Services

**Phase 5 Completed:**
- ✅ Settings app (koompi-settings) with Display, Appearance, Sound, Network, About pages
- ✅ File manager (koompi-files) with navigation, list/grid views, sidebar
- ✅ Notification daemon with toast notifications
- ✅ OSD for volume/brightness feedback
- ✅ Lock screen (Super+L)
- ✅ Power menu (Ctrl+Alt+Delete)
- ✅ Screenshot tool foundation
- ✅ Login screen (greetd + tuigreet)

**New Applications:**
- `koompi-files` - File manager with sidebar, list/grid views
- `koompi-settings` - System settings (Display, Appearance, Sound, Network, About)

**Shell Keybindings:**
- `Super`: Toggle launcher
- `Super+L`: Lock screen
- `Super+T`: Open terminal
- `Super+E`: Open file manager
- `Super+Q`: Close window
- `Tab`: Cycle windows
- `F11`: Toggle fullscreen
- `Ctrl+Alt+Del`: Power menu
- `PrtSc`: Screenshot

**Next Steps:**
1. Integrate daemon with shell
2. Add Snapshot manager UI to Settings
3. Create Software Center UI

---

## 📋 Legend
- [ ] Todo
- [x] Done
