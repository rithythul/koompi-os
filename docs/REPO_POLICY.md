# koompi-repo policy

Phase 1 specification for our own apt repository — the highest-priority
backend in vita's resolution order (VITA_SPEC.md §2).

## 1. Signing

- Repository is signed with a dedicated koompi-repo GPG release key, not a
  personal or CI-account key. The public key ships as a package
  (`koompi-archive-keyring`) pre-seeded on the ISO and in `base/`'s
  package list, so a freshly installed system trusts the repo without a
  manual `apt-key`-equivalent step.
- Release files (`InRelease`/`Release.gpg`) are signed at publish time by
  CI using a key held in CI's secret store — the private key is never
  checked into this repository and never touches a build worker's disk
  outside the signing step.
- Key rotation: the keyring package supports multiple valid keys
  simultaneously (old + new) for one release cycle, so systems update the
  keyring package itself before the old key is retired — avoids a
  chicken-and-egg trust break.

## 2. CI build flow

1. Source packages for koompi-repo content (vita, koompi-install,
   koompi-snapper-hooks, the Khmer stack, vendored packages like
   grub-btrfs — see §3) live in their own source trees/repos, each
   producing a `.deb` via a standard Debian packaging build
   (`dpkg-buildpackage` or equivalent) in CI.
2. Built `.deb`s are published into a repository managed by `reprepro`
   (chosen over `aptly` for Phase 1: simpler mental model — a declarative
   `conf/distributions` file per suite — and no separate database service
   to run in CI; revisit only if multi-version/pool management outgrows
   it).
3. `reprepro` handles pool layout, `Packages`/`Release` generation, and
   signing (§1) as part of the same CI job that ingests new `.deb`s.
4. One suite per Debian release we track (currently `trixie`), so
   koompi-repo's suite name matches the base Debian suite it layers onto —
   avoids a separate mental mapping between "which koompi-repo suite goes
   with which Debian release."
5. CI publishes to the public repo host only from the default branch of
   each source tree, on a tag — no direct pushes from a build worker to
   the published repo outside that path.

## 3. Package inclusion policy

koompi-repo carries **only what an edition manifest requires, or what
users demonstrably request** — it is not a general-purpose package
mirror or a dumping ground for "might be nice."

In scope:

- Our own tools: `vita`, `koompi-install` (packaged as `.deb`s from this
  repository's `vita/` and `installer/` for systems that want them outside
  the ISO), `koompi-snapper-hooks`.
- Khmer input/fonts stack (Khmer keyboard layouts/input method, Khmer web
  and UI fonts) — not carried in Debian stable at the depth KOOMPI needs.
- Government middleware required by the `government` edition's manifest.
- Veyon, required by the `school` (and optionally `government`) edition's
  manifest — not in Debian's archive.
- **grub-btrfs**, vendored from upstream (github.com/Antynea/grub-btrfs)
  and packaged as a `.deb` — confirmed absent from Debian's archive
  (ARCHITECTURE.md §4.2). This is infrastructure every edition needs
  (boot-into-snapshot), not edition-specific, but it ships from
  koompi-repo rather than `base/`'s raw file list because it needs proper
  `.deb` packaging (systemd unit, postinst enabling `grub-btrfsd`) rather
  than loose files.
- Demand-driven extras: anything else only after a real, tracked user
  request — not spec'd preemptively here.

Explicitly out of scope for koompi-repo:

- Anything already adequately served by Debian stable, security, or
  backports (layers 2) — no re-packaging just to have "our" version.
- Anything better served by Flathub (layer 3) — GUI applications default
  to flatpak per the resolution order; koompi-repo does not compete with
  Flathub for ordinary desktop apps.
- Anything one edition's long tail needs but doesn't justify shipping to
  every system with koompi-repo enabled — that's what `dev`'s distrobox
  fallback (layer 4) exists for instead.

## 4. Versioning and updates

- koompi-repo package versions follow Debian's `<upstream>-<revision>`
  convention (e.g. `0.1.0-1`), so `apt`/`vita` version comparison behaves
  normally against Debian-native packages of the same tool where relevant.
- No separate "channel" concept (stable/testing) in Phase 1 — one suite
  per Debian release (§2.4), updated in place as CI publishes new builds.
  A staging/testing channel is a candidate for a later phase if
  koompi-repo's own package count and update frequency justify it.
