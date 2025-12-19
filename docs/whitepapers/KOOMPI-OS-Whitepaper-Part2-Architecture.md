# KOOMPI OS Development Whitepaper
## Part 2: System Architecture

**Version:** 1.0  
**Date:** December 2024  
**Organization:** SmallWorld

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER INTERFACE LAYER                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │   KOOMPI Chat    │  │   KOOMPI CLI     │  │ KOOMPI Shell │  │
│  │  (Natural Lang)  │  │  (Power Users)   │  │(Rust/Smithay)│  │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘  │
├───────────┴─────────────────────┴────────────────────┴──────────┤
│                     AI & INTELLIGENCE LAYER                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │   Gemini API     │  │  Voice Engine    │  │  Intent      │  │
│  │   (Cloud AI)     │  │  (Whisper/Coqui) │  │  Router      │  │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘  │
├───────────┴─────────────────────┴────────────────────┴──────────┤
│                     KOOMPI CORE ENGINE                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ Package  │ │ Snapshot │ │ Update   │ │ Classroom│           │
│  │ Manager  │ │ Manager  │ │ System   │ │ Manager  │           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
├─────────────────────────────────────────────────────────────────┤
│                     SYSTEM SERVICES LAYER                       │
│  systemd │ NetworkManager │ PulseAudio │ Syncthing │ Avahi     │
├─────────────────────────────────────────────────────────────────┤
│                     IMMUTABLE BASE LAYER                        │
│  Arch Linux │ linux-lts kernel │ Btrfs │ Wayland │ systemd-boot│
├─────────────────────────────────────────────────────────────────┤
│                        HARDWARE                                 │
│     KOOMPI Devices │ Generic x86_64 │ ARM (future)             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Components

### 2.1 Base System (Arch Linux + Immutability)

#### Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Distribution | Arch Linux (rolling) | Always current, AUR ecosystem |
| Kernel | linux-lts | Stability for education |
| Init | systemd | Industry standard |
| Display | Wayland (Smithay) | Custom Rust Compositor |
| Desktop | KOOMPI Shell | Rust + Iced UI |
| Filesystem | Btrfs | Snapshots, compression |
| Bootloader | systemd-boot | Simple, fast |
| Languages | Rust, Python 3.12 | Performance + AI ecosystem |

#### Immutable Architecture

```
/                    # Read-only (Btrfs snapshot)
├── @root-current    # Active system snapshot
├── @root-2024-12-01 # Previous snapshot (rollback)
├── @root-2024-11-15 # Older snapshot
│
/home                # Read-write (Btrfs subvolume)
├── /home/student    # User data (preserved)
│
/var                 # Read-write (Btrfs subvolume)
├── /var/log         # System logs
├── /var/cache       # Package cache
│
/opt                 # Read-write (optional software)
├── /opt/aur         # AUR packages
├── /opt/appimages   # AppImages
```

#### Update Process

1. Current snapshot: `@root-current` (read-only, active)
2. Create new snapshot: `@root-new` from `@root-current`
3. Mount `@root-new` as read-write (temporarily)
4. Apply updates to `@root-new`
5. Set `@root-new` to read-only
6. Update bootloader to boot `@root-new`
7. Reboot → `@root-new` becomes `@root-current`
8. Old snapshot retained for rollback (keep last 10)

#### Automatic Rollback Process

1. Boot failure detected (3 consecutive failed boots)
2. GRUB automatically boots previous snapshot
3. System recovers without user intervention
4. Alert sent to admin/teacher

---

### 2.2 KOOMPI Core Engine

**Languages:** Rust (core daemon), Python 3.12 (AI/scripting)  
**Purpose:** Central intelligence and orchestration layer

#### Language Strategy

| Component | Language | Rationale |
|-----------|----------|-----------|
| Core daemon | Rust | Memory safety, performance, long-running stability |
| Snapshot manager | Rust | System-critical, needs reliability |
| Mesh networking | Rust | Performance, concurrent connections |
| AI integration | Python | ML ecosystem, rapid development |
| CLI tools | Python | Fast iteration, calls Rust via FFI |
| Chat application | Python + Qt | AI integration + UI |

#### Module Structure

```
koompi-core/                    # Rust workspace
├── Cargo.toml
├── koompi-daemon/              # Main system daemon
│   └── src/
│       ├── main.rs
│       ├── config.rs
│       └── api.rs              # D-Bus/gRPC API
├── koompi-snapshots/           # Btrfs operations
│   └── src/
│       ├── lib.rs
│       ├── btrfs.rs
│       ├── rollback.rs
│       └── retention.rs
├── koompi-packages/            # Package management
│   └── src/
│       ├── lib.rs
│       ├── pacman.rs
│       ├── aur.rs
│       └── flatpak.rs
├── koompi-mesh/                # Classroom networking
│   └── src/
│       ├── lib.rs
│       ├── discovery.rs
│       ├── sync.rs
│       └── teacher.rs
└── koompi-ffi/                 # Python bindings (PyO3)
    └── src/
        └── lib.rs

koompi-ai/                      # Python package
├── pyproject.toml
├── koompi_ai/
│   ├── __init__.py
│   ├── gemini.py               # Google Gemini API integration
│   ├── nlp.py                  # Natural language processing
│   ├── voice.py                # Voice recognition
│   └── intent.py               # Intent classification
└── tests/

koompi-cli/                     # Python CLI
├── pyproject.toml
├── koompi_cli/
│   ├── __init__.py
│   ├── main.py
│   └── commands/
└── tests/

koompi-chat/                    # Python + Qt application
├── pyproject.toml
├── koompi_chat/
│   ├── __init__.py
│   ├── app.py
│   ├── ui/
│   └── backend/
└── tests/
```

---

### 2.3 AI & Intelligence Layer

#### Local LLM Integration
Cloud AI Integration (Gemini)

We utilize Google's Gemini API for high-performance, low-latency intelligence. This removes the heavy RAM requirement of local LLMs, allowing the OS to run smoothly on 4GB RAM devices.

**Configuration:**
```yaml
ai_config:
  provider: "google"
  model: "gemini-1.5-flash"
  api_key_source: "user_input" # Or "school_license"
  
  fallback:
    strategy: "graceful_degradation"
    offline_message: "I need an internet connection to answer complex questions.
  voice:
    stt: "whisper-large-v3"
    tts: "coqui-tts"
    language: "km"  # Khmer
```

#### API Key Management

To balance ease of use with security, we employ a **Hybrid License Model**:

1.  **School License (Managed)**:
    - Keys are pre-provisioned by the school administrator via MDM.
    - Stored securely in the system keyring (`/etc/koompi/secrets/gemini_key`).
    - Students cannot see or extract the key.
    - Usage is monitored and rate-limited at the school level.

2.  **Personal License (BYOD)**:
    - Users can input their own Gemini API key via the Settings app.
    - Key is stored in the user's encrypted wallet (`KWallet`).
    - Ideal for developers or students using personal devices at home.

3.  **Security & Rate Limiting**:
    - Keys are never logged in plain text.
    - The OS handles `429 Too Many Requests` errors with exponential backoff.
    - If the quota is exceeded, the AI gracefully degrades to "Offline Mode" (basic commands only).

#### Intent Classification System

```yaml
intents:
  package_management:
    patterns:
      - "install {app}"
      - "remove {app}"
      - "update system"
    handler: "koompi_core.packages.manager"
  
  system_info:
    patterns:
      - "how much RAM"
      - "disk space"
      - "system status"
    handler: "koompi_core.system.info"
  
  file_operations:
    patterns:
      - "find files"
      - "compress {folder}"
      - "backup {location}"
    handler: "koompi_core.files.manager"
  
  classroom:
    patterns:
      - "share with class"
      - "collect assignments"
      - "who is online"
    handler: "koompi_core.classroom.mesh"
  
  help:
    patterns:
      - "how do I"
      - "teach me"
      - "explain"
    handler: "koompi_core.ai.tutor"
```

---

### 2.4 Classroom Mesh Network

#### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SCHOOL NETWORK                           │
│                                                             │
│  ┌─────────────┐                                           │
│  │   Teacher   │                                           │
│  │   Device    │ ←─── HUB (coordinator)                    │
│  └──────┬──────┘                                           │
│         │                                                   │
│    Broadcast                                               │
│         │                                                   │
│  ┌──────┴──────┬──────────────┬──────────────┐            │
│  │             │              │              │             │
│  ▼             ▼              ▼              ▼             │
│ ┌────┐       ┌────┐        ┌────┐        ┌────┐          │
│ │ S1 │ ←───→ │ S2 │ ←────→ │ S3 │ ←────→ │ S4 │          │
│ └────┘       └────┘        └────┘        └────┘          │
│                                                             │
│  Students peer-sync (Syncthing)                            │
│  Zero internet required                                     │
└─────────────────────────────────────────────────────────────┘
```

#### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Discovery | Avahi (mDNS) | Zero-config device finding |
| File Sync | Syncthing | P2P file synchronization |
| Messaging | MQTT (local) | Real-time communication |
| Dashboard | Qt/QML | Teacher control interface |

#### Sync Configuration

```yaml
classroom_mesh:
  discovery:
    protocol: "mdns"
    service_type: "_koompi._tcp"
    timeout: 30  # seconds
  
  sync:
    engine: "syncthing"
    conflict_resolution: "teacher_wins"
    bandwidth_limit: "10MB/s"  # Per device
    selective_sync: true
  
  roles:
    teacher:
      - broadcast_files
      - collect_assignments
      - manage_devices
      - block_websites
      - share_screen
    
    student:
      - receive_files
      - submit_assignments
      - peer_collaboration
      - request_help
  
  features:
    max_devices: 50
    offline_capable: true
    sync_on_discovery: true
    auto_reconnect: true
```

---

### 2.5 Package Management Strategy

#### Unified Interface

```rust
// koompi-packages/src/lib.rs

use std::collections::HashMap;

pub enum Backend {
    Pacman,
    Aur,
    Flatpak,
    AppImage,
}

pub struct PackageManager {
    backends: HashMap<Backend, Box<dyn PackageBackend>>,
    ai_checker: AiSafetyChecker,
}

impl PackageManager {
    pub async fn install(
        &self, 
        package: &str, 
        user_request: bool
    ) -> Result<InstallResult, PackageError> {
        // AI selects best backend
        let backend = self.ai_select_backend(package).await?;
        
        // Safety check for user requests
        if user_request {
            let risk = self.ai_checker.check(package).await?;
            if risk > 0.7 {
                return Ok(InstallResult::NeedsConfirmation { package, risk });
            }
        }
        
        // Create snapshot before install
        koompi_snapshots::create(&format!("pre-install-{}", package))?;
        
        // Install via selected backend
        self.backends[&backend].install(package).await
    }
}
```

#### Package Sources Priority

1. **Pacman (Official)** - System packages, guaranteed stable
2. **Flatpak** - GUI applications, sandboxed
3. **AUR** - Community packages, AI-reviewed
4. **AppImage** - Portable apps, user-specific

---

### 2.6 Smart Update System

#### Update Tiers

| Tier | Content | Testing | Rollout |
|------|---------|---------|---------|
| **Security** | CVE patches | Auto-test | Immediate |
| **Critical** | Bug fixes | 24h soak | 48h staged |
| **Regular** | Features | 7d beta | 14d staged |
| **Major** | Breaking changes | 30d beta | Manual |

#### AI Testing Pipeline

```yaml
update_pipeline:
  stages:
    1_pull:
      - Fetch package updates
      - Calculate dependencies
      - Check disk space
    
    2_test:
      - Boot in VM/container
      - Run automated tests
      - Check for regressions
      - AI analyze logs
    
    3_stage:
      - Deploy to beta channel
      - Monitor for 24-72 hours
      - Collect telemetry
    
    4_rollout:
      - 10% → 25% → 50% → 100%
      - Pause on error spike
      - Auto-rollback if needed
    
    5_verify:
      - Post-update health check
      - User feedback collection
      - Issue tracking
```

---

## 3. Security Architecture

### 3.1 Defense Layers

| Layer | Technology | Protection |
|-------|------------|------------|
| **Immutable Base** | Btrfs read-only | System tampering |
| **Sandboxing** | Flatpak, Firejail | App isolation |
| **Firewall** | nftables | Network attacks |
| **Encryption** | LUKS2 | Disk encryption |
| **Secure Boot** | UEFI | Boot tampering |
| **Updates** | Signed packages | Supply chain |

### 3.2 Privacy Design

```yaml
privacy_config:
  telemetry:
    enabled: false  # Default off
    opt_in_only: true
    anonymized: true
    local_processing: true
  
  data_collection:
    crash_reports: "opt-in"
    usage_analytics: "none"
    location: "never"
  
  network:
    dns_over_https: true
    tracker_blocking: true
    vpn_ready: true
```

---

## 4. Hardware Requirements

### 4.1 Minimum Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | x86_64, 2 cores | 4+ cores |
| RAM | 2GB | 4GB+ |
| Storage | 32GB | 64GB+ |
| Display | 1024x768 | 1920x1080 |

### 4.2 KOOMPI Device Optimization

```yaml
hardware_profiles:
  koompi_lite:
    ram: 4GB
    storage: 64GB
    animations: "reduced"
    
  koompi_standard:
    ram: 8GB
    storage: 128GB
    animations: "full"
    
  koompi_pro:
    ram: 16GB
    storage: 256GB
/
├── boot/                    # Bootloader, kernel
├── etc/                     # System configuration
├── usr/                     # System binaries, libraries
│   ├── bin/
│   ├── lib/
│   └── share/
├── opt/                     # Optional software (RW)
│   ├── aur/
│   ├── appimages/
│   └── koompi/              # KOOMPI applications
├── var/                     # Variable data (RW)
│   ├── log/
│   ├── cache/
│   └── lib/
├── home/                    # User directories (RW)
│   └── student/
│       ├── Documents/
│       ├── Projects/
│       ├── .config/
│       └── .local/
└── mnt/
    └── classroom/           # Mesh sync folder
```

---

*End of Part 2*

**Next:** [Part 3: Feature Specifications](./KOOMPI-OS-Whitepaper-Part3-Features.md)
