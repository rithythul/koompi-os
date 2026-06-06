# KOOMPI OS

The Hyprland desktop for KOOMPI OS. Based on
[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse) + quickshell.

The desktop ships as part of the KOOMPI OS image: the dotfiles in `dots/` are
packaged into `/etc/skel` (see `sdata/dist-arch/koompi-hyprland-config/`), so a
freshly installed user inherits the whole desktop on first login.

For the full OS build architecture — signed `[koompi]` repo → archiso profile →
installer — see [`docs/os-build.md`](docs/os-build.md).
