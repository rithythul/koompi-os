# shellcheck shell=bash
# Sourced by sdata/install/deps.sh. Arch Linux and derivatives.
#
# Only the *dependency* metapackages are installed here. The packages that ship
# the desktop itself - koompi-hyprland-config, koompi-shell, koompi-session and
# the koompi-desktop-* editions - are deliberately left out: ./setup installs
# that content into $HOME, and having both would give you two copies of the
# shell fighting over the same paths. Building the full OS image is a separate
# path; see docs/os-build.md.

have pacman || die "no pacman; sdata/dist-arch is for Arch and its derivatives"

# arch_install_yay and arch_install_pkgbuild, shared with install-apps.sh.
# shellcheck source=sdata/lib/arch.sh
source "$REPO_ROOT/sdata/lib/arch.sh"

# Dependency metas only, in dependency order.
ARCH_DEP_PKGBUILDS=(
    koompi-basic
    koompi-audio
    koompi-backlight
    koompi-fonts-themes
    koompi-kde
    koompi-portal
    koompi-python
    koompi-screencapture
    koompi-toolkit
    koompi-widgets
    koompi-hyprland
    koompi-quickshell-git
    koompi-microtex-git
    koompi-bibata-modern-classic-bin
)

# Package names from the pre-KOOMPI era. Left installed they sit as orphans and,
# worse, the -git builds shadow the repo versions the metas now pull in.
arch_drop_deprecated() {
    local stale=(
        illogical-impulse-{microtex,pymyc-aur,oneui4-icons-git}
        illogical-impulse-{quickshell-git,audio,backlight,basic,bibata-modern-classic-bin}
        illogical-impulse-{fonts-themes,hyprland,kde,microtex-git,portal,python}
        illogical-impulse-{screencapture,toolkit,widgets}
        matugen-bin hyprland-qtutils
        {quickshell,hyprutils,hyprpicker,hyprlang,hypridle,hyprland-qt-support}-git
        {hyprland-qtutils,hyprlock,xdg-desktop-portal-hyprland,hyprcursor}-git
        {hyprwayland-scanner,hyprland}-git
    )
    local present=() pkg
    for pkg in "${stale[@]}"; do
        pacman -Qq "$pkg" >/dev/null 2>&1 && present+=("$pkg")
    done
    (( ${#present[@]} )) || return 0
    warn "removing ${#present[@]} superseded package(s): ${present[*]}"
    # -Rdd: they are replaced by the metas installed immediately after, so the
    # dependency check would refuse a removal that is in fact safe.
    run sudo pacman -Rdd --noconfirm "${present[@]}"
}

step "Arch: refreshing packages"
run sudo pacman -Syu --noconfirm

arch_drop_deprecated
arch_install_yay

for _koompi_pkg in "${ARCH_DEP_PKGBUILDS[@]}"; do
    step "Arch: $_koompi_pkg"
    arch_install_pkgbuild "$_koompi_pkg"
done
unset _koompi_pkg

# ~600 KiB itself, but on a machine without KDE it drags in ~600 MiB of Plasma.
# Only worth it for media-position reporting out of Firefox.
if ! pacman -Qq plasma-browser-integration >/dev/null 2>&1; then
    if confirm "Install plasma-browser-integration? (browser media position in the shell; pulls KDE libraries)"; then
        run sudo pacman -S --needed --noconfirm plasma-browser-integration
    fi
fi
