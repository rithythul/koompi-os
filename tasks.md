# KOOMPI OS Development Tasks

**Goal:** Build a fully functional, immutable, AI-powered OS with a custom Rust shell.
**Pace:** 2-3 hours/day.
**Strategy:** "Lowest Hanging Fruit" first. Build the foundation, then the walls, then the roof.

---

## 🟢 Phase 1: The "Hello World" ISO (Week 1)
**Objective:** A bootable ISO that runs our custom Rust binary (even if it just prints "Hello").

### Day 1: The Rust Shell Skeleton (LHF 🍎)
- [ ] **Task 1.1**: Fix `rust/koompi-shell/Cargo.toml` dependencies (ensure `smithay`, `iced`, `tokio` versions are compatible).
- [ ] **Task 1.2**: Write a minimal `src/main.rs` that initializes a `tracing` subscriber and enters a loop.
- [ ] **Task 1.3**: Verify it compiles with `cargo build --release`.

### Day 2: The ISO Builder Script (LHF 🍎)
- [ ] **Task 2.1**: Update `scripts/build-iso.sh` to actually run `mkarchiso`.
- [ ] **Task 2.2**: Configure `iso/profiledef.sh` and `iso/packages.x86_64` with minimal packages (`base`, `linux`, `rust`, `git`).
- [ ] **Task 2.3**: Run the build script and generate an `.iso` file.

### Day 3: The First Boot
- [ ] **Task 3.1**: Update `scripts/test-vm.sh` to launch QEMU with the generated ISO.
- [ ] **Task 3.2**: Boot the ISO in QEMU.
- [ ] **Task 3.3**: Verify we can log in as root.

### Day 4: Auto-Start the Shell
- [ ] **Task 4.1**: Create a systemd service `koompi-shell.service` in `iso/airootfs/etc/systemd/system/`.
- [ ] **Task 4.2**: Configure the ISO to auto-login to a user session.
- [ ] **Task 4.3**: Verify that booting the ISO automatically runs our Rust binary.

### 🛑 Phase 1 Review & Cleanup
- [ ] **Task 1.R1**: **Code Review**: Check `koompi-shell` for unused dependencies and `unwrap()` calls.
- [ ] **Task 1.R2**: **Cleanup**: Remove temporary build artifacts and unused scripts.
- [ ] **Task 1.R3**: **Test**: Perform a clean build (`cargo clean && cargo build`) and a fresh ISO build to ensure reproducibility.

---

## 🟡 Phase 2: The Compositor Prototype (Week 2-3)
**Objective:** A graphical shell that can display a window.

### Day 5: Smithay Backend
- [ ] **Task 5.1**: Initialize Smithay's `winit` backend (for testing inside an existing X11/Wayland session).
- [ ] **Task 5.2**: Handle basic input events (keyboard/mouse) in the event loop.

### Day 6: Iced UI Integration
- [ ] **Task 6.1**: Create a basic Iced `Application` (e.g., a simple panel with a clock).
- [ ] **Task 6.2**: Render the Iced UI into a Smithay buffer.

### Day 7: Window Management
- [ ] **Task 7.1**: Implement `XdgShell` support in Smithay.
- [ ] **Task 7.2**: Allow launching a terminal (e.g., `alacritty`) and having it appear as a window.

### 🛑 Phase 2 Review & Cleanup
- [ ] **Task 2.R1**: **Code Review**: Ensure Smithay event loop handles errors gracefully (no panics on window close).
- [ ] **Task 2.R2**: **Cleanup**: Refactor monolithic `main.rs` into modules (`backend.rs`, `ui.rs`, `input.rs`).
- [ ] **Task 2.R3**: **Test**: Run `cargo clippy` and fix all warnings. Verify window resizing and movement works without glitches.

---

## 🟠 Phase 3: Core Services (Week 4)
**Objective:** Python talking to Rust.

### Day 8: The Daemon
- [ ] **Task 8.1**: Implement `koompi-daemon` with a basic D-Bus interface (`org.koompi.Daemon`).
- [ ] **Task 8.2**: Add a method `GetSystemStats()` that returns RAM usage.

### 🛑 Phase 3 Review & Cleanup
- [ ] **Task 3.R1**: **Code Review**: Check D-Bus security policies (can non-root users call methods?).
- [ ] **Task 3.R2**: **Cleanup**: Document the D-Bus API in `docs/api.md`.
- [ ] **Task 3.R3**: **Test**: Write a Python unit test that mocks the D-Bus connection and verifies the FFI return types.

### Day 9: Python Bindings (FFI)
- [ ] **Task 9.1**: Configure `pyo3` in `rust/koompi-ffi`.
- [ ] **Task 9.2**: Expose a function `koompi_core.get_ram_usage()` that calls the Rust daemon.
- [ ] **Task 9.3**: Verify it works in a Python script.

---

## 🔴 Phase 4: AI Intelligence (Week 5)
### 🛑 Phase 4 Review & Cleanup
- [ ] **Task 4.R1**: **Code Review**: Audit API key handling (ensure keys are never logged).
- [ ] **Task 4.R2**: **Cleanup**: Add type hints to all Python code and run `mypy`.
- [ ] **Task 4.R3**: **Test**: Verify graceful degradation when internet is disconnected (app should not crash).

**Objective:** Chat with Gemini.

### Day 10: Gemini Integration
- [ ] **Task 10.1**: Implement `koompi-ai/koompi_ai/llm.py` to call Google Gemini API.
- [ ] **Task 10.2**: Create a CLI tool `koompi-cli ask "How do I install git?"`.

### Day 11: The Chat UI
- [ ] **Task 11.1**: Create a simple Qt (PySide6) window for `koompi-chat`.
### 🛑 Phase 5 Review & Cleanup
- [ ] **Task 5.R1**: **Code Review**: Check UI performance (frame rate) on low-end hardware (or VM with low RAM).
- [ ] **Task 5.R2**: **Cleanup**: Standardize icon naming and resource loading.
- [ ] **Task 5.R3**: **Test**: Full "User Acceptance Test" - Boot ISO, log in, launch app, chat with AI, shutdown.

- [ ] **Task 11.2**: Connect the UI to the `llm.py` backend.

---

## 🟣 Phase 5: The "Hybrid" Polish (Week 6+)
**Objective:** Make it look like KOOMPI OS.

### Day 12: The Panel
- [ ] **Task 12.1**: Style the Iced panel to look like Windows 11 (bottom bar, centered icons).
- [ ] **Task 12.2**: Add system tray indicators (battery, wifi).

### Day 13: The App Drawer
- [ ] **Task 13.1**: Implement the full-screen "Squircle" icon grid in Iced.
- [ ] **Task 13.2**: Make the "Start Button" toggle the drawer.

---

## 📋 Legend
- [ ] Todo
- [x] Done
- 🍎 **LHF (Lowest Hanging Fruit)**: Easy wins to start with.
