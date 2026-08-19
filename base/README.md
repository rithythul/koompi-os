# base/

The shared foundation every edition builds on — see docs/EDITIONS.md §2
for the exact composition order.

- `packages.list` — common package list, installed for every edition, no
  exceptions.
- `overlay/` — shared filesystem tree merged onto the target root before
  any edition-specific overlay (branding, default configs, the
  `koompi-edition` marker file each edition's own overlay overrides).
- `branding/` — placeholder for shared branding assets (wallpapers, logos,
  Plasma theme defaults). Empty until KOOMPI branding assets exist.
