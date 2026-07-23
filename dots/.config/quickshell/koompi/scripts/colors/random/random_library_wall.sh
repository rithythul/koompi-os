#!/usr/bin/env bash

# Random wallpaper from the KOOMPI library. This is the default random source:
# it ships with the OS, works offline, and needs no content filtering. The
# online sources (konachan, osu) stay available as explicit choices.

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBRARY_DIR="$XDG_CONFIG_HOME/koompi/wallpapers/library"
CONFIG_FILE="$XDG_CONFIG_HOME/koompi/config.json"

if [ ! -d "$LIBRARY_DIR" ]; then
    echo "random_library_wall: no wallpaper library at $LIBRARY_DIR" >&2
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
done < <(find "$LIBRARY_DIR" -type f -not -path '*/not-desktop-grade/*' -print0)

if [ "${#images[@]}" -eq 0 ]; then
    echo "random_library_wall: no images in $LIBRARY_DIR" >&2
    exit 1
fi

pick="${images[RANDOM % ${#images[@]}]}"

# Picking the wallpaper already on screen reads as a dead button, so try again.
current=$(jq -r '.background.wallpaperPath // empty' "$CONFIG_FILE" 2>/dev/null)
if [ "$pick" = "$current" ] && [ "${#images[@]}" -gt 1 ]; then
    pick="${images[RANDOM % ${#images[@]}]}"
fi

"$SCRIPT_DIR/../switchwall.sh" --image "$pick"
