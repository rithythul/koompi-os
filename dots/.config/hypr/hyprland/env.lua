local home_dir = os.getenv("HOME")

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Applications
local xdg_data_dirs_old = os.getenv("XDG_DATA_DIRS") or ""
hl.env("XDG_DATA_DIRS", home_dir .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:" .. xdg_data_dirs_old)

-- Global menu: GTK apps export their menubar over DBus instead of drawing it
hl.env("GTK_MODULES", "appmenu-gtk-module")

-- KDE's crash handler assumes a Plasma session; outside one it can only park
-- a dead "closed unexpectedly" icon in the tray. Let crashes just exit.
hl.env("KDE_DEBUG", "1")

-- Themes
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- qt6ct, not kde: Qt apps read the matugen-rendered qt6ct palette instead of
-- loading plasma-integration (M5/M7 Qt unwind). KDE apps still read kdeglobals,
-- which switchwall.sh merges the same colors into.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Virtual environment
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", home_dir .. "/.local/state/quickshell/.venv")
