# KOOMPI OS — Standout Audit & Roadmap

**Date:** 2026-06-06
**Repo:** `~/workspace/koompi-os` (canonical) — github.com/rithythul/koompi-os
**Method:** every file:line claim below was re-verified against the live tree on
2026-06-06 by a 5-agent verification pass (workflow `koompi-audit-verify`). Where
the earlier audit was imprecise, this doc corrects it — see §2a.

---

## 1. Verdict

KOOMPI OS today is a **well-built reskin of end-4/dots-hyprland (illogical-impulse)
on Arch, plus an archiso skeleton.** The engine is solid and the branding has real
assets (wallpapers, logo). But three things keep it from being either *installable*
or *differentiated*:

1. **The installer doesn't run** — it's stubbed. So the semi-immutable / restore
   architecture (which is fully coded and wired) has never executed and is untested.
2. **The `[koompi]` package repo is unpublished** — there's nothing to install
   `koompi-*` packages from.
3. **The one real moat — regional/education ("Made in Cambodia, for Cambodian
   students") — is not shipped.** There is no Khmer anywhere in the OS.

Nothing here is a dead end. The restore stack is ~one stub away from running; the
moat is mostly packaging. This doc is the path.

---

## 2. Where it stands (verified)

### 2a. Semi-immutable / restore — CODE-COMPLETE + WIRED, UNTESTED, NEVER RUN

> **Correction to the earlier audit.** The prior framing ("designed-only, ~70%
> coded") undersold it. The restore stack is **fully implemented and actively
> called** inside `installer/src/post_install.sh main()`:

| Capability | Function | Defined | Called in `main()` |
|---|---|---|---|
| Overlayfs immutability hook | `setup_snapshot_boot()` | post_install.sh:136-151 | line 192 |
| Snapper + snap-pac | `setup_snapper()` | post_install.sh:58-88 | line 189 |
| `@baseline` factory-reset snapshot | `pin_baseline()` | post_install.sh:102-113 | line 193 |
| grub-btrfs boot-into-snapshot | `setup_grub_btrfs()` | post_install.sh:119-127 | line 194 |
| btrfs subvolumes `@ @home @var_log @var_cache @snapshots` | (disk_config) | archinstall.zig:122-127 | — |

**The whole stack is one gate away from executing.** `post_install.sh` runs via
`arch-chroot /mnt` only *after* archinstall provisions the disk — and that exec is
stubbed at `main.zig:311` (`"SCAFFOLD: would exec archinstall here; skipping in
stub"`). The file is also marked `⚠️ SCAFFOLD — UNTESTED. Do NOT run on a live
system` (post_install.sh:4-6).

So the accurate status is: **code-complete, wired, but never executed and never
tested** — not "five unfinished functions." Remove the stub, supply a real
disk_config, then VM-test. That's the work.

### 2b. Three blocking gates to a working, differentiated v1

- **G1 — Installer doesn't execute.** `main.zig:311` stubs the archinstall exec;
  the Review-confirmation gate is a TODO (`main.zig:264`); the disk_config is a fake
  template — literal `"obj_id": "<GENERATED-UUID>"` (archinstall.zig:104,115) and
  hardcoded subvolume names archinstall ignores (archinstall.zig:122-127). Net: zero
  real disk setup.
- **G2 — Installer not on the ISO.** `packages.x86_64:38` has `#koompi-installer`
  commented out. The live ISO autologins root and runs `.automated_script.sh`, which
  finds no installer and prints *"installer not present yet (skeleton ISO). Dropping
  to a shell."* (the `exec` line is commented). **A v1 build boots to a root shell.**
- **G3 — `[koompi]` repo unpublished.** The `[koompi]` stanza in
  `iso/koompi/pacman.conf:26-28` is commented out (`#Server =
  https://repo.koompi.org/$repo/os/$arch` — placeholder). The builder
  `sdata/dist-arch/repo/build-repo.sh` is a skeleton with TODO GPG key + publish URL
  (its README says so explicitly). Nothing can install `koompi-*` packages.

### 2c. The moat (regional / education) — verified NOT shipped

| Gap | Evidence |
|---|---|
| 14 translation JSONs, **zero Khmer** | `dots/.config/quickshell/koompi/translations/` — de/en/es/fr/he/id/it/ja/pt/ru/tr/uk/vi/zh, no `km`/`km_KH` |
| No Khmer font | `koompi-fonts-themes/PKGBUILD:8-25` — no `noto-fonts-khmer` |
| No Khmer input | no `koompi-*/PKGBUILD` depends on `fcitx5` |
| Default locale `en_US` despite Cambodia timezone | locale `en_US.UTF-8` (config.zig:29, koompi.toml:41) vs timezone `Asia/Phnom_Penh` (config.zig:30) |
| Khmer assets exist but orphaned | `dots-extra/fcitx5` + `dots-extra/fontsets` exist; **zero** repo references — no PKGBUILD ships them |

### 2d. Branding — partially real, partly skeleton

- **Ships for real:** wallpapers `koompi-antlers.jpg` + `koompi-synthwave.jpg`,
  logo `koompi-symbolic.svg` (koompi-branding/PKGBUILD).
- **Skeleton/placeholder:** SDDM greeter points at stock `breeze`
  (`files/sddm/10-koompi.conf:6 Current=breeze`); Plymouth is a black-bg wordmark
  ("replace with the Naga animation"); GRUB `theme.txt` is a stub ("replace with Naga
  art").
- **OOBE gap:** `welcome.qml:82` greets generic *"Hi there!"*; links end-4's wiki
  (welcome.qml:448) and shows a *"Support end-4"* sponsor button (welcome.qml:478-480).
  `About.qml` reads *"Built on illogical-impulse"* (98) + *"Support end-4"* (141) —
  attribution is correct, but there's no KOOMPI/Cambodia/education framing anywhere
  in first-run.

---

## 3. Roadmap

### Track A — Make it run (ship-blockers)

- **A1. Unblock installer execution.** Replace the `main.zig:311` stub with the real
  archinstall exec; wire the `main.zig:264` Review gate to an actual keypress.
- **A2. Real archinstall disk_config.** Pin an archinstall version; generate the
  disk_config JSON from `archinstall --dry-run` / its schema instead of the
  `<GENERATED-UUID>` fake template; let archinstall assign UUIDs.
- **A3. Put `koompi-installer` on the ISO.** Uncomment `packages.x86_64:38` (needs A4
  so it can resolve from `[koompi]`).
- **A4. Publish the signed `[koompi]` repo.** Real GPG key + publish target in
  `repo/build-repo.sh`; build and host at `repo.koompi.org`; uncomment the
  `pacman.conf` `[koompi]` stanza.
- **A5. VM-test the restore lifecycle.** The post_install.sh stack is coded+wired but
  UNTESTED — install in a VM and verify `@baseline` snapshot, grub-btrfs
  boot-into-snapshot, and snapper rollback actually factory-reset. (Depends on A1.)

### Track B — The moat (make "for Cambodian students" true)

- **B1. Ship Khmer base.** Add `km_KH.json` translation; add `noto-fonts-khmer` to
  `koompi-fonts-themes`; package `dots-extra/fcitx5` + an fcitx5 Khmer engine as a
  `koompi-input` package and pull it into `koompi-base`. (Pure packaging — no
  installer dependency, can land in parallel with Track A.)
- **B2. km_KH locale default via geoIP.** When the installer resolves
  `Asia/Phnom_Penh`, default locale to `km_KH.UTF-8` (en_US fallback) instead of
  `en_US` (config.zig:29).
- **B3. Education bundle (bare-environment-respecting).** A small **opt-in**
  `koompi-education` metapackage (offline dictionary, KhmerOS tools, a few student
  apps) — not forced into the base.
- **B4. One-click student factory-reset.** ⏳ *Scaffolded 2026-06-06.* The Zig CLI
  `koompi-restore` (installer/src/{restore_main,reset,snapper,proc}.zig) is written:
  default **System Restore** (`snapper rollback @ → @baseline`, keeps /home) and
  `--full` **Full Factory Reset** (also wipes/reseeds /home offline via a
  marker-gated boot unit, `reset_home.sh` + the `.service`). Required install-side
  fix landed in `post_install.sh`: `fix_root_subvol_mount()` unpins `/` from
  `subvol=@` in fstab so `snapper rollback` actually boots (else it silently
  no-ops), and `install_home_reset_unit()` bakes the gated wipe into the baseline.
  **Known-open before this works on hardware:** the fstab unpin is *necessary but
  not sufficient* — `snapper rollback` boots by flipping the btrfs default
  subvolume, but grub-mkconfig's 10_linux typically also bakes `rootflags=subvol=@`
  onto the kernel cmdline, which overrides that flip and makes the rollback no-op
  at the GRUB layer. Only the fstab leg is closed; the GRUB leg is not.
  **⚠️ `--full` DATA-LOSS GATE:** the offline /home wipe could wipe every user's
  /home while leaving the system un-reset (if a no-op boot — the open GRUB leg —
  ran the wipe anyway). **Fix IMPLEMENTED** (pending VM-verification of the subvol
  detection): `koompi-restore` arms the marker *after* the rollback, writing the
  rollback's `--print-number` snapshot id into it, and `reset_home.sh run`
  verifies the running root subvol is that snapshot before deleting @home
  (skip + keep-marker on mismatch → fails SAFE on a no-op boot). Robustness also
  done: `sync` before unmounts + idempotent `@home` re-create. **Still required
  before `--full` runs on real hardware:** VM-verify the running-subvol detection
  AND close the GRUB `rootflags=subvol=@` leg (the guard makes a no-op boot
  non-destructive, but does not make the rollback succeed).
  **Remaining:** pin zig 0.14 to compile (shared blocker with the installer — see
  §5); close the GRUB `rootflags=subvol=@` leg (strip it, or route restore through
  the grub-btrfs "boot into @baseline" entry); package it (`koompi-restore`
  PKGBUILD + polkit policy + a Settings/GUI button); VM-test both modes end-to-end
  (depends on A5). Facts to verify on a real target before shipping: the actual
  genfstab `subvol=` form, whether grub.cfg carries `rootflags=subvol=@`, and
  snapper's `--jsonout` userdata shape (we parse `--csvout` to sidestep the latter).

### Track C — Identity polish (cheap, high-signal)

- **C1. KOOMPI welcome OOBE.** Rewrite the `welcome.qml` greeting with KOOMPI /
  Cambodia / education mission; swap the end-4 wiki link for a KOOMPI quickstart;
  keep attribution in About but drop the "Support end-4" donate CTA from first-run.
  (~1 hour, immediately changes first-run perception.)
- **C2. Boot/login chrome.** Land the Naga art for the SDDM greeter, the Plymouth
  animation, and the GRUB theme — replacing the three skeletons.

---

## 4. Sequencing

```
critical path to "real installable OS w/ working restore":  A1 → A2 → A5
gate a usable ISO:                                          A3 + A4
cheapest moat win, parallelizable now:                      B1
~1h identity win, parallelizable now:                       C1
then:                                                       B2, B3, B4, C2
```

---

## 5. Explicitly NOT gaps (don't re-litigate)

- **Inheriting the end-4 engine** — deliberate soft-fork (see `UPSTREAM.md`). Track
  upstream, diverge on identity surfaces. Not tech debt.
- **Bare-environment app policy** — chosen; ship shell + system tools, users install
  apps.
- **Zig installer paused for zig 0.16** — known; not abandoned.
- **Multi-distro packaging dropped** — Arch-only by decision (v1 = Arch + archiso).
