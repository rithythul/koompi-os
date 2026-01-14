#!/usr/bin/env bash
# KOOMPI OS - Deepin Configuration Script
# Applies KOOMPI branding to Deepin Desktop

# Deepin uses dconf/gsettings-like API through dde-api

# Set KOOMPI wallpaper
WALLPAPER="/usr/share/koompi/wallpapers/koompi-splash.png"

# Deepin stores wallpaper config in ~/.config/deepin/
mkdir -p "$HOME/.config/deepin/dde-appearance"
cat > "$HOME/.config/deepin/dde-appearance/theme.json" << EOF
{
    "wallpaper": "$WALLPAPER",
    "StandardFont": "Noto Sans",
    "MonospaceFont": "JetBrainsMono Nerd Font"
}
EOF

# Set dark mode
if command -v dbus-send &>/dev/null; then
    dbus-send --session --type=method_call \
        --dest=com.deepin.daemon.Appearance \
        /com/deepin/daemon/Appearance \
        com.deepin.daemon.Appearance.Set \
        string:"gtk" string:"deepin-dark" 2>/dev/null || true
fi

# Configure Deepin Terminal
DEEPIN_TERM_CONFIG="$HOME/.config/deepin/deepin-terminal/config.conf"
mkdir -p "$(dirname "$DEEPIN_TERM_CONFIG")"
cat > "$DEEPIN_TERM_CONFIG" << 'EOF'
[basic]
font=JetBrainsMono Nerd Font
font_size=11
opacity=0.9
theme=deepin

[advanced]
cursor_shape=beam
EOF

# Set dock to auto-hide
mkdir -p "$HOME/.config/deepin/dde-dock"
cat > "$HOME/.config/deepin/dde-dock/config.json" << 'EOF'
{
    "HideMode": "smart-hide",
    "DisplayMode": "efficient",
    "Position": "bottom"
}
EOF

echo "Deepin configuration applied!"
