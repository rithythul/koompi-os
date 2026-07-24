# KOOMPI Desktop Experience - dependencies

What the desktop needs to run, what is optional, and which packages provide it.
The package layer lives in `sdata/dist-arch/`; installing `koompi-desktop-experience` pulls everything in the required section.

## Required

The core session, in dependency order:

| Package | Provides |
|---|---|
| `koompi-hyprland` | Hyprland compositor, hyprsunset, wl-clipboard |
| `koompi-quickshell-git` | the `qs` shell runtime (Qt6), kdialog |
| `koompi-shell` | the shell tree in `/etc/xdg/quickshell/koompi`, the `koompi-*` tools in `/usr/bin` |
| `koompi-session` | `koompi-session` launcher, SDDM session entry, portal config |
| `koompi-hyprland-config` | the full dotfiles seed in `/etc/skel` for new users |
| `koompi-base` | everything below |

`koompi-base` fans out to the domain metas:

| Meta | Pulls in | Why |
|---|---|---|
| `koompi-basic` | coreutils, curl, wget, jq, rsync, ripgrep, cliphist, bc, go-yq, xdg-user-dirs, fprintd, cmake | shell scripts and clipboard history |
| `koompi-audio` | pipewire-pulse, wireplumber, playerctl, pavucontrol-qt, cava | sound and media controls |
| `koompi-backlight` | brightnessctl, ddcutil, geoclue | brightness and night light |
| `koompi-fonts-themes` | matugen, adw-gtk-theme, breeze-plus, darkly, kitty, fish, starship, the KOOMPI font set | theming pipeline and default terminal |
| `koompi-kde` | dolphin, kdialog, gnome-keyring, networkmanager | file manager, dialogs, Secret Service, networking |
| `koompi-portal` | xdg-desktop-portal + gtk + hyprland backends | file chooser and screenshare |
| `koompi-screencapture` | hyprshot, slurp, swappy, wf-recorder, tesseract | screenshots, recording, OCR |
| `koompi-toolkit` | upower, ydotool, wtype | power reporting and input synthesis |
| `koompi-widgets` | fuzzel, hypridle, hyprlock, hyprpicker, wlogout, translate-shell, libqalculate | launcher, lock, idle, widget helpers |

## Optional

Feature packages the desktop uses when present and degrades without:

- `matugen` is technically in the required set via `koompi-fonts-themes`, but the desktop survives its absence: `koompi-theme` degrades to a warning and keeps the current colors.
- `koompi-microtex-git` renders LaTeX in the shell; without it math rendering is off.
- `easyeffects` audio effects, `wayvnc` remote desktop, `fprintd` fingerprint login.
- `plasma-browser-integration` media control from the browser.

## GTK/Qt compatibility (outputs, not infrastructure)

The desktop is KDE-free and GNOME-free as infrastructure; these packages exist so apps look and behave right:

- GTK apps: gtk3/gtk4, libadwaita, adw-gtk-theme (theme applied via gsettings/dconf), xdg-desktop-portal-gtk (file chooser), appmenu-gtk-module (global menu).
- Qt apps: qt6ct (`QT_QPA_PLATFORMTHEME=qt6ct`), the Darkly style, breeze-plus icons; matugen renders the palette, `switchwall.sh` writes `qt6ct.conf` and `kdeglobals`.
- Secret Service: `gnome-keyring` stays the provider; it is PAM-integrated with the lock screen and holds existing secrets, and quickshell links qtkeychain against it.

GTK and Qt settings files are generated compatibility outputs.
`~/.config/koompi/config.json` is the only user-owned source of truth.

## Watch items

- No polkit authentication agent is installed since the M5 plasma removal; `koompi-useradd` (pkexec) needs one for graphical auth prompts. If privileged GUI actions fail, add a lean agent (for example `hyprpolkitagent`) rather than resurrecting polkit-kde-agent.
- `kdialog` is a hard dependency of `koompi-quickshell-git` upstream; dropping it fully is a packaging change there, not here.
