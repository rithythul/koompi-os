# KOOMPI OS Development Tasks (Main Branch)

**Scope:** Base OS only (headless, CLI, daemon, AI)  
**Desktop/Apps:** See feature branches

---

## Branch Structure

| Branch          | Purpose                                       |
| --------------- | --------------------------------------------- |
| `main`          | Base OS: daemon, snapshots, packages, AI, CLI |
| `koompi-shell`  | Custom Rust compositor (Smithay + Iced)       |
| `koompi-kde`    | KDE Plasma integration                        |
| `koompi-apps`   | File manager, chat, utilities                 |
| `koompi-edu`    | Classroom mesh networking, teacher/student    |
| `koompi-office` | Office suite                                  |
| `koompi-docs`   | Whitepapers, architecture vision, roadmap     |

---

## 🟢 Phase 1: Bootable Foundation ✅

**Status:** COMPLETE

- [x] ISO build with archiso
- [x] Btrfs immutable layout
- [x] Boot with linux-lts
- [x] Base packages (no DE)

---

## 🟢 Phase 2: Core Daemon ✅

**Status:** COMPLETE

- [x] `koompi-daemon` with D-Bus interface
- [x] Snapshot manager integration
- [x] Package manager integration
- [x] Service configuration (`daemon.toml`)

---

## 🟡 Phase 3: Package Management

**Status:** IN PROGRESS

### Pacman Backend

- [x] Basic pacman wrapper
- [x] Package search
- [x] Package install/remove
- [ ] **Parse pacman output properly** (update count, etc.)
- [ ] **Pre-install snapshot integration**

### AUR Backend

- [ ] **AUR RPC search implementation**
- [ ] **yay/paru installation wrapper**
- [ ] **PKGBUILD safety checks**

### Flatpak Backend

- [x] Basic flatpak wrapper
- [ ] **Flathub remote configuration**

### Update System

- [ ] **`koompi update` command**
- [ ] **Auto pre-update snapshot**
- [ ] **GRUB rollback on failed boot (3 attempts)**

---

## 🟡 Phase 4: Snapshot & Immutability

**Status:** IN PROGRESS

- [x] Snapshot create/list/delete
- [x] Rollback to snapshot
- [x] Retention policy (max 10)
- [ ] **Integration test: create → modify → rollback → verify**
- [ ] **grub-btrfs integration for boot menu**
- [ ] **Automatic rollback on 3 failed boots**

---

## � Phase 5: AI Integration ✅

**Status:** COMPLETE

- [x] Gemini API integration
- [x] Offline knowledge base (FTS5)
- [x] ArchWiki content ingestion
- [x] Intent classification
- [x] Voice recognition (Whisper)
- [ ] **`koompi ai setup` for API key**
- [ ] **pytest test suite**

---

## 🟡 Phase 7: CLI Tool

**Status:** IN PROGRESS

### Core Commands

- [x] Basic CLI structure (click)
- [ ] **`koompi install <pkg>`** - Install with auto-snapshot
- [ ] **`koompi remove <pkg>`** - Remove package
- [ ] **`koompi update`** - System update with snapshot
- [ ] **`koompi search <query>`** - Search packages

### Snapshot Commands

- [ ] **`koompi snapshot create <name>`**
- [ ] **`koompi snapshot list`**
- [ ] **`koompi snapshot rollback <id>`**
- [ ] **`koompi snapshot delete <id>`**

### AI Commands

- [ ] **`koompi ai <question>`** - Ask AI assistant
- [ ] **`koompi ai setup`** - Configure API key
- [ ] **`koompi ai offline`** - Query offline only

---

## 🔴 Phase 8: Testing & Quality

**Status:** NOT STARTED

### Rust Tests

- [ ] `cargo test` for all crates
- [ ] D-Bus API integration tests
- [ ] Snapshot lifecycle tests

### Python Tests

- [ ] pytest for koompi-ai
- [ ] pytest for koompi-cli
- [ ] Mock Gemini API tests

### CI/CD

- [ ] GitHub Actions workflow
- [ ] Auto `cargo clippy` + `rustfmt`
- [ ] Auto `ruff` + `black` for Python

---

## 📋 Priority Order

1. **P0:** Complete AUR backend (`rust/packages/src/aur.rs`)
2. **P0:** Complete Pacman parsing (`rust/packages/src/pacman.rs`)
3. **P1:** CLI commands (`python/koompi-cli/`)
4. **P2:** Test suites
5. **P2:** grub-btrfs auto-rollback

---

## 📋 Legend

- [ ] Todo
- [x] Done
- **Bold** = Current priority
