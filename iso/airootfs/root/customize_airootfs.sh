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
useradd -m -G wheel,video,audio,input -s /usr/bin/zsh koompi 2>/dev/null || true
echo "koompi:koompi" | chpasswd

# Allow wheel group sudo access (with password)
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

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

# ═══════════════════════════════════════════════════════════════════════
# KOOMPI Immutability Services
# ═══════════════════════════════════════════════════════════════════════

# Enable daily snapshot timer (will activate after installation)
systemctl enable koompi-snapshot-daily.timer 2>/dev/null || true

# Enable initial snapshot service (runs on first boot after install)
systemctl enable koompi-initial-snapshot.service 2>/dev/null || true

# Enable boot watchdog services (per whitepaper Part 2 §1.4)
systemctl enable koompi-boot-watchdog.service 2>/dev/null || true
systemctl enable koompi-boot-success.service 2>/dev/null || true

# Enable KOOMPI daemon service (if available)
systemctl enable koompid.service 2>/dev/null || true

# Create classroom role groups (for polkit rules)
groupadd -r teachers 2>/dev/null || true
groupadd -r students 2>/dev/null || true

# Make KOOMPI CLI executable
chmod +x /usr/local/bin/koompi 2>/dev/null || true
chmod +x /usr/local/bin/koompi-install 2>/dev/null || true
chmod +x /usr/local/bin/koompi-snapshot 2>/dev/null || true
chmod +x /usr/local/bin/koompi-update 2>/dev/null || true
chmod +x /usr/local/bin/koompi-watchdog 2>/dev/null || true
chmod +x /usr/local/bin/koompi-classroom-roles 2>/dev/null || true

# Create snapshots directory structure (for live ISO testing)
mkdir -p /.snapshots/rootfs 2>/dev/null || true

# Create koompi state directory
mkdir -p /var/lib/koompi 2>/dev/null || true

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

# Create KOOMPI branding for fastfetch
mkdir -p /etc/fastfetch
cat > /etc/fastfetch/config.jsonc << 'FASTFETCH_EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "small"
    },
    "modules": [
        "title",
        "separator",
        "os",
        "kernel",
        "shell",
        "terminal",
        "cpu",
        "memory",
        "disk",
        "separator",
        {
            "type": "custom",
            "format": "KOOMPI OS Base - Run 'koompi help' to get started!"
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
                                   OS Base Edition

  Quick Start:
  • koompi help         - Show all commands
  • koompi install kde  - Install desktop environment
  • koompi desktop      - List desktop options
  • koompi snapshot     - Manage system snapshots

  Website: https://koompi.com
  
MOTD_EOF

# Add fastfetch to shell startup for live user
if [[ -f /home/koompi/.zshrc ]]; then
    echo '# Show system info on login' >> /home/koompi/.zshrc
    echo 'fastfetch' >> /home/koompi/.zshrc
fi

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
