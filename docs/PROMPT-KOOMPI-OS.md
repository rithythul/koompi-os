# KOOMPI OS - AI Agent Build Prompt

## Mission

Build a minimal, bootable KOOMPI OS ISO based on Arch Linux with Btrfs immutability, automatic snapshots, and KOOMPI branding. The OS boots to CLI and allows users to install their choice of desktop environment.

> **Note:** The AI-powered CLI (`koompi-cli`) is developed in a separate repository and installed via AUR/PyPI. This prompt focuses **only on OS development**.

---

## Project Scope

**In Scope (This Repo):**
- ISO build system (archiso)
- Btrfs immutability & snapshots
- System scripts (`koompi-snapshot`, `koompi-watchdog`, `koompi-install`)
- Desktop environment installation (`koompi desktop`)
- KOOMPI branding (MOTD, fastfetch, wallpapers, configs)
- Boot watchdog & auto-recovery

**Out of Scope (Separate Repo):**
- AI CLI (`koompi-cli`, `koompi-ai`) - installed from AUR/PyPI

---

## Repository Structure

```
koompi-os/
├── iso/                              # archiso build system
│   ├── airootfs/                     # Live system overlay
│   │   ├── root/customize_airootfs.sh
│   │   ├── etc/
│   │   │   ├── motd                  # KOOMPI ASCII banner
│   │   │   ├── issue                 # Login prompt
│   │   │   ├── os-release            # KOOMPI OS identity
│   │   │   ├── skel/                 # Default user configs
│   │   │   └── systemd/system/       # KOOMPI services
│   │   └── usr/
│   │       ├── local/bin/            # KOOMPI system scripts
│   │       │   ├── koompi            # Unified package manager
│   │       │   ├── koompi-snapshot
│   │       │   ├── koompi-watchdog
│   │       │   ├── koompi-install
│   │       │   ├── koompi-desktop
│   │       │   └── koompi-update
│   │       └── share/koompi/         # Branding assets
│   │           ├── wallpapers/
│   │           └── configs/
│   ├── packages.x86_64               # Package list
│   ├── profiledef.sh                 # ISO profile
│   └── pacman.conf
├── rust/                             # System components
│   └── snapshots/                    # Btrfs snapshot library
├── configs/                          # Desktop configs
│   ├── hyprland/
│   ├── waybar/
│   ├── openbox/
│   └── tint2/
├── scripts/
│   ├── build-iso.sh
│   └── test-vm.sh
└── docs/
```

---

## Requirements

### 1. KOOMPI Branding

**MOTD (`/etc/motd`):**
```
  ██╗  ██╗ ██████╗  ██████╗ ███╗   ███╗██████╗ ██╗
  ██║ ██╔╝██╔═══██╗██╔═══██╗████╗ ████║██╔══██╗██║
  █████╔╝ ██║   ██║██║   ██║██╔████╔██║██████╔╝██║
  ██╔═██╗ ██║   ██║██║   ██║██║╚██╔╝██║██╔═══╝ ██║
  ██║  ██╗╚██████╔╝╚██████╔╝██║ ╚═╝ ██║██║     ██║
  ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝
                                   OS Base Edition

  Quick Start:
  • koompi install <pkg> - Install packages (repos + AUR)
  • koompi upgrade       - Safe system upgrade with snapshot
  • koompi-desktop       - Install a desktop environment
  • koompi-snapshot      - Manage system snapshots
  • koompi-cli           - AI-powered assistant (if installed)

  Website: https://koompi.com
```

**`/etc/os-release`:**
```
NAME="KOOMPI OS"
ID=koompi
ID_LIKE=arch
VERSION="1.0"
VERSION_ID="1.0"
PRETTY_NAME="KOOMPI OS Base Edition"
HOME_URL="https://koompi.com"
DOCUMENTATION_URL="https://docs.koompi.com"
SUPPORT_URL="https://github.com/koompi/koompi-os"
```

**`/etc/issue`:**
```

  KOOMPI OS Base Edition
  Kernel: \r on \m

  Login: koompi | Password: koompi

```

**Fastfetch config** (`/etc/fastfetch/config.jsonc`):
```jsonc
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "builtin",
        "source": "arch",
        "color": {
            "1": "blue",
            "2": "white"
        }
    },
    "display": {
        "separator": " → "
    },
    "modules": [
        {
            "type": "custom",
            "format": "┌──────────────────────────────────────────┐"
        },
        {
            "type": "custom",
            "format": "│  Welcome to KOOMPI OS                   │"
        },
        {
            "type": "custom",
            "format": "└──────────────────────────────────────────┘"
        },
        "break",
        "title",
        "separator",
        "os",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "terminal",
        "cpu",
        "gpu",
        "memory",
        "disk",
        "break",
        {
            "type": "custom",
            "format": "Run 'koompi --help' for commands"
        }
    ]
}
```

---

### 2. Package List (`packages.x86_64`)

```
# ═══════════════════════════════════════════════════════════════
# KOOMPI OS Base - Minimal Arch Linux
# ═══════════════════════════════════════════════════════════════

# Core System
base
linux-lts
linux-firmware
btrfs-progs

# CPU Microcode (both included, correct one loads automatically)
intel-ucode
amd-ucode

# GPU Drivers (covers most hardware)
mesa
vulkan-intel
vulkan-radeon
libva-mesa-driver
mesa-vdpau

# Boot
grub
efibootmgr
dosfstools
mtools
os-prober

# Immutability
snapper
snap-pac
grub-btrfs

# Fonts & Localization
noto-fonts
noto-fonts-khmer
noto-fonts-emoji
noto-fonts-cjk
ttf-jetbrains-mono-nerd
ttf-fira-code
gnu-free-fonts

# Input Method (Khmer Support)
fcitx5-im
fcitx5-m17n
fcitx5-qt
fcitx5-gtk

# Boot Splash
plymouth

# Essential Tools
sudo
networkmanager
git
curl
wget

# Shell
zsh
zsh-completions
zsh-autosuggestions
zsh-syntax-highlighting
bash-completion

# CLI Essentials
nano
vim
htop
btop
fastfetch
rsync
parted
reflector

# Filesystem Tools
ntfs-3g
exfatprogs
xdg-user-dirs

# Network
openssh
iwd
wireless_tools
wpa_supplicant

# Compression
unzip
zip
p7zip

# Man pages
man-db
man-pages

# Audio (base)
pipewire
pipewire-pulse
pipewire-alsa
wireplumber

# Bluetooth
bluez
bluez-utils

# Flatpak
flatpak

# AUR Support (paru built during customize_airootfs.sh)
base-devel
rust

# Power Management
tlp
acpid

# Swap (zram)
zram-generator

# TUI Tools (for installer/menus)
dialog

# Python (for koompi-cli from AUR)
python
python-pip
```

---

### 3. System Scripts

#### `koompi-snapshot` - Snapshot Management
```bash
#!/bin/bash
# Btrfs snapshot management

case "$1" in
    create)  # Create snapshot
    list)    # List snapshots
    delete)  # Delete snapshot
    rollback) # Rollback to snapshot
    info)    # Show snapshot info
    cleanup) # Apply retention policy
esac
```

#### `koompi-watchdog` - Boot Watchdog
```bash
#!/bin/bash
# Monitor boot failures, trigger auto-rollback after 3 failures

case "$1" in
    check)   # Check boot counter, rollback if > 3
    success) # Reset boot counter (called after successful boot)
    status)  # Show boot status
esac
```

#### `koompi-update` - Safe System Update
```bash
#!/bin/bash
# Update system with automatic snapshot

# 1. Create pre-update snapshot (tagged as "pre-update", protected from auto-cleanup)
# 2. Run koompi upgrade (uses paru internally)
# 3. Update GRUB menu
# 4. Apply tiered retention policy
```

#### `koompi` - Unified Package Manager
```bash
#!/bin/bash
# Unified wrapper for pacman + paru (AUR)
# Provides a single command for all package operations

# Network check for AUR operations
check_network() {
    if ! ping -c1 -W2 archlinux.org &>/dev/null; then
        echo "Error: No network connection"
        exit 1
    fi
}

case "$1" in
    install|-S)     # Install packages (auto-detects AUR)
                    check_network
                    # paru -S "${@:2}"
    remove|-R)      # Remove packages
                    # paru -Rns "${@:2}"
    upgrade|-U)     # Full system upgrade with snapshot
                    check_network
                    # koompi-update
    search|-Ss)     # Search packages (repos + AUR)
                    # paru -Ss "${@:2}"
    info|-Si)       # Show package info
                    # paru -Si "${@:2}"
    list|-Q)        # List installed packages
                    # paru -Q "${@:2}"
    clean|-Sc)      # Clean package cache
                    # paru -Sc
    *)              # Pass-through to paru for advanced usage
                    # paru "$@"
esac
```

**Usage Examples:**
```bash
koompi install firefox          # Install from repos
koompi install koompi-cli       # Install from AUR (auto-detected)
koompi remove firefox           # Remove package
koompi upgrade                  # Safe upgrade with snapshot
koompi search neovim            # Search repos + AUR
koompi -Syu                     # Pass-through to paru
```

#### `koompi-install` - System Installer (TUI)
```bash
#!/bin/bash
# TUI installer using dialog

# Steps:
# 1. Welcome screen
# 2. Locale selection (en_US.UTF-8, km_KH.UTF-8, etc.)
# 3. Keyboard layout selection
# 4. Timezone selection (with auto-detect option)
# 5. Disk selection
# 6. Encryption option (None / LUKS2 password)
# 7. Partitioning (auto/manual)
# 8. Btrfs subvolume creation (@, @home, @snapshots, @var_log)
# 9. Base system installation (pacstrap + detect CPU for microcode)
# 10. Bootloader installation (GRUB)
# 11. User creation (username, password, add to wheel)
# 12. Network configuration
# 13. Create "golden" recovery snapshot
# 14. Finish & reboot prompt
```

#### `koompi-desktop` - Desktop Installation
```bash
#!/bin/bash
# Interactive desktop environment installer

# Show menu:
# ┌─ KOOMPI Editions ─────────────────────────┐
# │  [1] KOOMPI Tiling   (Hyprland + configs) │
# │  [2] KOOMPI Terminal (Pure CLI)           │
# │  [3] KOOMPI Lite     (Openbox)            │
# └───────────────────────────────────────────┘
# ┌─ Community Desktops ──────────────────────┐
# │  [4] KDE  [5] GNOME  [6] XFCE  [7] More   │
# └───────────────────────────────────────────┘
```

---

### 4. Desktop Environment Options

#### **KOOMPI Editions** (Custom, Terminal-First)

**KOOMPI Tiling** - Modern Wayland with AI integration
```bash
PACKAGES=(
    hyprland xdg-desktop-portal-hyprland
    foot waybar fuzzel mako
    yazi thunar gvfs
    grim slurp wl-clipboard cliphist
    brightnessctl playerctl pavucontrol
    nwg-look qt5ct
    greetd greetd-tuigreet
)
```

**KOOMPI Terminal** - Pure CLI experience
```bash
PACKAGES=(
    zellij
    yazi ueberzugpp
    neovim lazygit
    btop dust duf fd ripgrep bat eza
)
```

**KOOMPI Lite** - Lightweight floating desktop
```bash
PACKAGES=(
    openbox obconf
    tint2 rofi
    alacritty
    pcmanfm gvfs
    nitrogen picom lxappearance
    lightdm lightdm-gtk-greeter
)
```

#### **Community Desktops**

```bash
declare -A DE_PACKAGES=(
    [kde]="plasma-desktop plasma-pa plasma-nm sddm konsole dolphin"
    [gnome]="gnome gnome-tweaks gdm"
    [xfce]="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"
    [cinnamon]="cinnamon nemo lightdm lightdm-gtk-greeter"
    [mate]="mate mate-extra lightdm lightdm-gtk-greeter"
    [i3]="i3-wm i3status i3lock dmenu alacritty lightdm"
    [sway]="sway swaylock waybar wofi foot greetd"
    [hyprland]="hyprland waybar wofi foot greetd"
)

declare -A DM_ENABLE=(
    [kde]="sddm" [gnome]="gdm" [xfce]="lightdm"
    [cinnamon]="lightdm" [mate]="lightdm" [i3]="lightdm"
    [sway]="greetd" [hyprland]="greetd"
)
```

---

### 5. KOOMPI Desktop Configs

Create pre-configured dotfiles for KOOMPI editions:

```
iso/airootfs/usr/share/koompi/configs/
├── hyprland/
│   └── hyprland.conf       # KOOMPI keybinds, colors, autostart
├── waybar/
│   ├── config              # Modules: workspaces, clock, tray, AI status
│   └── style.css           # KOOMPI theme colors
├── foot/
│   └── foot.ini            # KOOMPI color scheme
├── fuzzel/
│   └── fuzzel.ini          # KOOMPI theme
├── zellij/
│   └── config.kdl          # KOOMPI layout
├── neovim/
│   └── init.lua            # LazyVim-based config
├── openbox/
│   ├── rc.xml              # KOOMPI keybinds
│   └── autostart           # Startup apps
├── tint2/
│   └── tint2rc             # KOOMPI panel theme
└── rofi/
    └── config.rasi         # KOOMPI theme
```

**Apply script** (`/usr/local/bin/koompi-apply-config`):
```bash
#!/bin/bash
# Symlink KOOMPI configs to user home

KOOMPI_CONFIGS="/usr/share/koompi/configs"
USER_HOME="$HOME"

case "$1" in
    hyprland)
        mkdir -p "$USER_HOME/.config/hypr"
        cp "$KOOMPI_CONFIGS/hyprland/hyprland.conf" "$USER_HOME/.config/hypr/"
        # ... waybar, foot, fuzzel
        ;;
    openbox)
        mkdir -p "$USER_HOME/.config/openbox"
        cp "$KOOMPI_CONFIGS/openbox/"* "$USER_HOME/.config/openbox/"
        # ... tint2, rofi
        ;;
esac
```

---

### 6. Systemd Services

**`koompi-snapshot-daily.timer`:**
```ini
[Unit]
Description=Daily KOOMPI Snapshot

[Timer]
OnCalendar=*-*-* 02:00:00
OnBootSec=10min
RandomizedDelaySec=30min
Persistent=true

[Install]
WantedBy=timers.target
```

**`koompi-snapshot-daily.service`:**
```ini
[Unit]
Description=Create Daily KOOMPI Snapshot

[Service]
Type=oneshot
ExecStart=/usr/local/bin/koompi-snapshot create "daily-$(date +%%Y%%m%%d)" Scheduled
ExecStartPost=/usr/local/bin/koompi-snapshot cleanup 10
Nice=19
IOSchedulingClass=idle
```

**`koompi-boot-watchdog.service`:**
```ini
[Unit]
Description=KOOMPI Boot Watchdog
DefaultDependencies=no
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/koompi-watchdog check
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
```

**`koompi-boot-success.service`:**
```ini
[Unit]
Description=KOOMPI Boot Success Marker
After=multi-user.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 300
ExecStart=/usr/local/bin/koompi-watchdog success

[Install]
WantedBy=multi-user.target
```

---

### 7. Snapper Configuration

Pre-configure snapper so snapshots work immediately after installation:

**`/etc/snapper/configs/root`:**
```ini
# KOOMPI OS Snapper Configuration
SUBVOLUME="/"
FSCONFIG="btrfs"

# Tiered Retention Policy
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"

# Keep 5 daily, 2 weekly, 1 monthly
TIMELINE_LIMIT_HOURLY="0"
TIMELINE_LIMIT_DAILY="5"
TIMELINE_LIMIT_WEEKLY="2"
TIMELINE_LIMIT_MONTHLY="1"
TIMELINE_LIMIT_YEARLY="0"

# Number comparison-based cleanup
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="5"

# Empty pre/post cleanup
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
```

**Retention Policy Rationale:**
- **5 daily** - Enough to recover from recent mistakes
- **2 weekly** - Covers longer-term issues discovered late
- **1 monthly** - Baseline for major rollbacks
- **Pre-update snapshots** - Tagged as "important", protected by `NUMBER_LIMIT_IMPORTANT`

> **Note:** `snap-pac` (added to packages) automatically creates pre/post snapshots for every pacman transaction.

---

### 8. Mkinitcpio Configuration (`/etc/mkinitcpio.conf`)

Ensure Btrfs and Plymouth support in initramfs:

```bash
MODULES=(btrfs)
BINARIES=()
FILES=()
# Key hooks: systemd (for faster boot), sd-plymouth (splash), sd-vconsole (fonts)
HOOKS=(base systemd sd-plymouth autodetect modconf kms keyboard sd-vconsole block filesystems fsck)
```

---

### 9. customize_airootfs.sh

```bash
#!/usr/bin/env bash
set -e -u

# ═══════════════════════════════════════════════════════════════
# KOOMPI OS Base Edition - Customization Script
# ═══════════════════════════════════════════════════════════════

# Locale
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

# Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Hostname
echo "koompi-live" > /etc/hostname

# Create live user
useradd -m -G wheel,video,audio,input -s /usr/bin/zsh koompi 2>/dev/null || true
echo "koompi:koompi" | chpasswd

# Sudo access
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Enable services
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
systemctl enable koompi-snapshot-daily.timer
systemctl enable koompi-boot-watchdog.service
systemctl enable koompi-boot-success.service
systemctl set-default multi-user.target

# Make scripts executable
chmod +x /usr/local/bin/koompi-*

# Create directories
mkdir -p /.snapshots
mkdir -p /var/lib/koompi

# Configure zram (compressed swap in RAM)
cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

# Enable services
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable tlp.service
systemctl enable acpid.service

# Setup XDG User Directories
xdg-user-dirs-update --force

# Build and install paru (AUR helper) - NOT in official repos
cd /tmp
git clone --depth=1 https://aur.archlinux.org/paru-bin.git
cd paru-bin
su koompi -c "makepkg -si --noconfirm"
cd / && rm -rf /tmp/paru-bin

# Oh-my-zsh for live user
export ZSH="/home/koompi/.oh-my-zsh"
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH" 2>/dev/null || true
chown -R koompi:koompi /home/koompi/

# Add fastfetch to login
echo 'fastfetch' >> /home/koompi/.zshrc

# Copy fastfetch config
mkdir -p /etc/fastfetch
cp /usr/share/koompi/configs/fastfetch/config.jsonc /etc/fastfetch/

# Configure Plymouth (Boot Splash)
plymouth-set-default-theme -R details # Change to 'koompi' theme later
# regenerate initramfs
mkinitcpio -P

echo "KOOMPI OS Base Edition - Customization Complete!"
```

---

## Build Tasks

### Phase 1: Core System Scripts
- [ ] Implement `koompi-snapshot` (create, list, delete, rollback, cleanup)
- [ ] Implement `koompi-watchdog` (check, success, status)
- [ ] Implement `koompi-update` (snapshot + pacman + grub)
- [ ] Create systemd service files
- [ ] Configure snapper with tiered retention policy
- [ ] **Test rollback early** - Boot watchdog is critical, validate 3-failure auto-recovery
- [ ] Test in VM

### Phase 2: Desktop Installation
- [ ] Implement `koompi-desktop` with TUI menu (dialog)
- [ ] Add KOOMPI editions: tiling, terminal, lite
- [ ] Add community desktops: kde, gnome, xfce, etc.
- [ ] Create KOOMPI config files (hyprland, waybar, etc.)
- [ ] Test desktop installation in VM

### Phase 3: System Installer
- [ ] Implement `koompi-install` TUI
- [ ] Disk partitioning (auto/manual)
- [ ] Btrfs subvolume creation
- [ ] Base system installation (pacstrap)
- [ ] Bootloader setup (GRUB)
- [ ] User creation
- [ ] Test full installation in VM

### Phase 4: Branding & Polish
- [ ] Create MOTD, issue, os-release
- [ ] Configure fastfetch
- [ ] Add KOOMPI wallpapers
- [ ] Configure Plymouth boot splash
- [ ] Configure Mkinitcpio (hooks & modules)
- [ ] Test complete ISO

### Phase 5: Testing & Release
- [ ] Build final ISO
- [ ] Test UEFI + BIOS boot
- [ ] Test snapshot system
- [ ] Test desktop installation
- [ ] Test full system install
- [ ] Create documentation

---

## Success Criteria

1. **ISO boots** to CLI with KOOMPI branding
2. **Snapshots work**: create, list, rollback
3. **Boot watchdog** recovers from failed boots
4. **`koompi-desktop`** installs KOOMPI and community DEs
5. **`koompi-install`** successfully installs to disk with encryption option
6. **ISO size** under 1.2GB (increased due to GPU drivers + microcode)
7. **Works on** UEFI and BIOS systems
8. **paru works** out of the box for AUR packages
9. **zram active** providing swap without disk I/O
10. **Power management** active on laptops (TLP)
11. **Khmer text** renders correctly (fonts installed)
12. **Boot splash** (plymouth) hides scrolling text

---

## Build & Test Commands

```bash
# Build ISO
cd /home/rithy/projects/koompi-os
sudo ./scripts/build-iso.sh

# Test in QEMU
qemu-system-x86_64 \
  -m 2G \
  -enable-kvm \
  -boot d \
  -cdrom out/koompi-os-base-*.iso \
  -drive file=test-disk.qcow2,format=qcow2

# Create test disk
qemu-img create -f qcow2 test-disk.qcow2 32G
```

---

## Notes for Agent

1. **Focus on OS only** - AI CLI is separate repo
2. **Use bash for system scripts** - No Python dependency for core OS
3. **Test frequently** - Build and test in QEMU
4. **Keep it minimal** - Base edition, users add what they need
5. **Btrfs is key** - Immutability and snapshots are core features
6. **Test rollback first** - Boot watchdog + snapshot rollback are the most critical features
7. **paru must be built** - It's in AUR, not official repos
8. **Include both microcodes** - Kernel auto-loads correct one
9. **Test LUKS install path** - Encryption adds complexity to bootloader

---

## Known Limitations & Future Work

### Secure Boot
Currently **not supported**. Users must disable Secure Boot in BIOS.

**Future:** Implement `shim` + `mokutil` for Secure Boot support.

### NVIDIA GPUs
Only open-source `nouveau` driver via mesa. For proprietary drivers:
```bash
koompi install nvidia nvidia-utils  # User installs manually
```

**Future:** Add NVIDIA detection to `koompi-desktop` with driver prompt.

### Recovery Snapshot
The installer creates a "golden" snapshot after fresh install. This snapshot:
- Is tagged as `important` (protected from auto-cleanup)
- Named `factory-YYYYMMDD`
- Can be restored via `koompi-snapshot rollback factory-*`

### First-Boot Experience
**Future enhancement:** On first graphical login, show a welcome dialog:
- Quick tour of KOOMPI features
- Prompt to install `koompi-cli` for AI assistant
- Link to documentation

---

## Future Enhancement: True Immutability (Optional)

The current design uses **pragmatic immutability** — users can still run `pacman -S` normally but have a snapshot safety net. For stricter immutability in the future, consider:

### Option A: Read-only `/usr` with Overlays
```bash
# Mount root read-only, use overlays for mutable areas
/ (read-only)
├── /etc → overlay (rw)
├── /var → separate subvolume (rw)
└── /usr → read-only
```

### Option B: OSTree/Composefs
Similar to Fedora Silverblue — atomic updates, layered packages.

### Option C: NixOS-style
Declarative configuration, reproducible builds.

> **Recommendation:** Stick with current Btrfs snapshot approach. It provides 90% of immutability benefits without the steep learning curve. Upgrade only if user feedback demands it.

---

## Comparison: KOOMPI OS vs Full Immutable Distros

| Feature | KOOMPI OS (This) | Fedora Silverblue | NixOS |
|---------|-----------------|-------------------|-------|
| Base | Arch Linux | Fedora | Nix |
| Package Manager | pacman + AUR | rpm-ostree + Flatpak | nix |
| Rollback | Btrfs snapshots | OSTree commits | Generations |
| Learning Curve | Low | Medium | High |
| Flexibility | High | Medium | Very High |
| Read-only Root | No (snapshots) | Yes | Yes |
