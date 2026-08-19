# Editions

Editions are profiles, never forks: one Debian base (see ARCHITECTURE.md
§1), and each edition is a directory under `editions/<name>/` containing
exactly three things layered onto that base at install time.

## 1. Directory format

```
editions/<name>/
  manifest.toml     # packages to install, by backend
  overlay/           # filesystem tree merged onto the target root
  policy.toml         # non-package behavioral settings
```

### 1.1 `manifest.toml`

Lists packages per backend, so the installer (and later, `vita`) knows
where each one is expected to resolve from without re-running full
discovery for every package at install time:

```toml
[koompi-repo]
packages = ["khmer-fonts", "khmer-input-method"]

[debian]
packages = ["kde-plasma-desktop", "firefox-esr"]

[flatpak]
packages = ["org.gimp.GIMP"]
```

A package listed here is expected to resolve via the named backend — the
installer does not re-derive backend choice from vita's resolution order
(ARCHITECTURE.md's four-layer order in VITA_SPEC.md §2) for manifest
packages; it installs each listed package directly via its listed backend.
The resolution order governs ad hoc `vita install` after the system is
running, not manifest bootstrap.

An edition's manifest is additive on top of `base/`'s common package list
(installed for every edition regardless of manifest content) — it is never
a full replacement list.

### 1.2 `overlay/`

A filesystem tree merged onto the target root during install (after
bootstrap, before account creation — installer step 11 in ARCHITECTURE.md §6).
Paths mirror their final location, e.g. `overlay/etc/skel/.config/...`.
Files here take priority over anything from `base/`'s overlay when both
provide the same path.

### 1.3 `policy.toml`

Non-package behavioral settings the installer and `vita` read at their
respective points:

```toml
[apt]
backports = false          # only "dev" and "general" default this true

[vita]
allow_distrobox_offer = false   # only "dev" defaults this true

[snapper]
timeline_limit_daily = 10

[account]
model = "sudo-user"   # or "separate-root"
```

Any key not present in an edition's `policy.toml` falls back to a base
default — editions only need to state what differs.

`account.model` decides what the installer's account-creation step (see
ARCHITECTURE.md §6, step 8) does with the user's answers: `sudo-user`
creates one user account with full sudo and leaves the root account
locked (Ubuntu/Debian-desktop-installer style — the base default, used
by `general`); `separate-root` additionally sets a distinct root
password and creates the user without sudo by default. No edition has
set `separate-root` yet — it exists for `government`/`enterprise` to opt
into once their `policy.toml` is written.

## 2. Composition with `base/`

`base/` holds the common package list (installed for every edition, no
exceptions), the shared filesystem overlay (branding, default configs),
and shared policy defaults. Composition order at install time:

1. Bootstrap via `mmdebstrap` with `base/`'s common package list.
2. Apply `base/`'s overlay.
3. Install the selected edition's `manifest.toml` packages, per backend.
4. Apply the selected edition's `overlay/` (overwriting any conflicting
   path from step 2).
5. Apply the selected edition's `policy.toml` over base defaults.

No edition subtracts from `base/` — there is no exclusion mechanism in
Phase 1. An edition that needs a Debian package *not* installed cannot
currently remove it via the manifest format; that's a gap to revisit only
if a real edition needs it (none of the five do, as scoped below).

## 3. Edition scope

**government** — Khmer-first, government middleware (document
signing/verification tooling, Veyon for lab/classroom-style remote
management where applicable), backports off, distrobox offer off,
conservative snapper retention. No AD/FreeIPA integration in Phase 1 (see
ARCHITECTURE.md §7).

**school** — Khmer-first, Veyon (classroom monitoring/control), curated
education-flatpak set, backports off, distrobox offer off. Optimized for
lab deployment consistency over user customization.

**enterprise** — Khmer-capable but not Khmer-first by default, general
productivity + collaboration flatpak set, backports off, distrobox offer
off. Assumes managed fleet updates via `vita update --json` under
Ansible.

**dev** — General productivity plus a developer toolchain (compilers,
editors, container tooling), backports **on** by default, distrobox offer
**on** by default (the one edition where the fourth resolution-order tier
is reachable without extra flags). Backports and distrobox existing
specifically to serve development workflows that need newer packages or
one-off environments Debian stable doesn't carry.

**general** — Default consumer-facing edition: everyday productivity and
media flatpaks, Khmer-first, backports **on** (so hardware/driver-adjacent
packages can be newer), distrobox offer off. This is the edition populated
with a real manifest and overlay in Phase 1 (`editions/general/`) to prove
the format; the other four are directory stubs until their content is
actually needed.
