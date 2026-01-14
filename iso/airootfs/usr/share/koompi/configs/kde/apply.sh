#!/usr/bin/env bash
# KOOMPI OS - KDE Plasma Configuration Script
# Applies KOOMPI branding to KDE Plasma

# Set KOOMPI wallpaper
if command -v plasma-apply-wallpaperimage &>/dev/null; then
    plasma-apply-wallpaperimage /usr/share/koompi/wallpapers/koompi-splash.png
fi

# Set KOOMPI color scheme (Breeze Dark with KOOMPI accent)
if command -v plasma-apply-colorscheme &>/dev/null; then
    plasma-apply-colorscheme BreezeDark
fi

# Configure Konsole to use JetBrains Mono
KONSOLE_PROFILE="$HOME/.local/share/konsole/KOOMPI.profile"
mkdir -p "$(dirname "$KONSOLE_PROFILE")"
cat > "$KONSOLE_PROFILE" << 'EOF'
[Appearance]
ColorScheme=Breeze
Font=JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0

[General]
Name=KOOMPI
Parent=FALLBACK/
EOF

# Set as default profile
mkdir -p "$HOME/.config"
cat >> "$HOME/.config/konsolerc" << 'EOF'
[Desktop Entry]
DefaultProfile=KOOMPI.profile
EOF

echo "KDE configuration applied!"
