# KOOMPI OS — Factory Reset & Restore UX

**Date:** 2026-06-06
**Scope:** the end-to-end user experience of restoring / factory-resetting a KOOMPI
laptop — every surface, walked through with concrete student/teacher scenarios.
**Companion docs:** mechanics live in [`roadmap.md`](roadmap.md) §2a + B4 and in
`installer/src/{reset,snapper,proc,restore_main}.zig`, `reset_home.sh`, and the
`.service`. This doc is the UX layer over those.

---

## 0. Read this first — what actually works today (the spine)

Everything below hangs off this honest ordering. There are **three** reset paths and
they are **not** equally real right now:

| Path | What it does | Status **today** |
|---|---|---|
| **GRUB → "KOOMPI @baseline"** menu entry | Boots the factory system image. Keeps `/home`. | **Most reliable path.** Works at the boot layer, needs no running desktop. *Caveat:* boots **read-write** only if the `grub-btrfs-overlayfs` initramfs hook is present — `post_install.sh setup_snapshot_boot()` **skips** it when mkinitcpio uses the `systemd` hook, leaving snapshot boots **read-only**. Until reconciled, treat "usable desktop from @baseline" as conditional. |
| **`koompi-restore`** (CLI) / **GUI button** | System Restore (keeps `/home`) or `--full` (wipes `/home`). | **Intended end-state, not usable yet.** Written, **never executed, never VM-tested**; targets zig 0.14 and does not compile on the dev box's zig 0.16. The GUI button + its polkit policy + the Settings page **do not exist** in QML. |
| **`koompi-restore --full`** (wipe `/home`) | Factory-resets system **and** all user files. | **⚠️ Has an unresolved data-loss hazard — must NOT run on real hardware** until two gates land (see §6). |

**Two facts that shape the whole UX and must never be soft-pedalled:**

1. **The keep-vs-wipe line is a btrfs fact, not a wording choice.** `/home` is the
   separate `@home` subvolume. **System Restore and the GRUB @baseline boot never
   enter it** → user files survive. **Only `--full` deletes `@home`.**

2. **The CLI rollback can silently no-op (KNOWN-OPEN GRUB leg).** `snapper rollback`
   changes what boots by flipping the btrfs *default* subvolume, but
   grub-mkconfig's `10_linux` typically bakes `rootflags=subvol=@` onto the kernel
   cmdline, which overrides the flip. Consequence: today, **the GRUB menu entry —
   not the CLI — is the mechanism most likely to actually reset the system.**

> **Terminology honesty.** "Not built / never run" ≠ "absent." The Zig CLI, the
> wipe script, and the systemd unit **are written and in the repo**; they have just
> never been executed or tested. Where this doc says "intended," it means the code
> exists but the path is unverified — not that nothing is there.

---

## 1. Mental model — three things a user can do

```
                 Did the laptop still boot to the desktop?
                         │
            ┌────────────┴─────────────┐
           YES                         NO
            │                           │
   What do you want?            Boot GRUB → snapshots →
   ┌────────┴─────────┐         "KOOMPI @baseline"   ← reliable today
   │                  │         (system fresh, /home kept)
 Fix the system   Erase
 keep my files    everything
   │                  │
 System Restore   Full Factory Reset  ← ⚠️ destructive, gated
 (keeps /home)    (wipes + reseeds /home)
```

- **System Restore** — "my computer is broken, make the *system* like new, but keep
  my documents." Reverts `@` to `@baseline`. `/home` untouched. Reversible (the
  pre-reset `@` is itself snapshotted first).
- **Full Factory Reset** — "wipe this machine for the next person." Reverts `@` **and**
  deletes+reseeds `@home`. **Irreversible for `/home`** (no `/home` snapshot is taken).
- **GRUB recovery** — "it won't even boot." Pick the `@baseline` entry at the boot
  menu; keyboard-only; keeps `/home`.

---

## 2. The surfaces (where each path lives)

- **GUI button — *planned*.** Quickshell `settings.qml` has 8 nav pages
  (Quick/General/Bar/Background/Interface/Services/Advanced/About). The natural home
  is a **9th "System / Maintenance" page** after Advanced, or a card in `welcome.qml`.
  The button would launch `koompi-restore` elevated via **polkit**. None of this
  exists in QML yet, and no `koompi-restore` polkit `.policy` file exists.
- **CLI — written.** `koompi-restore` (System Restore), `koompi-restore --full`
  (Full Factory Reset), `--dry-run` (show the plan, change nothing), `--yes` (skip
  confirmation — automation only). Must run as root.
- **GRUB — wired at install.** `post_install.sh` enables grub-btrfs and pins an
  un-prunable `@baseline` snapshot; the boot menu gains a snapshots submenu that
  includes **"KOOMPI @baseline (factory reset point)"**.

### The exact CLI text (from `reset.zig`)
```
KOOMPI OS — restore to factory baseline
  mode      : System Restore         (or: FULL FACTORY RESET)
  baseline  : snapshot #N  (the un-prunable @baseline)
  /home     : kept (untouched)       (or: ERASED + reseeded from /etc/skel)

Proceed with System Restore? Files in /home are kept. [y/N]
   — or, for --full —
FULL FACTORY RESET erases ALL files in /home. Type RESET to confirm:

rolled @ back → new root snapshot #N. Rebooting…
```
Guard errors (mapped in `restore_main.zig`): `must be run as root` · `/ is pinned in
fstab …` · `no @baseline snapshot found` · `aborted. Nothing changed.`

---

## 3. Scenario walkthroughs

Each scenario: **situation → path → what they see → under the hood → outcome → if it
goes wrong.** Personas are KOOMPI's real users — Cambodian students (often first
laptop), shared lab machines, ICT teachers managing fleets, frequent power cuts,
spotty internet, Khmer-first.

---

### 3.1 — System Restore from the GUI (keep my files) · *flagship happy path*

**Situation.** Sophea, 15. Her only laptop. She followed a YouTube guide, edited some
config, and now the desktop misbehaves. Her Khmer-literature essay is in `~/Documents`,
due tomorrow. She is terrified of losing it.

**Path.** GUI button → confirm dialog → polkit → reboot. *(Surface is planned.)*

| She sees | She does | Under the hood |
|---|---|---|
| Settings → **System** page (planned 9th page). Two cards: a friendly **"Reset system — keep my files"**, and far below, in a red danger card, **"Erase everything"** she's meant to ignore. | Taps the friendly button. | Maps to `koompi-restore` default mode (`reset.zig` `Mode.system`). |
| Dialog: *"Restore your system? Your personal files in Home are kept — your essay and everything in Documents will still be there. Your computer will restart once."* `Cancel` / `Restore`. | Reads the "your essay will still be there" line, clicks **Restore**. | The dialog text is a faithful translation of the CLI's `Files in /home are kept` promise. |
| Polkit password dialog (KOOMPI's themed in-shell agent). | Types the admin password, OK. | `koompi-restore` must run as root (`ensureRoot`). |
| Brief *"Restoring… restart in a moment"* spinner — over in seconds. | Waits. | `snapper -c root rollback @ → @baseline`: a btrfs **CoW metadata flip**, no bulk copy. snapper first snapshots the *current broken* `@` (so even that is recoverable), then makes `@baseline` the default subvol. |
| Reboots **once**, boots to the login screen. | Logs in normally. | `systemctl reboot`. **(See "if it goes wrong" — the boot landing clean is not guaranteed yet.)** |

**Outcome.** **Kept:** everything in `/home` — essay, Documents, Pictures. **Erased:**
nothing in `/home`; only `@` (system + `/etc` + system configs) reverted to factory.
**Reboots:** 1. **Time:** ~1–2 min wall-clock, almost all of it the reboot.

**If it goes wrong / honest caveats.**
- **Scope mismatch (important).** System Restore fixes **system** (`@`) damage. If
  Sophea's breakage was in **her own** `~/.config` (which lives in `@home`), the
  restore **keeps** it — so it won't fix her problem. The UX must set this
  expectation: "this fixes the *system*; it does not touch your personal settings."
- **CLI no-op risk.** If the GRUB `rootflags=subvol=@` leg bites, the reboot lands on
  the old `@` and nothing changed — the tool would still have said "Rebooting…".
  Reliable fallback **today**: the GRUB `@baseline` entry (§3.3).
- **Can't open Settings at all?** → GRUB path (§3.3).

---

### 3.2 — Full Factory Reset for hand-off (erase everything)

**Situation.** Dara, 18, graduating. School laptop goes to a Grade-7 student next week.
He's logged into Gmail/Telegram, has photos and saved passwords. He wants **nothing**
of his left.

**Path.** `koompi-restore --full` (CLI today; GUI danger-button later).

| He sees | He does | Under the hood |
|---|---|---|
| Plan header: `mode: FULL FACTORY RESET`, `/home: ERASED + reseeded from /etc/skel`. | Reads it. | `reset.zig` prints the plan before any change. |
| `FULL FACTORY RESET erases ALL files in /home. Type RESET to confirm:` | Types **`RESET`** (not `y` — a deliberately harder, type-the-word gate). | `confirm(.full)` compares the exact string `RESET`; anything else → `aborted. Nothing changed.` |
| `rolled @ back → new root snapshot #N. Rebooting…` | Lets it reboot. | Marker armed on the rollback-proof top-level subvol → `snapper rollback` → `systemctl reboot`. |
| On next boot, a brief plain-console line `[koompi-reset-home] …` before the login screen. | Waits (must not power off). | The baseline's gated unit runs **before** `home.mount`: deletes `@home`, recreates it, reseeds each user from `/etc/skel`, clears the marker. |
| Factory login → first-run as a clean account. | Hands the laptop over. | Next student gets a factory system + empty, skel-seeded home. |

**Outcome.** **Kept:** nothing of Dara's. The user *accounts* from `@baseline` persist,
but their home *contents* are wiped + reseeded. **Erased:** all of `/home`
(`btrfs subvolume delete @home`) + `@` reverted. **Reboots:** 1 (the wipe runs during
it). **Time:** ~2–5 min on low-spec hardware.

**⚠️ This path is BLOCKED on real hardware.** See §6. Reasons:
- **Asymmetric-reset hazard — now guarded (pending VM verification).** Previously the
  `/home` wipe was armed *before* the rollback and gated only on the marker, so with
  the GRUB leg open it could **wipe every user's `/home` while leaving the system
  un-reset**. Fixed: the marker is now armed *after* the rollback carrying the new
  snapshot number, and the boot-time wipe only runs if the running subvol **is** that
  snapshot — a no-op boot now **skips the wipe and keeps `/home`**. Still blocked
  until that detection is VM-verified and the GRUB leg is closed.
- **No backup prompt + irreversible.** Unlike System Restore, **no `/home` snapshot is
  taken** before the delete. Once gone, gone.

**If it goes wrong.** `RootSubvolPinned` / `BaselineNotFound` → loud refusal, no
change. Offline wipe finds `/home` mounted → `ABORT: /home is mounted; refusing to
replace @home` (no half-state). Power cut → see §3.6.

---

### 3.3 — GRUB `@baseline` recovery (it won't boot) · *most reliable path today*

**Situation.** A lab laptop took a bad update / botched config and black-screens or
drops to a console on boot — never reaches the login screen. The GUI button and even a
normal login are **unreachable**. Recovery is keyboard-only at the GRUB menu.

**Path.** Boot menu → snapshots submenu → "KOOMPI @baseline".

| They see | They do | Under the hood |
|---|---|---|
| Power-cycle; at boot, the GRUB menu (reveal key varies — `Esc`/`Shift`, held from firmware-logo). | Open the menu, scroll to a **"snapshots"** submenu. | grub-btrfs enumerates snapshots into a GRUB submenu. |
| In the submenu, among dated entries, **"KOOMPI @baseline (factory reset point)"**. | Select it, Enter. | The `@baseline` snapshot pinned at install. |
| Boots to a working KOOMPI desktop; logs in with the usual password; **all files present**. | Uses the machine. | Booting `@baseline` *bypasses* the broken `@`. `/home` (`@home`) is untouched. **Read-write only if the overlayfs hook is present** — else it's a read-only emergency boot (see caveats). |
| **Choice:** (A) just use it as-is, or (B) make it permanent. | (A) carry on; (B) run System Restore from inside. | (A) is ephemeral — you re-pick the entry each boot. (B) `koompi-restore`/`snapper rollback` to commit. |

**Outcome.** **Kept:** all of `/home`. **Erased:** nothing — the broken state is
*bypassed*, not deleted. **Reboots:** 1 to reach the desktop; +1 if you commit
(option B). **Time:** ~1–3 min, mostly hunting for the reveal key.

**If it goes wrong / honest caveats.**
- **Drops to an emergency shell instead of a desktop** → the
  `grub-btrfs-overlayfs` hook was skipped (read-only snapshot boot). This is a real,
  known gap (§6). The system is still recoverable read-only; committing via option B
  then a normal boot is the way out.
- **No `@baseline` entry at all** → baseline never pinned (install incomplete).
- **Committing (option B) reboots back to the black screen** → the rollback hit the
  open GRUB `rootflags` leg and no-op'd. Re-pick the GRUB entry; the permanent fix
  needs the GRUB leg closed (§6).
- **A fault that lives in `/home`** survives this path (and System Restore) — both keep
  `@home`. Only `--full` would clear it.
- **No root password (shared machine)** → option A still fully works; option B needs root.

---

### 3.4 — Fleet reset, 30 lab laptops (teacher)

**Situation.** Ms. Chan, ICT teacher, resets 30 KOOMPI laptops to factory between
terms. Weekend, spotty internet. The reset itself needs **no internet** (local
snapshots + `/etc/skel`).

**Path.** Per machine: `sudo koompi-restore --full --yes`, with the GRUB `@baseline`
entry as fallback. **Today this is largely manual and partly blocked.**

**What the workflow looks like.**
- `--yes` skips the type-`RESET` gate (automation). **This removes the only brake** —
  it must be a deliberate, machine-scoped action, never a careless paste.
- After each machine, **verify** it actually reset: the booted subvol is the
  `@baseline`-derived one *and* `/home` is freshly skel-seeded. There is **no
  `--verify` and no batch dashboard** — verification is manual today.
- Machines where the CLI rollback no-op'd (GRUB leg) need the **GRUB `@baseline`
  fallback** per machine (boot the entry, then commit) — extra reboots.

**Outcome (per machine).** **Kept:** nothing from last term. **Erased:** all prior
`/home` + `@` reverted. **Reboots:** 1 (offline wipe runs during it); +2 if the GRUB
fallback is needed (boot `@baseline`, then reboot after commit). **Time:** ~2–4 min
each; realistically a multi-hour weekend across 30 by hand.

**Honest gaps (what's *not* automatable yet).**
- **No fleet surface** — 30 machines = 30 manual touches; no SSH fan-out, no
  pass/fail ledger.
- **`--full --yes` has no machine-scoped safety** — no hostname allowlist, no
  dry-run-then-commit lock. One wrong paste irreversibly wipes a machine.
- **The asymmetric hazard (§3.2) applies at fleet scale** — a silent no-op means
  last cohort's private data is exposed to the next cohort. **Blocked until the gates
  in §6 land.** Until then, drive the system reset through the **GRUB `@baseline`
  entry**, and treat the `/home` wipe as not-yet-safe-to-automate.

---

### 3.5 — Safety: "can a curious kid nuke a thesis?"

**Situation.** A 13-year-old pokes around Settings and finds the reset controls. What
stops accidental data loss?

**The guard model (today + intended).**
1. **Two different confirmations.** System Restore = `[y/N]`. Full Reset = **type the
   word `RESET`** — deliberately higher friction.
2. **`--dry-run`** prints the plan and changes nothing — a zero-risk "show me what
   would happen."
3. **System Restore keeps `/home`** *and* snapshots the pre-reset `@` first → it is
   **reversible**. Full Reset is the **only** destructive path.
4. **Root required.** The GUI elevates via polkit → a non-admin kid is stopped at the
   password dialog before anything is touched. *(Today: the polkit `.policy` doesn't
   exist yet — this wall is planned, not guaranteed; see §6.)*

**Recommended GUI confirmation UX (the design ask).**
- **Safe button:** **"Reset system (keep my files)"** — Khmer:
  *កំណត់ប្រព័ន្ធឡើងវិញ (រក្សាឯកសារ)* — neutral color, single confirm.
- **Destructive button:** **"Erase everything (factory reset)"** — Khmer:
  *លុបទាំងអស់ (កំណត់ដូចដើម)* — red/danger card, visually separated, behind a
  second screen that names what is lost ("photos, accounts, all files for **every**
  user on this laptop") **and** a type-to-confirm gate, then polkit.
- **A "do not power off" splash** during the offline `/home` wipe (low-spec machines
  go quiet for a minute — silence reads as "frozen" and invites a hard power-off).
- **Decide:** should a non-admin even *see* the destructive control? (Greyed +
  lock, hidden, or polkit-gated.)

**Shared-lab reality to surface in copy.** Full Reset erases **all** users' files, not
just the actor's. One reset can wipe every student's work on that machine.

---

### 3.6 — Power dies mid-wipe (failure-mode audit)

**Situation.** Cambodian power cuts are common. A student starts a **Full** reset; the
machine reboots to wipe `/home` — and the power dies mid-wipe.

**Marker semantics.** The wipe is gated by a marker on the rollback-proof top-level
subvol and runs **before** `home.mount`. The intended design self-heals: the marker is
**cleared last** (after reseed completes), so an interrupted wipe simply re-runs on the
next boot until it finishes once cleanly.

**Cut-point analysis (honest — this is an audit, not marketing).**

| Cut point | Safe? | Behavior |
|---|---|---|
| After arm, before reboot | ✅ *(now guarded)* | Marker is set, carrying snapshot N. Next boot wipes `/home` **only if** it booted snapshot N. A no-op boot (old `@`) → guard **skips** the wipe and keeps the marker. The old asymmetric case (`/home` wiped, system un-reset) is prevented. |
| During the rollback | ✅ | btrfs CoW; metadata flip either took or didn't. Re-run. |
| During `btrfs subvolume delete @home` | ✅ *(now idempotent)* | Re-create now deletes any remnant first, then creates; if create fails, the marker is kept → next boot retries rather than leaving `/home` unmountable. |
| During reseed | ✅ | Marker still set → next boot re-deletes + reseeds. |
| After clear-marker | ✅ | One harmless redundant boot; no marker → no-op. |

**Net.** Now idempotent and power-cut-tolerant by design, with the durability +
asymmetry gaps closed in code: (1) `sync` before unmount makes marker state durable
across an abrupt cut; (2) the `@home` re-create is idempotent; (3) the asymmetric
hazard is guarded (wipe only on a verified baseline boot). **Still pending:**
VM-verification of the running-subvol detection and the open GRUB leg (§5).

> *Correction to one verifier:* in the cut-before-commit case the reseed reads the
> **old** `@`'s `/etc/passwd` (not the baseline's), because the rollback didn't
> commit. User-data *safety* is unaffected (accounts match), but it confirms the
> asymmetry — the wipe should never run when the boot isn't on `@baseline`.

**Correct user action after an interrupted reset:** *turn it back on and wait* — the
wipe resumes. This needs to be documented and ideally shown on the boot splash; right
now there is **no on-screen guidance**.

---

## 4. Consolidated open UX decisions

Surfaced across the scenarios; each needs a design call:

- **GUI exists at all** — System/Maintenance settings page vs Welcome card; and the
  button → polkit → CLI wiring. *(The CLI `confirm()` reads stdin; launched via polkit
  there's no TTY → stdin EOF → it aborts. The GUI needs its own confirm dialog that
  invokes the CLI non-interactively.)*
- **Polkit `.policy`** — authored with a **Khmer** message; and whether one dialog
  guards both modes or the destructive mode gets distinct, scarier text.
- **Khmer localization of the entire flow** — button labels, reassurance copy, confirm
  dialog, GRUB entry label, **and the type-to-confirm keyword** (must a Khmer-locale
  student type the Latin `RESET`?).
- **Admin password availability** — does a single-student laptop even have an admin
  credential the kid knows? If not, polkit dead-ends them.
- **GRUB discoverability** — pin `GRUB_TIMEOUT`/`GRUB_TIMEOUT_STYLE` so the menu is
  reachable; brand the submenu (`GRUB_BTRFS_SUBMENUNAME`) so `@baseline` stands out
  among snap-pac's dated entries.
- **"Do not power off" splash** + **asymmetric-state detection/messaging** during/after
  the offline wipe.
- **Undo-last-restore affordance** — the pre-reset `@` is snapshotted but there's no
  button for it.
- **Fleet surface** — discovery, batch run, and a pass/fail/no-op verification ledger.

---

## 5. What must be true before this ships (gates)

Ordered by severity. The doc above is honest about all of these; here they are as a
checklist.

1. **⚠️ Asymmetric-reset hazard — FIX IMPLEMENTED, pending VM verification.** The
   marker now carries the rollback's `--print-number` snapshot id (armed *after* the
   rollback), and `reset_home.sh run` verifies the **running subvol** matches before
   deleting `@home` (skip + keep marker + warn on mismatch) — so a no-op boot fails
   **safe** without needing the GRUB leg fixed first. **Still TODO:** VM-verify that
   `btrfs subvolume show /` reports `.snapshots/N/snapshot` on a real rollback.
2. **⚠️ Close the GRUB `rootflags=subvol=@` leg (blocks *reliable* rollback).** Strip it,
   or route restore through the grub-btrfs "boot into @baseline" entry. VM-verify by
   grepping `/boot/grub/grub.cfg`. (The §1 guard makes a no-op boot non-destructive;
   this is what makes the rollback actually *succeed*.)
3. **Robustness — DONE.** `sync` before unmounts + idempotent `@home` re-create in
   `reset_home.sh`.
4. **Read-write snapshot boots:** reconcile `setup_snapshot_boot()` so the
   `grub-btrfs-overlayfs` hook is actually installed (today it's skipped under the
   `systemd` mkinitcpio hook → read-only snapshot boots).
5. **Compile:** pin zig 0.14 (shared blocker with the installer).
6. **Surface:** polkit `.policy` + the Settings page/Welcome card + GUI confirm dialog.
7. **Localization:** Khmer strings for every surface, incl. polkit and the confirm
   keyword.

**Until gates 1 + 2 land AND are VM-verified, `koompi-restore --full` must not run on
real hardware** — especially shared lab machines holding other students' data. The
reliable path meanwhile is the **GRUB `@baseline`** entry (system reset, keeps `/home`).
