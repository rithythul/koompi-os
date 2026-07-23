#!/usr/bin/env bash

# Random wallpaper from the KOOMPI library. This is the default random source:
# it ships with the OS, works offline, and needs no content filtering. The
# online sources (konachan, osu) stay available as explicit choices.

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$XDG_CONFIG_HOME/koompi/config.json"

get_pictures_dir() {
    if command -v xdg-user-dir >/dev/null 2>&1; then
        xdg-user-dir PICTURES
        return
    fi
    echo "$HOME/Pictures"
}

# Two homes, on purpose. The shipped set is installed read-only by the
# koompi-branding package so it survives, upgrades, and costs one copy for the
# whole machine. The user's own folder is where anything they add lives, and
# where the online sources save what they download.
dirs=()
configured=$(jq -r '.background.workspaceWallpapers.libraryPath // empty' "$CONFIG_FILE" 2>/dev/null)
[ -n "$configured" ] && [ -d "$configured" ] && dirs+=("$configured")
[ -d "/usr/share/backgrounds/koompi" ] && dirs+=("/usr/share/backgrounds/koompi")
user_dir="$(get_pictures_dir)/Wallpapers"
[ -d "$user_dir" ] && dirs+=("$user_dir")

if [ "${#dirs[@]}" -eq 0 ]; then
    echo "random_library_wall: no wallpaper directory found" >&2
    exit 1
fi

# Curation notes and source manifests sit beside the images, and
# not-desktop-grade/ holds ones held back from the shipped set. Select on mime
# type rather than extension: several library images have no extension.
images=()
while IFS= read -r -d '' f; do
    case "$(file -b --mime-type "$f")" in
        image/*) images+=("$f") ;;
    esac
done < <(find "${dirs[@]}" -type f -not -path '*/not-desktop-grade/*' -print0)

if [ "${#images[@]}" -eq 0 ]; then
    echo "random_library_wall: no images in ${dirs[*]}" >&2
    exit 1
fi

pick="${images[RANDOM % ${#images[@]}]}"

# Picking the wallpaper already on screen reads as a dead button, so try again.
current=$(jq -r '.background.wallpaperPath // empty' "$CONFIG_FILE" 2>/dev/null)
if [ "$pick" = "$current" ] && [ "${#images[@]}" -gt 1 ]; then
    pick="${images[RANDOM % ${#images[@]}]}"
fi

"$SCRIPT_DIR/../apply_wall.sh" "$pick"
