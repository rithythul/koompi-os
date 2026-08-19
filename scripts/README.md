# scripts/

Build and test drivers.

- `builder.Containerfile` — a `debian:trixie` image with every tool the
  other two scripts need (debhelper, dpkg-dev, reprepro, live-build,
  mmdebstrap, xorriso, grub tools). None of this is installed on the
  host; everything Debian-side runs in this container.
- `build_iso.sh` — builds the 4 packages + signed local repo
  (`repo/build-repo.sh`), stages `editions/`, `base/`, the repo, and the
  built `vita`/`koompi-install` binaries into a `build/live-build/`
  working copy of `base/live-build/`, then runs `lb build`. Output:
  `build/iso/koompi-os.iso`.
- `test_qemu.sh` — the Phase 4 acceptance test. Boots the ISO under
  QEMU/OVMF against a fresh virtual disk, drives `koompi-install`
  non-interactively over the live session's serial console (the
  installer itself takes no CLI flags -- this pipes canned answers to
  its normal stdin prompts), then reboots straight into the installed
  disk and drives `apt-get install`, `snapper -c root list`, and `vita
  rollback` the same way. The autologin serial console and the
  `graphical.target` default-target used to drive these are written
  directly into the one qcow2 image this script builds -- never through
  `base/overlay` or any `.deb`, so none of it ships to a real install.
- `qemu_console.py` — connects to a QEMU `-serial unix:...` chardev
  socket, sends a payload in small chunks (avoids overrunning the tty's
  canonical-mode input buffer), and logs everything received until the
  guest powers off or a timeout hits.
