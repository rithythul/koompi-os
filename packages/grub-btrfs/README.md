# grub-btrfs

Vendored from upstream, not forked — `debian/` here is only KOOMPI's own
packaging overlay. `build.sh` clones upstream at the pinned tag, verifies
the resulting commit matches the pinned SHA, copies `debian/` on top, and
runs `dpkg-buildpackage`. The cloned source and the built `.deb` land
under the repo's gitignored `build/`, never committed.
