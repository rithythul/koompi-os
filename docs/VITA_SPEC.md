# vita — CLI specification

Phase 1 specification. No implementation described here exists yet; see
`vita/` for the current empty-binary skeleton.

## 1. Toolchain

Zig 0.14.x exactly. Target `x86_64-linux-musl`, fully static
(`.linkage = .static`), built with `zig build -Doptimize=ReleaseSafe`.
External tools (`apt-get`, `dpkg-query`, `flatpak`, `snapper`, `distrobox`,
`btrfs`) are invoked via `std.process.Child`. No C bindings, no libapt —
vita never links against `libapt-pkg` and never parses dpkg's internal
database format directly; it shells out and parses stdout.

## 2. Resolution order (normative)

For `install`, `search`, and (implicitly) `update`, backends are tried in
this order:

1. **koompi-repo** — our signed apt repository (highest priority: pins,
   Khmer stack, our own tools, government middleware, curated extras).
2. **Debian stable + security** — the base apt sources. `debian-backports`
   is enabled by default only in the `dev` and `general` editions (see
   EDITIONS.md); other editions do not get backports unless their policy
   file opts in.
3. **Flathub (flatpak)** — default source for GUI applications not covered
   by 1 or 2.
4. **distrobox** — dev-edition-only fallback for the long tail. vita may
   *offer* installing into a distrobox container; it never does so
   silently or non-interactively (a `--yes` run without an explicit
   `--allow-distrobox` flag skips this tier and fails instead).

`remove` does not use this order — see §4.

## 3. CLI grammar

```
vita <command> [args...] [--yes] [--json]

vita install <pkg>...
vita remove <pkg>...
vita search <query>
vita update
vita rollback [<snapshot-number>]
vita info <pkg>
```

Global flags:

- `--yes` — non-interactive; skip confirmation prompts, fail closed
  (exit 4, see §7) on anything that would otherwise require a choice
  (e.g. multiple ambiguous matches, or a distrobox offer without
  `--allow-distrobox`).
- `--json` — machine-readable output on stdout (see §6); human-readable
  progress/errors still go to stderr. Required for Ansible-driven fleet
  management, per the fixed decisions.
- `--allow-distrobox` — the explicit opt-in `install` needs to reach the
  distrobox tier (§2). Ignored by every other command.

### 3.1 `vita install <pkg>...`

Resolves each package independently through the four-layer order (§2).
First layer with a match wins for that package; a run installing multiple
packages may pull each from a different backend. Each successful install
appends one entry to the ledger (§5).

### 3.2 `vita remove <pkg>...`

Does **not** re-run the install resolution order. Instead:

1. Check the ledger (§5) for a recorded backend for `<pkg>`. If present,
   remove via that backend.
2. If not in the ledger (e.g. pre-existing system package, or ledger
   loss), fall back to `dpkg-query -s <pkg>` — if installed as a native
   deb, remove via apt.
3. If not found via dpkg either, check `flatpak list` — if present, remove
   via flatpak.
4. If none match, exit 3 (not found, see §7).

### 3.3 `vita search <query>`

Queries all of koompi-repo, Debian, and Flathub (not distrobox — nothing
meaningful to search there) and returns a merged, backend-labeled result
list. Does not touch the ledger.

### 3.4 `vita update`

Snapshot-orchestrated full-system update. See §8 for the exact sequence.

### 3.5 `vita rollback [<snapshot-number>]`

Invokes `snapper rollback [<snapshot-number>]` (defaults to snapper's own
"most recent pre snapshot" behavior when omitted), then prompts for a
reboot (skipped under `--yes`, which prints the required manual reboot
instruction instead — vita never reboots the machine itself).

Known limitation, stated to the user on every invocation: `@home` and
`@var_log` are not part of the rollback (see ARCHITECTURE.md §2) — files
created or changed there since the snapshot are unaffected either way.

### 3.6 `vita info <pkg>`

Shows: installed? (and via which backend, per the ledger or the §3.2
fallback chain), available versions per backend, and which backend
`install` would choose today.

## 4. Ledger

Path: `/var/lib/vita/state.json`. Records the backend used for every
install so `remove` and `info` don't have to re-derive it.

```json
{
  "version": 1,
  "packages": {
    "<pkg-name>": {
      "backend": "koompi-repo | debian | flatpak | distrobox",
      "version": "<version string as reported by the backend>",
      "installed_at": "<RFC 3339 timestamp>",
      "requested": true
    }
  }
}
```

- `requested: true` marks packages the user explicitly asked for (vs. a
  dependency pulled in transitively by apt/flatpak) — reserved for a
  future `vita autoremove`, not used by any Phase 1/2 command yet, but
  part of the schema from the start so it doesn't require a migration.
- Written atomically: serialize to `state.json.tmp`, `fsync`, `rename` over
  `state.json`. A crash mid-write never corrupts the ledger.
- Missing or corrupt ledger is not fatal: `install` recreates it from
  scratch; `remove`/`info` fall back to the dpkg/flatpak queries in §3.2.

## 5. Snapshot orchestration (`vita update`)

1. `snapper -c root create --type pre --print-number --description "vita
   update"` → capture pre-update snapshot number `N`.
2. `grub-editenv /boot/grub/grubenv set koompi_pending_snapshot=N`
3. `grub-editenv /boot/grub/grubenv set koompi_boot_pending=1`
4. `apt-get update && apt-get full-upgrade -y`
5. `flatpak update -y`
6. `snapper -c root create --type post --pre-number N --print-number
   --description "vita update"` → capture post-update snapshot number
   (reported as `post_snapshot` in `--json` output, §6).

If step 4 or 5 fails, vita stops, leaves `koompi_boot_pending=1` set (the
boot-success fallback in ARCHITECTURE.md §5 is the safety net for a
currently-running, not-yet-rebooted system that's left in a bad state —
vita itself does not attempt to auto-rollback a failed update in place),
and exits non-zero with the failing step named. The flag is only cleared
by `koompi-boot-success.service` after a subsequent successful boot to
`graphical.target`, not by vita.

## 6. `--json` output shapes

One JSON object per command on stdout, always including `"ok": bool` and
`"exit_code": int` mirroring the process exit code:

```json
// vita install
{"ok": true, "exit_code": 0, "installed": [
  {"package": "khmer-fonts", "backend": "koompi-repo", "version": "1.2-1"}
]}

// vita remove
{"ok": true, "exit_code": 0, "removed": ["khmer-fonts"]}

// vita search
{"ok": true, "exit_code": 0, "results": [
  {"package": "gimp", "backend": "flatpak", "version": "2.10.36", "installed": false}
]}

// vita update
{"ok": true, "exit_code": 0,
 "pre_snapshot": 42, "post_snapshot": 43,
 "apt_upgraded": 12, "flatpak_upgraded": 3}

// vita rollback
{"ok": true, "exit_code": 0, "rolled_back_to": 42, "reboot_required": true}

// vita info
{"ok": true, "exit_code": 0, "package": "vita",
 "installed": true, "backend": "koompi-repo", "version": "0.1.0-1",
 "available": {"koompi-repo": "0.1.0-1", "debian": null, "flatpak": null}}

// any failure
{"ok": false, "exit_code": 3, "error": "package not found: foo"}
```

## 7. Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Generic/unexpected error (I/O, subprocess spawn failure, malformed backend output) |
| 2 | Invalid usage (bad flags/args) |
| 3 | Package not found (install/remove/info target doesn't resolve in any backend) |
| 4 | Confirmation required but `--yes` given without the specific opt-in needed (e.g. distrobox install without `--allow-distrobox`) |
| 5 | Backend subprocess failed (apt/dpkg/flatpak/snapper/distrobox/btrfs exited non-zero) — the failing backend and its exit status are included in `--json` error output and printed to stderr otherwise |
| 6 | Snapshot operation failed (`vita update`/`vita rollback` snapper step) — distinct from 5 so tooling can treat rollback-path failures as higher severity |
