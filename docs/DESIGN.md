# Design

Visual system of the KOOMPI OS brainstorm page (`docs/brainstorm/`), mirroring the intended Quickshell shell design.

## Theme

Page chrome is light; desktop sims support `theme-light` (default) and `theme-dark` via a toggle. Semantic color meaning is identical in both.

## Color palette

Tokens defined in `css/base.css`:

- `--bg` #070B13 (sim dark desktop), page background near-white
- `--surface` / `--surface2` / `--surface3` / `--surface4`: layered panels
- `--accent` #6366F1 indigo: AI / intelligence
- `--cyan` #22D3EE: data streams
- `--emerald` #10B981: private / safe / local
- `--amber` #F59E0B: consent needed
- `--red` #EF4444: danger / violation
- Each accent has a `-glow` translucent variant for tinted backgrounds
- `--text`, `--text-muted`, `--text-subtle` for three-step text hierarchy

Color is semantic first: never use an accent decoratively where its state meaning could mislead.

## Typography

- `--font-ui`: UI sans (system stack), `--font-mono`: JetBrains Mono for data/code/timestamps
- Display 56px / heading 22px / title 15px / body 13px / label 11px / mono 12px
- Mono is used for anything machine-true: times, sizes, hashes, file paths

## Shape & elevation

- Radii: `--radius-sm` < `--radius` < `--radius-lg` < `--radius-xl`; pills use 20px+
- Elevation via soft layered shadows, not borders alone; 1px `--border`/`--border2` hairlines
- Dark sim surfaces use translucent fills + `backdrop-filter` blur for shell glass

## Components

- Bar pills (privacy pill, AI pill, media pill), workspace dots, tray icons (`bar.css`)
- Sidebar panels, quick-settings tiles, notification items (`widgets.css`)
- Desktop sim: wallpaper layer, window chrome (tiled/floating), sidebars, popups, OSD, overview, launcher (`desktop-sim.css`)
- Brainstorm sections: `.section-header` + `.tag`, `.desc`, `.callout-group`, `.tool-code`, `.state-chip`, `.badge`

## Motion

- 150–280ms transitions, ease-out (quart/quint/expo family); no bounce, no elastic
- Panels slide/scale from their anchor; OSD pills fade+rise; overview tiles stagger in
- AI "thinking" is non-directional (breathing); loading is directional (bars)
- All motion gated by `prefers-reduced-motion`
