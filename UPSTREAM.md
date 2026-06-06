# Upstream & attribution

KOOMPI OS's desktop shell is **not original work**. It is a downstream fork of
**[illogical-impulse]** — the Hyprland dotfiles by **end-4**
(<https://github.com/end-4/dots-hyprland>). The bar, sidebars, notifications,
OSD, settings, the Material You theming engine, and the QML service layer are
all end-4's design and code. We are deeply grateful for it.

[illogical-impulse]: https://github.com/end-4/dots-hyprland

## License

end-4/dots-hyprland is **GPL-3.0**, and so is this repository (`LICENSE`). A
derivative of GPL-3.0 code stays GPL-3.0 — that is by design, not an obstacle.
Nothing in KOOMPI's fork relicenses any inherited file.

If you copy code from a *third* repository into this one, follow the rule in
[`licenses/README.md`](licenses/README.md): add a license notice to the file and
drop a copy of the license under `licenses/`.

## How the fork is structured

This is a **real git fork with full shared history**, not a content copy:

- We share end-4's entire commit history (~6300 commits, including their merged PRs).
- Fork point: `614f02e6` (end-4 `main`, 2026-06-03).
- The directory/namespace rename `ii → koompi` (config dir, `modules/`, the
  `~/.config/illogical-impulse` state dir, keyring id, metapackages) was done as
  **git renames (R100)**, so git tracks them across merges — end-4's future edits
  to `modules/ii/...` land on our `modules/koompi/...` files automatically.
- The only submodule is `modules/common/widgets/shapes`
  (end-4/rounded-polygon-qmljs).

## What KOOMPI actually authored

Our divergence is small and deliberate — keep it that way:

- The `hl.*` **Hyprland Lua config bridge** (`dots/.config/hypr/`) — KOOMPI's own
  config layer; the inherited shell's dispatch calls were ported onto it.
- **OS integration**: KOOMPI detection in `services/SystemInfo.qml`, the
  user-actions loader in `services/LauncherSearch.qml`, config-path rewrites.
- **Branding**: wallpapers, brand-green accent, KOOMPI bar-layout tweaks, the
  KOOMPI default theme, this attribution.
- A handful of added AI providers (DeepSeek, GLM, MiniMax, Kimi).
- The **Zig installer** (`installer/`) and the **Arch packaging tree**
  (`sdata/dist-arch/`) are KOOMPI-original, not from end-4.

## Tracking upstream

end-4 actively maintains the shell (Wayland/Quickshell breakage, fixes). Staying
a trackable fork means we get those for free. To pull upstream:

```sh
git remote add end-4 https://github.com/end-4/dots-hyprland.git   # once
git fetch end-4
git log --oneline 614f02e6..end-4/main      # review what's new
git merge end-4/main                         # renames are auto-followed
```

To keep merges cheap: **make KOOMPI changes on KOOMPI-owned surfaces** (the Lua
bridge, branding, installer, packaging) and touch end-4-owned QML as little as
possible. Every edit to an inherited file is a future merge conflict.

## Supporting end-4

If KOOMPI's shell is useful to you, the upstream project deserves the credit and
the support: <https://github.com/sponsors/end-4>.
