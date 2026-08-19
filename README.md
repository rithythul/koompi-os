# KOOMPI OS

A Debian-based Linux distribution for Cambodia, serving government,
schools, enterprises, developers/students, and general users through
edition profiles built from one shared base.

Core differentiators:

- **Instant Btrfs snapshot rollback** ("Time Machine") — snapper +
  grub-btrfs, with an automatic boot-success fallback if an update leaves
  the system unbootable. See `docs/ARCHITECTURE.md`.
- **`vita`** — a unified package interface (Zig) resolving koompi-repo →
  Debian → Flathub → distrobox, so users and Ansible-driven fleets have
  one command regardless of where a package actually comes from. See
  `docs/VITA_SPEC.md`.
- **Khmer-first localization.**

The KOOMPI Desktop Environment is a separate repository and is not part of
this project; v1 ships KDE Plasma (Wayland).

## Status

Phase 1: repository skeleton and specifications only. No `vita` or
`koompi-install` logic is implemented — both build as empty static
binaries to prove the toolchain. See `docs/` for the full design; nothing
in `docs/` describes work that has actually been done yet beyond what's
listed here.

## Repository layout

```
koompi-os/
  base/            # live-build config, common package list, branding
  editions/        # government/ school/ enterprise/ dev/ general/
  vita/            # Zig project — unified package interface
  installer/       # Zig project — koompi-install TUI
  repo/            # koompi-repo CI config, signing, inclusion policy
  scripts/         # build_iso.sh, test_qemu.sh
  docs/            # ARCHITECTURE.md, VITA_SPEC.md, EDITIONS.md, REPO_POLICY.md
```

## Editions

| Edition | Scope |
|---|---|
| `government` | Khmer-first, government middleware, conservative snapshot retention |
| `school` | Khmer-first, Veyon classroom management, curated education apps |
| `enterprise` | Productivity + collaboration, managed fleet updates via Ansible |
| `dev` | Developer toolchain, backports on, distrobox fallback on |
| `general` | Default consumer edition, Khmer-first, backports on |

Full scope per edition: `docs/EDITIONS.md`.

## Building

`vita` and `installer` are Zig 0.14.x projects, targeting
`x86_64-linux-musl`, fully static:

```sh
cd vita && zig build -Doptimize=ReleaseSafe
cd installer && zig build -Doptimize=ReleaseSafe
```

Zig 0.14.x exactly is required (not the latest release) — see each
project's `build.zig`. ISO assembly (`scripts/build_iso.sh`) and QEMU boot
testing (`scripts/test_qemu.sh`) are Phase 4 and not implemented yet.

## Docs

- `docs/ARCHITECTURE.md` — boot chain, subvolume layout, snapshot hooks,
  grub-btrfs integration, boot-success auto-fallback, installer TUI
  sequence, Khmer-in-TUI strategy, non-goals.
- `docs/VITA_SPEC.md` — CLI grammar, ledger schema, resolution order,
  snapshot orchestration, exit codes, `--json` shapes.
- `docs/EDITIONS.md` — manifest format, composition with `base/`, per-
  edition scope.
- `docs/REPO_POLICY.md` — koompi-repo signing, CI build flow, package
  inclusion policy.
