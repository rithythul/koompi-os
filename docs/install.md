# Installing the KOOMPI desktop

This document covers installing the desktop **onto an existing Linux install**.
If you are building the KOOMPI OS image itself, you want [`os-build.md`](os-build.md) instead - that path packages the same `dots/` tree into `/etc/skel` and never runs `./setup`.

## Quick start

```sh
curl -fsSL https://raw.githubusercontent.com/rithythul/koompi-os/main/install.sh | bash
```

Or, to read the thing before running it:

```sh
git clone --recursive https://github.com/rithythul/koompi-os.git
cd koompi-os
./setup install
```

`--recursive` matters: the shell's rounded-polygon widgets are a submodule and the QML fails to load without them.
If you already cloned without it, `./setup` runs `git submodule update --init --recursive` for you.

## The one-liner

`install.sh` is deliberately thin.
It installs `git` if the machine has none, clones the repository, and executes `./setup install`.
Everything of consequence lives in `./setup`, which is a file you can review after the clone rather than a stream you have already piped into a shell.

Three environment variables override it, mostly for testing:

| Variable | Default | Purpose |
|---|---|---|
| `KOOMPI_REPO` | `https://github.com/rithythul/koompi-os.git` | Clone from a fork or a local mirror |
| `KOOMPI_REF` | `main` | Install from a branch or tag |
| `KOOMPI_DEST` | `~/.local/share/koompi-os` | Where the checkout lives |

Arguments after `-s --` reach `./setup install` unchanged:

```sh
curl -fsSL .../install.sh | bash -s -- --dry-run
curl -fsSL .../install.sh | bash -s -- --no-apps
```

Two details are worth knowing.

When the destination already holds a checkout it is updated with `fetch` and `reset --hard`, not `pull`.
A merge conflict there would strand you inside a bootstrap script with no good way out, and nothing you edit belongs in that directory anyway: your changes live in `~/.config`, which `./setup` never clobbers.

`curl | bash` leaves stdin attached to the pipe carrying the script, so `./setup` would read every confirmation prompt from a closed stream and take the default for all of them.
`install.sh` reconnects stdin to `/dev/tty` before handing over, which is what makes the prompts - including the one guarding the application set - actually work.

## The four steps

`./setup install` runs four steps in order. Each can be skipped or run alone.

### 1. Dependencies

Routes to `sdata/dist-<group>/install-deps.sh` based on `/etc/os-release`:

| `ID` / `ID_LIKE` | Recipe |
|---|---|
| `arch`, `archlinux`, `koompi` | `sdata/dist-arch` |
| `fedora`, `rhel`, `centos` | `sdata/dist-fedora` |
| `debian`, `ubuntu` | `sdata/dist-debian` |

A distro matched through `ID_LIKE` rather than `ID` gets a warning: the recipe will probably work, but package names drift between derivatives.

An unrecognised distro stops this step rather than guessing a package manager.
Use `--no-deps` and work from [`dependencies.md`](dependencies.md).

### 2. Applications

Routes to `sdata/dist-<group>/install-apps.sh` by the same table as the dependency step.

This step is separate from the one above because the two answer different questions.
The dependency step installs what the session cannot start without; remove any of it and the desktop breaks.
This step installs the programs KOOMPI has an *opinion* about; remove any of it and you have simply chosen a different program.

It is several gigabytes, two proprietary browsers and an office suite, so it prompts before doing anything even when the rest of the install did not.
`--no-apps` skips it outright, and `--only-apps` adds it to a desktop installed earlier without it.

`dots/.config/hypr/hyprland/variables.lua` dispatches each role through `launch_first_available.sh`, which walks a preference list and runs the first program on `PATH`.
What this step installs is exactly what makes those lists resolve the way KOOMPI intends:

| Role | Installed | Notes |
|---|---|---|
| Terminal | `wezterm`, `konsole` | WezTerm is the default. Konsole is what KDE apps get when they ask KIO for a terminal - Dolphin's F4 does not read `variables.lua`. |
| File manager | `ark`, `kio-admin`, `kdegraphics-thumbnailers`, `ffmpegthumbs` | Dolphin itself is a dependency, from `koompi-kde`. These are what turn it from a file list into a file manager. |
| Browser | `google-chrome`, `brave` | `rules.lua` sends either to workspace 9 while leaving `chrome --app` widget windows where they are. |
| Editor | `zed` | Its binary is `zeditor`, which is the name `variables.lua` and `./setup doctor` look for. |
| Documents | `okular`, `loupe`, `mpv` | Okular is also Quick Look's fallback for PDFs. |
| Office | `libreoffice` | `variables.lua` prefers WPS then OnlyOffice then LibreOffice. Only LibreOffice is packaged on every supported distro, so it is the one the installer guarantees; install either of the others and it wins. |
| System | `btop`, `gnome-system-monitor`, `nm-connection-editor` | The sysmon scratchpad runs btop; the network widget's advanced settings open `nm-connection-editor`. |
| Phone | `kdeconnect` | The shell's KDE Connect integration does nothing without the daemon. |

Kitty is **not** in this list, despite being the KOOMPI terminal in several places.
It is a `koompi-fonts-themes` dependency because the shell hardcodes it rather than dispatching: the `Super+grave` scratchpad, `launch_sysmon.sh` and the `Config.qml` terminal actions all name it directly, and `applycolor.sh` writes it a generated theme.
WezTerm is what the terminal keybind opens; kitty is what the shell uses internally.

Per-distro sourcing:

- **Arch** builds one metapackage, `sdata/dist-arch/koompi-apps`. Chrome and Brave come from the AUR through yay. `mpvpaper` is offered separately at the end - `switchwall.sh` needs it to run a video as the wallpaper, and it is the only shipped feature with no packaged home on any distro.
- **Fedora** reads `packages-apps.list` and enables two vendor repositories first: Google's, through Fedora's own `fedora-workstation-repositories`, and Brave's, imported by key.
- **Debian/Ubuntu** reads `packages-apps.list` and adds the same two vendors as `signed-by` sources, each pinned to its own keyring so neither key can sign for anything else in the system's sources. Chrome is amd64 and arm64 only, Brave amd64 only; on any other architecture the repository is skipped rather than added broken.

Zed is packaged only on Arch.
On Fedora, Debian and Ubuntu the recipe runs Zed's own installer, which puts it in `~/.local` - the one per-user thing this step does, and why it is not in the package lists.
If it fails, the editor keybind falls through to the next entry rather than the install stopping.

Everything else is installed with `--skip-unavailable` on Fedora and behind an `apt-cache` check on Debian, so a name one release has dropped costs you that program rather than the step.
`./setup doctor` reports which of the set actually landed.

### 3. Setups

The parts that are neither a package nor a file:

- **Python venv** at `~/.local/state/quickshell/.venv`, built with `uv` from `sdata/uv/requirements.txt`.
  The shell's colour generation, thumbnailing and image analysis run out of it.
  It is created with `--system-site-packages` so PyGObject and OpenCV come from the distro packages instead of being compiled here.
- **global-menu daemon**, a Zig program in the shell tree.
  `zig-out/` is gitignored, so a fresh clone has no binary and the global menu silently stays empty until this builds it.
- **Groups**: `video`, `input`, and `i2c` where it exists. `i2c` is what lets `ddcutil` set the brightness of an external monitor.
- **Kernel modules**: `uinput` (ydotool, on-screen keyboard) and `i2c-dev`.
- **Services**: `ydotool` as a user service, `bluetooth` as a system one.

Group membership only takes effect at your next login.
Until then `ddcutil` and `ydotool` will not work, and that is expected rather than a failed install.

### 4. Files

`dots/` is copied into `$HOME` in three modes:

| Mode | Paths | Behaviour |
|---|---|---|
| sync | `.config/hypr/hyprland`, `.config/hypr/hyprlock`, `.config/quickshell/koompi`, `.config/quickshell/koompi-quicklook` | `rsync --delete`. These trees belong to the repo, so a file deleted upstream is deleted here too. |
| merge | the rest of `.config`, `.local/share`, `.local/bin` | Copied in, nothing deleted. Shared with whatever else you have. |
| keep | `.config/hypr/custom/*.lua` | Written only if absent. Your overrides survive every update. |

Before writing anything it copies every file it is about to overwrite into `~/.koompi-dots-backup/<timestamp>/`.
`--no-backup` skips that; there is no good reason to use it.

Everything written is appended to `~/.local/state/koompi/installed-files`.

The shipped `koompi.desktop` session entry points at `/usr/bin/koompi-session`, which is where the Arch package puts it.
On a user-level install that file does not exist, so the `Exec=` line is rewritten to `~/.local/bin/koompi-session`.
If a system `koompi-session` *is* present it is left pointing there.

## Updating

```sh
git pull
./setup install --only-files
```

That refreshes the config without touching packages.
If the update added a dependency, run the full `./setup install`.

Re-running the one-liner does the same thing: it fetches, hard-resets the checkout, and runs `./setup install` again.
Every step is idempotent, so this is the supported way to update an install that started as `curl | bash`.

If you skipped the applications the first time and changed your mind:

```sh
./setup install --only-apps
```

## Uninstalling

```sh
./setup uninstall
```

Removes the paths in the manifest and prunes the directories that are then empty.
`rmdir`, never `rm -r`, so a directory you put your own files in stays.

It does **not** remove packages.
The installer cannot tell which of them you also wanted for something else, and removing a shared library out from under a running session is not a recoverable mistake.
[`dependencies.md`](dependencies.md) has the list if you want to do it by hand.

The applications are easier to undo than the dependencies, because nothing depends on them.
On Arch, `sudo pacman -Rs koompi-apps` takes the whole set with it.
The two browser repositories the Fedora and Debian recipes added are one file each, in `/etc/yum.repos.d` and `/etc/apt/sources.list.d`.

Your pre-install config stays in `~/.koompi-dots-backup/`.

## Per-distro notes

### Arch and derivatives

The recipe builds the `koompi-*` dependency metapackages from `sdata/dist-arch/*/PKGBUILD` and installs `yay` first if it is missing, since several dependencies come from the AUR.

It installs the dependency metas, and `koompi-apps` if you accept the application step.
`koompi-hyprland-config`, `koompi-shell`, `koompi-session` and the `koompi-desktop-*` edition packages are skipped on purpose: those ship the desktop itself into `/etc/skel` and `/etc/xdg`, and `./setup` already puts that content in `$HOME`.
Installing both leaves two copies of the shell competing for the same paths.

`koompi-apps` is the exception that proves the rule - it contains no configuration at all, only `depends`, so the OS-image path can pull the same application set through `koompi-desktop-experience` without either copy conflicting.

Superseded `illogical-impulse-*` and `*-git` packages from before the KOOMPI rename are removed first, because the `-git` builds shadow the repo versions the metas now pull in.

### Fedora

Fedora 43 and later. Nothing is built from source: Fedora itself carries `quickshell` and `matugen`, and four COPRs cover the Hyprland stack, the KOOMPI fonts, Darkly and starship.

`quickshell` is pinned with `dnf versionlock` because it links private Qt APIs and crashes on a Qt ABI bump.
Unpin it before a Qt upgrade, then re-run `./setup install --only-deps` to re-pin.

Details, including which COPR carries what and how to get quickshell 0.3.x: [`../sdata/dist-fedora/README.md`](../sdata/dist-fedora/README.md).

### Debian and Ubuntu

| Release | Status |
|---|---|
| Debian 13 (trixie) | Supported. The recipe enables `trixie-backports`, which is where the entire Hyprland stack lives - `trixie` main has none of it. |
| Debian 14 (forky) / sid | Supported, no extra repository. |
| Ubuntu 26.04 (resolute) | Supported. Needs universe, multiverse and `ppa:avengemedia/danklinux`. |
| Ubuntu 25.10 | Refused. Hyprland 0.41 and EOL. |
| Ubuntu 24.04 | Refused. No Hyprland, and Qt 6.4.2 against quickshell's 6.6 floor. |
| Mint, Pop!\_OS and other derivatives | Judged on `apt-cache policy hyprland`, not on the release number. |

The refusals are deliberate.
On those releases the compositor either does not exist or is old enough that this config will not load, and an installer that "succeeds" into an unbootable session is worse than one that stops and says why.

Some things have no package on any Debian or Ubuntu release and are fetched by `sdata/lib/from-source.sh`: the six KOOMPI fonts, `uv`, `adw-gtk3`, `bibata-cursor-theme`, `hyprshot`, `matugen` on Debian, and `hyprsunset` on Ubuntu (a source build).
`darkly`, `breeze-plus`, `songrec` and `microtex` are named and skipped rather than built.

The font drop is not cosmetic.
Without Material Symbols every icon in the bar renders as a tofu box.

Details, including the `yq` trap and how releases are gated: [`../sdata/dist-debian/README.md`](../sdata/dist-debian/README.md).

### Anything else

`./setup install --no-deps` installs the config and runs the setups step, leaving packages to you.
[`dependencies.md`](dependencies.md) is the list.
`./setup doctor` afterwards tells you what is still missing.

## Troubleshooting

Start with:

```sh
./setup doctor
```

It reports the detected distro, which required and optional commands are on `PATH`, and whether the venv, shell tree, manifest and global-menu binary exist.

| Symptom | Cause |
|---|---|
| Session missing from the login screen | The display manager only rescans `~/.local/share/wayland-sessions` on restart. Restart it, or log out and back in. |
| Wallpaper does not change the colour scheme | No `matugen`, or no venv. `./setup doctor` will say which. |
| Global menu is always empty | `global-menu-daemon` was not built. Install `zig` and run `./setup install --only-setups`. |
| External monitor brightness does nothing | You are not in `i2c` yet. Log out and back in. |
| On-screen keyboard types nothing | `uinput` is not loaded, or you are not in `input` yet. |
