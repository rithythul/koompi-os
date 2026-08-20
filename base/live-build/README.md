Debian `live-build` configuration for the ISO (hybrid UEFI, KDE Plasma
live session → `koompi-install`, per docs/ARCHITECTURE.md §6).

`auto/config` pins the `lb config` invocation (trixie, amd64, iso-hybrid,
grub-efi). `config/package-lists/desktop.list.chroot` is the live
session's own desktop stack — separate from `base/packages.list`, which
the installer feeds to `mmdebstrap` for the *target* root, not the live
squashfs.

`config/includes.chroot/usr/share/koompi-os/{editions,base,repo}` and
`.../usr/bin/{vita,koompi-install}` don't exist here in git — they're
staged by `scripts/build_iso.sh` into a `build/live-build/` working copy
right before `lb build` runs, so this directory never duplicates content
that already lives elsewhere in the repo.

Autologin is enabled on `tty1` and `ttyS0` — standard live-CD posture
(anyone with console access to a live session already has root), and
`ttyS0` is also what `scripts/test_qemu.sh` drives headlessly.
`bootappend-live`'s `username=user` makes live-config apply the same
posture to SDDM (0085-sddm only autologins when a username is set on
the kernel cmdline) instead of parking the live session behind a login
prompt for its own undocumented default account.
