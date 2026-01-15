#!/usr/bin/env bash
# KOOMPI OS Base Edition - Customize airootfs script
# This runs during ISO build to configure the live environment
# Base edition: Minimal Arch + Btrfs immutability + AI-powered CLI

set -e -u

# ═══════════════════════════════════════════════════════════════════════
# Basic System Configuration
# ═══════════════════════════════════════════════════════════════════════

# Set locale
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Set hostname
echo "koompi-live" > /etc/hostname

# Create live user for ISO
# Username: koompi, Password: koompi
# Using pre-hashed password (SHA-512) for reliability in chroot
KOOMPI_PASS='$6$e4jiGQsT6ZnYWnNW$3pTFVdumY7VIR/nGQzuGkJ/icg7aM4et4tHfnD1GVGhsYgYROZIwsQ/uGG2SlCDhrnF5K8fuTHdr2WYhzIqp6.'
useradd -m -G wheel,video,audio,input -s /usr/bin/zsh -p "$KOOMPI_PASS" koompi 2>/dev/null || true

# Create greeter user for greetd (if not created by package)
useradd -r -s /usr/bin/nologin -M -d /var/lib/greeter greeter 2>/dev/null || true
usermod -a -G video greeter 2>/dev/null || true
mkdir -p /var/lib/greeter
chown greeter:greeter /var/lib/greeter
chmod 755 /var/lib/greeter

# Allow wheel group sudo access 
# Passwordless sudo for Live ISO environment
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Copy skeleton files to root too for consistent CLI experience
cp -rT /etc/skel /root/

# ═══════════════════════════════════════════════════════════════════════
# Shell Environment (zsh + oh-my-zsh)
# ═══════════════════════════════════════════════════════════════════════

# Copy skeleton files to live user
cp -rT /etc/skel /home/koompi/
chown -R koompi:koompi /home/koompi/

# Install oh-my-zsh for koompi user
export ZSH="/home/koompi/.oh-my-zsh"
if [[ ! -d "$ZSH" ]]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH" 2>/dev/null || true
fi

# Link system zsh plugins to oh-my-zsh
mkdir -p "$ZSH/custom/plugins"
ln -sf /usr/share/zsh/plugins/zsh-autosuggestions "$ZSH/custom/plugins/zsh-autosuggestions" 2>/dev/null || true
ln -sf /usr/share/zsh/plugins/zsh-syntax-highlighting "$ZSH/custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true

# Set correct ownership
chown -R koompi:koompi /home/koompi/

# Set zsh as default shell for new users
sed -i 's|SHELL=/bin/bash|SHELL=/usr/bin/zsh|' /etc/default/useradd 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════
# Core Services (Minimal Base)
# ═══════════════════════════════════════════════════════════════════════

systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable bluetooth.service 2>/dev/null || true

# Set multi-user target as default (CLI-only base)
systemctl set-default multi-user.target 2>/dev/null || true

# Disable services that shouldn't run on live ISO
systemctl disable systemd-firstboot.service 2>/dev/null || true

# Configure greetd (if enabled)
if systemctl is-enabled greetd.service &>/dev/null; then
    mkdir -p /etc/greetd
    cat > /etc/greetd/config.toml << 'GREETD_EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-user-session --cmd /usr/bin/zsh"
user = "greeter"

[initial_session]
command = "/usr/bin/zsh -l"
user = "koompi"
GREETD_EOF
    chown -R greeter:greeter /etc/greetd
    chmod 644 /etc/greetd/config.toml
fi

# Configure mkinitcpio for KOOMPI
cat > /etc/mkinitcpio.conf << 'MKINIT_EOF'
HOOKS=(base udev modconf kms memdisk archiso_shutdown archiso_loop_mnt archiso block filesystems fsck)
COMPRESSION="zstd"
MKINIT_EOF

# Enable autologin on tty1 for koompi user (Fallback/Live reliability)
systemctl disable greetd.service 2>/dev/null || true
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTOLOGIN_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin koompi %I $TERM
AUTOLOGIN_EOF

systemctl enable getty@tty1.service 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════
# KOOMPI Immutability Services
# ═══════════════════════════════════════════════════════════════════════

# Enable daily snapshot timer (will activate after installation)
systemctl enable koompi-snapshot-daily.timer 2>/dev/null || true

# Enable boot watchdog services (per whitepaper Part 2 §1.4)
systemctl enable koompi-boot-watchdog.service 2>/dev/null || true
systemctl enable koompi-boot-success.service 2>/dev/null || true

# Enable KOOMPI daemon service (if available)
systemctl enable koompid.service 2>/dev/null || true

# Enable automatic GRUB menu updates for Btrfs snapshots
systemctl enable grub-btrfsd.service 2>/dev/null || true

# Create classroom role groups (for polkit rules)
groupadd -r teachers 2>/dev/null || true
groupadd -r students 2>/dev/null || true

# Make KOOMPI CLI executables
chmod +x /usr/local/bin/koompi 2>/dev/null || true
chmod +x /usr/local/bin/koompi-install 2>/dev/null || true
chmod +x /usr/local/bin/koompi-snapshot 2>/dev/null || true
chmod +x /usr/local/bin/koompi-update 2>/dev/null || true
chmod +x /usr/local/bin/koompi-watchdog 2>/dev/null || true
chmod +x /usr/local/bin/koompi-desktop 2>/dev/null || true
chmod +x /usr/local/bin/koompi-security 2>/dev/null || true
chmod +x /usr/local/bin/koompi-classroom-roles 2>/dev/null || true

# Create snapshots directory structure (for live ISO testing)
mkdir -p /.snapshots/rootfs 2>/dev/null || true

# Create koompi state directory
mkdir -p /var/lib/koompi 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════
# Power Management & Performance
# ═══════════════════════════════════════════════════════════════════════

# Configure zram (compressed swap in RAM)
cat > /etc/systemd/zram-generator.conf << 'ZRAM_EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAM_EOF

# Enable power management and maintenance services
systemctl enable tlp.service 2>/dev/null || true
systemctl enable acpid.service 2>/dev/null || true
systemctl enable reflector.timer 2>/dev/null || true
systemctl enable fstrim.timer 2>/dev/null || true
systemctl enable haveged.service 2>/dev/null || true

# Set Plymouth default theme (ensure it looks professional)
if command -v plymouth-set-default-theme &>/dev/null; then
    plymouth-set-default-theme spinner 2>/dev/null || true
fi

# Pre-configure UFW (Firewall) defaults
if command -v ufw &>/dev/null; then
    ufw default deny incoming 2>/dev/null || true
    ufw default allow outgoing 2>/dev/null || true
fi

# Ensure mirrorlist is NEVER empty and has good fallbacks
mkdir -p /etc/pacman.d
cat > /etc/pacman.d/mirrorlist << 'MIRROR_EOF'
## KOOMPI OS Regional Mirrors (Southeast Asia + East Asia)

# Cambodia
Server = https://mirror.sabay.com.kh/archlinux/$repo/os/$arch

# Singapore
Server = https://mirror.0x.sg/archlinux/$repo/os/$arch
Server = https://download.nus.edu.sg/mirror/archlinux/$repo/os/$arch

# Hong Kong
Server = https://mirror-hk.koddos.net/archlinux/$repo/os/$arch

# Japan
Server = https://ftp.jaist.ac.jp/pub/Linux/ArchLinux/$repo/os/$arch
Server = https://mirrors.cat.net/archlinux/$repo/os/$arch

# Global Fallback
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRROR_EOF

# Initialize pacman keyring
echo "Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinux

# Try to run reflector and sync databases if online
if ping -c1 -W2 archlinux.org &>/dev/null; then
    echo "Network detected. Optimizing mirrors and syncing databases..."
    reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist.tmp && mv /etc/pacman.d/mirrorlist.tmp /etc/pacman.d/mirrorlist || rm -f /etc/pacman.d/mirrorlist.tmp
    pacman -Sy --noconfirm
fi

# ═══════════════════════════════════════════════════════════════════════
# Build paru (AUR helper) - NOT in official repos
# ═══════════════════════════════════════════════════════════════════════

if ! command -v paru &>/dev/null; then
    echo "Building paru from AUR..."
    cd /tmp
    git clone --depth=1 https://aur.archlinux.org/paru-bin.git 2>/dev/null || true
    if [[ -d paru-bin ]]; then
        chown -R koompi:koompi paru-bin
        cd paru-bin
        # Build as koompi user
        su koompi -c "makepkg --noconfirm" 2>/dev/null || true
        # Install as root manually to avoid sudo issues
        pacman -U --noconfirm paru-bin-*.pkg.tar.zst 2>/dev/null || true
        cd /
        rm -rf /tmp/paru-bin
    fi
fi

# ═══════════════════════════════════════════════════════════════════════
# KOOMPI CLI + AI Setup
# ═══════════════════════════════════════════════════════════════════════

# Install Python packages for KOOMPI CLI/AI
# Note: These are installed via PKGBUILD during package creation
# This section ensures paths are correct for local dev installs

# Ensure pip is available
python3 -m ensurepip --default-pip 2>/dev/null || true

# Set up Python path for KOOMPI packages (if installed locally)
mkdir -p /etc/profile.d
cat > /etc/profile.d/koompi-python.sh << 'PYTHONPATH_EOF'
# KOOMPI Python packages path
export PYTHONPATH="${PYTHONPATH:-}:/usr/lib/koompi/python"
PYTHONPATH_EOF

# ═══════════════════════════════════════════════════════════════════════
# KOOMPI Branding (Terminal-focused for base edition)
# ═══════════════════════════════════════════════════════════════════════

# Create /etc/os-release for KOOMPI OS identity
cat > /etc/os-release << 'OSRELEASE_EOF'
NAME="KOOMPI OS"
ID=koompi
ID_LIKE=arch
VERSION="1.0"
VERSION_ID="1.0"
PRETTY_NAME="KOOMPI OS Base Edition"
HOME_URL="https://koompi.com"
DOCUMENTATION_URL="https://docs.koompi.com"
SUPPORT_URL="https://github.com/koompi/koompi-os"
BUG_REPORT_URL="https://github.com/koompi/koompi-os/issues"
OSRELEASE_EOF

# Create /etc/issue (login prompt banner)
cat > /etc/issue << 'ISSUE_EOF'

  \e[1;34mKOOMPI OS\e[0m Base Edition
  Kernel: \r on \m

  Login: \e[1;32mkoompi\e[0m | Password: \e[1;32mkoompi\e[0m

ISSUE_EOF

# Create KOOMPI branding for fastfetch
mkdir -p /etc/fastfetch
cat > /etc/fastfetch/config.jsonc << 'FASTFETCH_EOF'
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
            "format": "┌────────────────────────────────┐"
        },
        {
            "type": "custom",
            "format": "│    Welcome to KOOMPI OS        │"
        },
        {
            "type": "custom",
            "format": "└────────────────────────────────┘"
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
FASTFETCH_EOF

# Create MOTD (Message of the Day)
cat > /etc/motd << 'MOTD_EOF'

  ██╗  ██╗ ██████╗  ██████╗ ███╗   ███╗██████╗ ██╗
  ██║ ██╔╝██╔═══██╗██╔═══██╗████╗ ████║██╔══██╗██║
  █████╔╝ ██║   ██║██║   ██║██╔████╔██║██████╔╝██║
  ██╔═██╗ ██║   ██║██║   ██║██║╚██╔╝██║██╔═══╝ ██║
  ██║  ██╗╚██████╔╝╚██████╔╝██║ ╚═╝ ██║██║     ██║
  ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝
                                            OS v1.0

  Quick Start:
  • koompi install <pkg> - Install packages (repos + AUR)
  • koompi upgrade       - Safe system upgrade with snapshot
  • koompi-desktop       - Install a desktop environment
  • koompi-security      - Enable security hardening
  • koompi-install       - Install KOOMPI OS to disk

  Website: https://koompi.com

MOTD_EOF

# Ensure koompi user has proper shell config
# (copied from /etc/skel during user creation)

# ═══════════════════════════════════════════════════════════════════════
# API Key Setup Helper
# ═══════════════════════════════════════════════════════════════════════

# Create helper script for API key setup
cat > /usr/local/bin/koompi-setup-ai << 'SETUP_AI_EOF'
#!/usr/bin/env bash
# KOOMPI AI Setup - Configure Gemini API key

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           KOOMPI AI Assistant Setup                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "To use the AI assistant, you need a Google Gemini API key."
echo ""
echo "Get your free API key at:"
echo "  → https://aistudio.google.com/app/apikey"
echo ""

read -p "Enter your Gemini API key: " api_key

if [[ -n "$api_key" ]]; then
    # Save to user environment
    echo "export GEMINI_API_KEY='$api_key'" >> ~/.bashrc
    echo "export GEMINI_API_KEY='$api_key'" >> ~/.zshrc
    
    # Export for current session
    export GEMINI_API_KEY="$api_key"
    
    echo ""
    echo "✓ API key saved! Testing connection..."
    echo ""
    
    # Test the API (if Python CLI is available)
    if command -v koompi &>/dev/null; then
        koompi ai "Hello, are you working?" 2>/dev/null || echo "AI test complete."
    fi
    
    echo ""
    echo "Setup complete! You can now use 'koompi' with AI features."
    echo "Try: koompi help me install firefox"
else
    echo "No API key provided. AI features will work in offline mode."
    echo "You can run this setup again anytime: koompi-setup-ai"
fi
SETUP_AI_EOF
chmod +x /usr/local/bin/koompi-setup-ai

# ═══════════════════════════════════════════════════════════════════════
# Final Setup
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  KOOMPI OS Base Edition - Customization Complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Features:"
echo "  • Btrfs immutability with automatic snapshots"
echo "  • AI-powered CLI assistant (koompi command)"
echo "  • Minimal base - install only what you need"
echo ""
echo "  To install a desktop environment:"
echo "    koompi desktop kde    # KDE Plasma"
echo "    koompi desktop gnome  # GNOME"
echo "    koompi desktop xfce   # XFCE (lightweight)"
echo ""
