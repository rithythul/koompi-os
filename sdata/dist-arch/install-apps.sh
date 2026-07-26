# shellcheck shell=bash
# Sourced by sdata/install/apps.sh. Arch Linux and derivatives.
#
# One metapackage. Everything in it is either in the official repositories or
# in the AUR, and arch_install_pkgbuild already knows how to get both, so this
# recipe is little more than a call into the dependency step's machinery.

have pacman || die "no pacman; sdata/dist-arch is for Arch and its derivatives"

# arch_install_yay and arch_install_pkgbuild, shared with install-deps.sh.
# Sourcing install-deps.sh to borrow them is not an option: it does its work at
# the top level, so it would re-run a full system upgrade on the way past.
# shellcheck source=sdata/lib/arch.sh
source "$REPO_ROOT/sdata/lib/arch.sh"

# --only-apps skips the dependency step, and every browser here is an AUR build.
arch_install_yay

step "Arch: koompi-apps"
arch_install_pkgbuild koompi-apps

# mpvpaper is the only piece of shipped configuration with no packaged home on
# any distro: switchwall.sh uses it to run a video file as the wallpaper. Every
# other wallpaper type works without it, so it is asked for rather than assumed.
if ! pacman -Qq mpvpaper >/dev/null 2>&1; then
    if confirm "Install mpvpaper? (lets you set a video as the wallpaper; AUR build)"; then
        run yay -S --sudoloop --needed --noconfirm mpvpaper
    fi
fi
