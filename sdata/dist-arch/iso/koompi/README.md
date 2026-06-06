# KOOMPI OS — archiso profile (SKELETON)

A minimal [archiso] profile for building the **KOOMPI OS** live/installer ISO.
It mirrors Arch's official `releng` profile, trimmed to what KOOMPI needs.
Everything here is scaffolding — see **What is stubbed** before expecting a clean
build.

Base: **Arch Linux only** (x86_64). Release era: **Naga** (v1, see
`docs/naming.md`).

## Where this sits in the ISO chain

```
signed [koompi] pacman repo (repo-add + GPG)
        ->  THIS archiso profile (profiledef.sh, packages.x86_64, pacman.conf, airootfs/)
        ->  mkarchiso
        ->  the Zig installer on the live ISO  ->  archinstall  ->  installed KOOMPI
```

The live ISO is **DE-agnostic**. The TARGET edition the user picks at install time
— `koompi-desktop-hyprland` **or** `koompi-desktop-kde` — is pacstrapped onto the
disk by the installer (archinstall engine), **not** listed in `packages.x86_64`.

## Files in this profile

| File | Purpose |
|------|---------|
| `profiledef.sh` | ISO identity, bootmodes (BIOS syslinux + UEFI systemd-boot), file permissions. |
| `pacman.conf` | Build-time repos: standard Arch + the `[koompi]` repo (placeholder `Server=`). |
| `packages.x86_64` | The live-ISO package set (base, kernel, archinstall, installer, btrfs/snapper/grub tooling). |
| `airootfs/etc/os-release` | The KOOMPI os-release for the live env (installer writes the same to the target). |
| `airootfs/root/.automated_script.sh` | Live-session installer autostart **stub** (does not auto-run yet). |

## Prerequisites

- `archiso` installed on the build host (`pacman -S archiso`).
- Run as **root** (mkarchiso needs it).
- **The signed `[koompi]` repo must already exist and be reachable.** `pacman.conf`
  points `[koompi]` at a placeholder `Server=` URL; mkarchiso cannot sync packages
  until that repo is real. Build the koompi-* packages from `sdata/dist-arch/*`,
  `repo-add` + GPG-sign them, and host them (or point `Server=` at a local path).

## Build

```sh
# from this directory (sdata/dist-arch/iso/koompi/)
sudo mkarchiso -v -w /tmp/koompi-work -o /tmp/koompi-out .
```

Output: `/tmp/koompi-out/koompi-naga-YYYY.MM.DD-x86_64.iso`.

## What is stubbed (this WILL NOT build clean as-is)

This is a deliberate skeleton. mkarchiso will fail until these land:

1. **`[koompi]` repo is a placeholder.** The `Server=` URL is fake and `SigLevel`
   is the bootstrap stopgap `Optional TrustAll`. Stand up the signed repo, fix the
   URL, then switch `pacman.conf`'s `[koompi]` `SigLevel` to
   `Required DatabaseOptional`. Never ship a `TrustAll` build.

2. **Bootloader config dirs are missing.** `bootmodes` in `profiledef.sh` reference
   systemd-boot (`efiboot/loader/…`) and syslinux (`syslinux/…`) config dirs that
   this skeleton does **not** include. Copy them from `releng` and re-brand, or
   mkarchiso aborts. (NOTE: this is the *live* ISO's bootloader; the *installed
   target* uses GRUB for grub-btrfs — that's the installer's job.)

3. **Zig installer binary.** `packages.x86_64` has `koompi-installer` commented
   out; it is built from `installer/` and must be dropped into the airootfs at
   `/usr/local/bin/koompi-installer` (or packaged into `[koompi]`).

4. **Installer autostart wiring.** `airootfs/root/.automated_script.sh` does not run
   on its own — archiso fires it via root's `~/.zlogin`. Add that `.zlogin` trigger
   (or a systemd service) to actually launch the installer on boot.

5. **Pin archinstall.** Its `user_configuration.json` schema drifts between
   releases. Pin a known-good version at the repo/build level (not expressible in
   the flat `packages.x86_64`).

6. **Branding art.** Plymouth / GRUB / SDDM Naga themes are functional placeholders
   (interim SDDM `Current=breeze`); see `koompi-branding`.

[archiso]: https://gitlab.archlinux.org/archlinux/archiso
