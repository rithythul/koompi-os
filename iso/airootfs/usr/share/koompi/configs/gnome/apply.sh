#!/usr/bin/env bash
# KOOMPI OS - GNOME Configuration Script
# Applies KOOMPI branding to GNOME

# Set KOOMPI wallpaper
gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/koompi/wallpapers/koompi-splash.png"
gsettings set org.gnome.desktop.background picture-uri-dark "file:///usr/share/koompi/wallpapers/koompi-splash.png"
gsettings set org.gnome.desktop.background picture-options "zoom"

# Set dark theme
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"

# Set font
gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 11"

# GNOME Terminal profile
PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
if [[ -n "$PROFILE_ID" ]]; then
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/font "'JetBrainsMono Nerd Font 11'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/use-system-font false
fi

# Enable some useful extensions if available
if command -v gnome-extensions &>/dev/null; then
    gnome-extensions enable dash-to-dock@micxgx.gmail.com 2>/dev/null || true
fi

# Set favorite apps in dock
gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'firefox.desktop']"

echo "GNOME configuration applied!"
