# KOOMPI OS Development Tasks

**Goal:** Build a fully functional, immutable, AI-powered OS with a custom Rust shell.
**Pace:** 2-3 hours/day.
**Strategy:** "Lowest Hanging Fruit" first. Build the foundation, then the walls, then the roof.
**Reference:** See `papers/` for full architecture and roadmap details.

---

## 🟢 Phase 1: The "Hello World" ISO (Milestone M1 Start)
**Objective:** A bootable ISO that runs our custom Rust binary. (Completed)

### Day 1: The Rust Shell Skeleton (LHF 🍎)
- [x] **Task 1.1**: Fix `rust/koompi-shell/Cargo.toml` dependencies.
- [x] **Task 1.2**: Write a minimal `src/main.rs` that initializes a `tracing` subscriber.
- [x] **Task 1.3**: Verify it compiles with `cargo build --release`.

### Day 2: The ISO Builder Script (LHF 🍎)
- [x] **Task 2.1**: Update `scripts/build-iso.sh` to actually run `mkarchiso`.
- [x] **Task 2.2**: Configure `iso/profiledef.sh` and `iso/packages.x86_64`.
- [x] **Task 2.3**: Run the build script and generate an `.iso` file.

### Day 3: The First Boot
- [x] **Task 3.1**: Update `scripts/test-vm.sh` to launch QEMU.
- [x] **Task 3.2**: Boot the ISO in QEMU.
- [x] **Task 3.3**: Verify we can log in as root.

### Day 4: Auto-Start the Shell
- [x] **Task 4.1**: Create a systemd service `koompi-shell.service`.
- [x] **Task 4.2**: Configure the ISO to auto-login.
- [x] **Task 4.3**: Verify that booting the ISO automatically runs our Rust binary.

### 🛑 Phase 1 Review & Cleanup
- [x] **Task 1.R1**: **Code Review**: Check `koompi-shell` for unused dependencies.
- [x] **Task 1.R2**: **Cleanup**: Remove temporary build artifacts.
- [x] **Task 1.R3**: **Test**: Perform a clean build and fresh ISO build.

---

## 🟡 Phase 2: The Compositor Prototype (KOOMPI Shell)
**Objective:** A graphical shell that can display a window (Smithay + Iced).
**Reference:** Architecture Part 2.1 (Base System)

### Day 5: Smithay Backend
- [x] **Task 5.1**: Initialize Smithay's `winit` backend (for testing).
- [x] **Task 5.2**: Handle basic input events (keyboard/mouse) in the event loop.

### Day 6: Iced UI Integration
- [ ] **Task 6.1**: Create a basic Iced `Application` (e.g., a simple panel).
- [ ] **Task 6.2**: Render the Iced UI into a Smithay buffer.

### Day 7: Window Management
- [ ] **Task 7.1**: Implement `XdgShell` support in Smithay.
- [ ] **Task 7.2**: Allow launching a terminal (e.g., `alacritty`) as a window.

### 🛑 Phase 2 Review & Cleanup
- [ ] **Task 2.R1**: **Code Review**: Ensure Smithay event loop handles errors gracefully.
- [ ] **Task 2.R2**: **Cleanup**: Refactor monolithic `main.rs` into modules.
- [ ] **Task 2.R3**: **Test**: Verify window resizing and movement.

---

## 🟠 Phase 3: Core Engine (The "Brain")
**Objective:** System services, Immutability, and Python FFI.
**Reference:** Architecture Part 2.2 (KOOMPI Core Engine) & Features CORE-001/002

### Day 8: The Daemon & D-Bus
- [ ] **Task 8.1**: Implement `koompi-daemon` with D-Bus interface (`org.koompi.Daemon`).
- [ ] **Task 8.2**: Add `GetSystemStats()` method.

### Day 9: Snapshot Manager (CORE-001)
- [ ] **Task 9.1**: Implement `koompi-snapshots` (Btrfs wrapper).
- [ ] **Task 9.2**: Create `create_snapshot(name)` and `rollback(id)` functions.
- [ ] **Task 9.3**: Expose snapshot methods via D-Bus.

### Day 10: Package Manager (CORE-002)
- [ ] **Task 10.1**: Implement `koompi-packages` (Pacman/Flatpak wrapper).
- [ ] **Task 10.2**: Implement `install_package(name)` with pre-install snapshot.
- [ ] **Task 10.3**: **Windows Support**: Integrate `WinApps` (KVM/RDP) for legacy apps.

### Day 11: Python Bindings (FFI)
- [ ] **Task 11.1**: Configure `pyo3` in `rust/koompi-ffi`.
- [ ] **Task 11.2**: Expose `koompi_core` module to Python.
- [ ] **Task 11.3**: Verify Python can call Rust daemon methods.

### 🛑 Phase 3 Review & Cleanup
- [ ] **Task 3.R1**: **Code Review**: Check D-Bus security policies.
- [ ] **Task 3.R2**: **Cleanup**: Document the D-Bus API.
- [ ] **Task 3.R3**: **Test**: Python unit tests mocking D-Bus.

---

## 🔴 Phase 4: AI Intelligence (Milestone M2)
**Objective:** Chat with Gemini and Voice Control.
**Reference:** Features AI-001

### Day 12: Gemini Integration
- [ ] **Task 12.1**: Implement `koompi-ai/koompi_ai/llm.py` (Gemini API).
- [ ] **Task 12.2**: Create CLI tool `koompi-cli ask "How do I install git?"`.

### Day 13: The Chat UI
- [ ] **Task 13.1**: Create Qt (PySide6) window for `koompi-chat`.
- [ ] **Task 13.2**: Connect UI to `llm.py` backend.

### Day 14: Voice & Intent
- [ ] **Task 14.1**: Implement `intent.py` for command classification.
- [ ] **Task 14.2**: Integrate Whisper for STT (if feasible) or cloud STT.

### 🛑 Phase 4 Review & Cleanup
- [ ] **Task 4.R1**: **Code Review**: Audit API key handling.
- [ ] **Task 4.R2**: **Cleanup**: Add type hints and run `mypy`.
- [ ] **Task 4.R3**: **Test**: Verify graceful degradation (offline mode).

---

## 🟣 Phase 5: Classroom Mesh (Milestone M3)
**Objective:** Offline P2P networking.
**Reference:** Features CLASS-001

### Day 15: Discovery & Sync
- [ ] **Task 15.1**: Implement `koompi-mesh` (Avahi discovery).
- [ ] **Task 15.2**: Integrate Syncthing for file transfer.

### Day 16: Teacher Dashboard
- [ ] **Task 16.1**: Create Teacher Dashboard UI (Qt or Iced).
- [ ] **Task 16.2**: Implement "Broadcast File" feature.

---

## � Phase 6: The Office Suite (Milestone M4)
**Objective:** AI-powered productivity tools.
**Reference:** Features AI-002, AI-003, AI-004

### Day 17: KOOMPI Write (Document Creator)
- [ ] **Task 17.1**: Create `koompi-write` UI (Iced/Qt).
- [ ] **Task 17.2**: Integrate `llm.py` for "Generate Outline" feature.
- [ ] **Task 17.3**: Implement Voice Dictation (Whisper).

### Day 18: Present & Calculate
- [ ] **Task 18.1**: Prototype `koompi-present` (Markdown-to-Slides).
- [ ] **Task 18.2**: Prototype `koompi-calculate` (Natural Language Formulas).

---

## ⚫ Phase 7: Production Readiness (Milestone M5)
**Objective:** Turn the prototype into a shippable product.
**Reference:** Roadmap M1 & M5

### Day 19: The Installer
- [ ] **Task 19.1**: Create a graphical installer (or configure `calamares`).
- [ ] **Task 19.2**: Ensure installer handles Btrfs subvolumes correctly.

### Day 20: Localization (Khmer)
- [ ] **Task 20.1**: Package Khmer fonts (`khmer-text-fonts`).
- [ ] **Task 20.2**: Configure Input Method (IBus/Fcitx) for Khmer.
- [ ] **Task 20.3**: Verify UI rendering of Khmer text.

### Day 21: Multi-User & Security
- [ ] **Task 21.1**: Implement User Roles (Teacher/Student) in Daemon.
- [ ] **Task 21.2**: Configure "Kiosk Mode" for Student accounts.

---

## �📋 Legend
- [ ] Todo
- [x] Done
- 🍎 **LHF (Lowest Hanging Fruit)**: Easy wins.
