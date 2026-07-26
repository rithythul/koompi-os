# shellcheck shell=bash
# Shared Arch helpers. Sourced by both sdata/dist-arch/install-deps.sh and
# sdata/dist-arch/install-apps.sh, which is the whole reason this file exists:
# the recipes have top-level statements and run their work on being sourced, so
# one cannot source the other just to borrow a function.
#
# Nothing here has a side effect at source time.

arch_install_yay() {
    have yay && return 0
    info "yay not found; building it (needed for the AUR dependencies)"
    local build
    build="$(mktemp -d)"
    run sudo pacman -S --needed --noconfirm base-devel git
    run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build"
    ( cd "$build" && run makepkg -si --noconfirm )
    rm -rf "$build"
}

# yay -Bi is unreliable (end-4/dots-hyprland#581), so the PKGBUILD is sourced for
# its depends[] and those go in first, then the meta itself is built.
arch_install_pkgbuild() {
    local dir="$REPO_ROOT/sdata/dist-arch/$1"
    [[ -d "$dir" ]] || { err "no such PKGBUILD dir: $dir"; return 1; }

    local depends=()
    # shellcheck source=/dev/null
    source "$dir/PKGBUILD"

    if (( ${#depends[@]} )); then
        run yay -S --sudoloop --needed --noconfirm --asdeps "${depends[@]}"
    fi
    # -A ignore the arch field, -f rebuild, -s pull build deps, -i install.
    ( cd "$dir" && run makepkg -Afsi --noconfirm --needed )
}
