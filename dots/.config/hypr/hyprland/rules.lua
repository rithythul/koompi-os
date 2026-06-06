-- ######## Window rules ########

-- Disable blur for xwayland context menus
hl.window_rule({match = {class = "^()$", title = "^()$" },                   no_blur = true })

-- Disable blur for every window
hl.window_rule({match = {class = ".*" }, no_blur = true })

-- Floating
hl.window_rule({match = {title = "^(Open File)(.*)$" },                      center = true})
hl.window_rule({match = {title = "^(Open File)(.*)$" },                      float = true})
hl.window_rule({match = {title = "^(Select a File)(.*)$" },                  center = true})
hl.window_rule({match = {title = "^(Select a File)(.*)$" },                  float = true})
hl.window_rule({match = {title = "^(Choose wallpaper)(.*)$" },               center = true})
hl.window_rule({match = {title = "^(Choose wallpaper)(.*)$" },               float = true})
hl.window_rule({match = {title = "^(Choose wallpaper)(.*)$" },               size = {"(monitor_w*0.60)", "(monitor_h*0.65)"} })
hl.window_rule({match = {title = "^(Open Folder)(.*)$" },                    center = true})
hl.window_rule({match = {title = "^(Open Folder)(.*)$" },                    float = true})
hl.window_rule({match = {title = "^(Save As)(.*)$" },                        center = true})
hl.window_rule({match = {title = "^(Save As)(.*)$" },                        float = true})
hl.window_rule({match = {title = "^(Library)(.*)$" },                        center = true})
hl.window_rule({match = {title = "^(Library)(.*)$" },                        float = true})
hl.window_rule({match = {title = "^(File Upload)(.*)$" },                    center = true})
hl.window_rule({match = {title = "^(File Upload)(.*)$" },                    float = true})
hl.window_rule({match = {title = "^(.*)(wants to save)$" },                  center = true})
hl.window_rule({match = {title = "^(.*)(wants to save)$" },                  float = true})
hl.window_rule({match = {title = "^(.*)(wants to open)$" },                  center = true})
hl.window_rule({match = {title = "^(.*)(wants to open)$" },                  float = true})
hl.window_rule({match = {class = "^(blueberry\\.py)$" },                     float = true})
hl.window_rule({match = {class = "^(guifetch)$" },                           float = true}) -- FlafyDev/guifetch
hl.window_rule({match = {class = "^(pavucontrol)$" },                        float = true})
hl.window_rule({match = {class = "^(pavucontrol)$" },                        size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })
hl.window_rule({match = {class = "^(pavucontrol)$" },                        center = true})
hl.window_rule({match = {class = "^(org.pulseaudio.pavucontrol)$" },         float = true})
hl.window_rule({match = {class = "^(org.pulseaudio.pavucontrol)$" },         size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })
hl.window_rule({match = {class = "^(org.pulseaudio.pavucontrol)$" },         center = true})
hl.window_rule({match = {class = "^(nm-connection-editor)$" },               float = true})
hl.window_rule({match = {class = "^(nm-connection-editor)$" },               size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })
hl.window_rule({match = {class = "^(nm-connection-editor)$" },               center = true})
hl.window_rule({match = {class = ".*plasmawindowed.*" },                     float = true})
hl.window_rule({match = {class = "kcm_.*" },                                  float = true})
hl.window_rule({match = {class = ".*bluedevilwizard" },                      float = true})
hl.window_rule({match = {title = ".*Welcome" },                              float = true})
hl.window_rule({match = {title = "^(KOOMPI Settings)$" },                    float = true})
hl.window_rule({match = {title = ".*Shell conflicts.*" },                    float = true})
hl.window_rule({match = {class = "org.freedesktop.impl.portal.desktop.kde" }, float = true})
hl.window_rule({match = {class = "org.freedesktop.impl.portal.desktop.kde" }, size = {"(monitor_w*0.60)", "(monitor_h*0.65)"} })
hl.window_rule({match = {class = "^(Zotero)$" },                             float = true})
hl.window_rule({match = {class = "^(Zotero)$" },                             size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })
-- Chat-widget scratchpads (toggled via scripts/toggle_app_scratchpad.sh). Each
-- app is pinned to its own special workspace by class and floated. Telegram and
-- WhatsApp are LEFT-DOCKED tall side panels (mirror of the SUPER+grave terminal,
-- which is right-docked): 0.5w wide (wider than the terminal's 0.42w) x FULL
-- height — they fill exactly the vertical band a maximized/tiled window gets, so a
-- floating widget reads as "same window, just half width". Anchored to the left
-- edge (x=16). See the terminal math for the full-height derivation. Discord is
-- still wide + centered. See keybinds App: *.
-- Telegram: SUPER + B  (left)
hl.window_rule({match = {class = "^(org.telegram.desktop)$" },               workspace = "special:telegram silent"})
hl.window_rule({match = {class = "^(org.telegram.desktop)$" },               float = true})
hl.window_rule({match = {class = "^(org.telegram.desktop)$" },               size = {"(monitor_w*0.5)", "(monitor_h-52)"} })
hl.window_rule({match = {class = "^(org.telegram.desktop)$" },               move = {"(16)", "(46)"} })
-- Discord: SUPER + SHIFT + D
hl.window_rule({match = {class = "^(discord)$" },                            workspace = "special:discord silent"})
hl.window_rule({match = {class = "^(discord)$" },                            float = true})
hl.window_rule({match = {class = "^(discord)$" },                            size = {"(monitor_w*0.7)", "(min(monitor_w*0.45, monitor_h*0.8))"} })
hl.window_rule({match = {class = "^(discord)$" },                            center = true})
-- WhatsApp Web: SUPER + SHIFT + W  (left; browser app-window, class contains web.whatsapp.com)
hl.window_rule({match = {class = ".*web\\.whatsapp\\.com.*" },               workspace = "special:whatsapp silent"})
hl.window_rule({match = {class = ".*web\\.whatsapp\\.com.*" },               float = true})
hl.window_rule({match = {class = ".*web\\.whatsapp\\.com.*" },               size = {"(monitor_w*0.5)", "(monitor_h-52)"} })
hl.window_rule({match = {class = ".*web\\.whatsapp\\.com.*" },               move = {"(16)", "(46)"} })
-- Quick-fire scratchpads sharing the chat-widget pattern. Same launch-or-toggle
-- script, same float/center/size convention; each uses a UNIQUE --class so it
-- never collides with the normal SUPER + Return terminal.
-- Terminal: SUPER + grave — RIGHT-docked panel (NOT centered like Discord),
-- since SUPER + T already opens a terminal in the workspace. Tall + narrow so it
-- reads as a side panel coming from the right. Telegram/WhatsApp above mirror it
-- on the LEFT (x=16) with the same size + vertical math.
hl.window_rule({match = {class = "^(term-scratch)$" },                       workspace = "special:term silent"})
hl.window_rule({match = {class = "^(term-scratch)$" },                       float = true})
-- FULL height — the panel fills exactly the band a maximized/tiled window gets, so
-- it lines up edge-for-edge with a normal window (just narrower). Measured on
-- eDP-1: reserved = [L,T,R,B] = [0,40,0,0] (the bar reserves 40px at the TOP, not
-- the bottom), gaps_out = 5, border = 1. A tiled window therefore sits at top
-- inset 46 (40 reserved + 5 gap + 1 border) and bottom inset 6 (5 gap + 1 border),
-- giving y = 46 and height = monitor_h-52 (40 + 6 + 6). x = monitor_w*0.58-16
-- right-docks the 0.42w panel (16px right gap). Fixed monitor_w/h math, NOT
-- window_w/window_h — those evaluate before the size rule and fall back to centered.
hl.window_rule({match = {class = "^(term-scratch)$" },                       size = {"(monitor_w*0.42)", "(monitor_h-52)"} })
hl.window_rule({match = {class = "^(term-scratch)$" },                       move = {"(monitor_w*0.58-16)", "(46)"} })
-- System monitor: SUPER + SHIFT + Escape (btop, falling back to htop/top)
hl.window_rule({match = {class = "^(sysmon-scratch)$" },                     workspace = "special:sysmon silent"})
hl.window_rule({match = {class = "^(sysmon-scratch)$" },                     float = true})
hl.window_rule({match = {class = "^(sysmon-scratch)$" },                     size = {"(monitor_w*0.7)", "(min(monitor_w*0.45, monitor_h*0.8))"} })
hl.window_rule({match = {class = "^(sysmon-scratch)$" },                     center = true})

-- Browser home workspace. A link clicked inside a chat widget spawns a real
-- browser window; with a special workspace focused, that window would be born on
-- the special workspace — tiled, hidden behind the floating widget. Pinning the
-- browser to ws 9 (non-silent, so it switches there) sends those link windows —
-- and every browser window — to your real browser instead. Matches the NORMAL
-- browser classes only, never the chrome --app widget class
-- (chrome-web.whatsapp.com__-Default), so the WhatsApp/Telegram/Discord widgets
-- stay on their special workspaces. See keybinds "App: * widget".
hl.window_rule({match = {class = "^(google-chrome|google-chrome-stable|chromium|brave-browser|firefox|zen|zen-browser|microsoft-edge|opera|librewolf)$" }, workspace = "9"})

-- Dolphin file manager: float-in-place for a quick file peek. Unlike the chat
-- widgets above it is NOT sent to a special workspace — it floats + centers +
-- sizes on the CURRENT workspace so SUPER + E still opens it normally (just
-- floating), and SUPER + Q dismisses it. Dolphin has no per-window class
-- override, so this applies to every Dolphin window. To make it a hide/restore
-- scratchpad instead, pin it to a special workspace like the chat widgets.
hl.window_rule({match = {class = "^(org.kde.dolphin)$" },                    float = true})
hl.window_rule({match = {class = "^(org.kde.dolphin)$" },                    size = {"(monitor_w*0.6)", "(min(monitor_w*0.4, monitor_h*0.75))"} })
hl.window_rule({match = {class = "^(org.kde.dolphin)$" },                    center = true})

-- Move
-- kde-material-you-colors spawns a window when changing dark/light theme. This is to make sure it doesn't interfere at all.
hl.window_rule({match = {class = "^(plasma-changeicons)$" }, float = true})
hl.window_rule({match = {class = "^(plasma-changeicons)$" }, no_initial_focus = true})
hl.window_rule({match = {class = "^(plasma-changeicons)$" }, move = {999999, 999999}})
-- stupid dolphin copy
hl.window_rule({match = {title = "^(Copying — Dolphin)$" }, move = {40, 80}})

-- Tiling
hl.window_rule({match = {class = "^dev\\.warp\\.Warp$" }, tile = true})

-- Picture-in-Picture
hl.window_rule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true})
hl.window_rule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, keep_aspect_ratio = true})
hl.window_rule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, move = {"(monitor_w*0.73)", "(monitor_h*0.72)"} })
hl.window_rule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, size = {"(monitor_w*0.25)", "(monitor_h*0.25)"} })
hl.window_rule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true})
hl.window_rule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, pin = true})

-- Screen sharing
hl.window_rule({match = {title = ".*is sharing (a window|your screen).*" }, float = true})
hl.window_rule({match = {title = ".*is sharing (a window|your screen).*" }, pin = true})
hl.window_rule({match = {title = ".*is sharing (a window|your screen).*" }, move = {"(monitor_w*.5-window_w*.5)", "(monitor_h-window_h-12)"} })

-- --- Tearing ---
hl.window_rule({match = {title = ".*\\.exe" }, immediate = true})
hl.window_rule({match = {title = ".*minecraft.*" }, immediate = true})
hl.window_rule({match = {class = "^(steam_app).*" }, immediate = true})

-- No shadow for tiled windows
hl.window_rule({match = {float = 0 }, no_shadow = true})

-- ######## Workspace rules ########
hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })
hl.workspace_rule({ workspace = "special:telegram", gaps_out = 30 })
hl.workspace_rule({ workspace = "special:discord", gaps_out = 30 })
hl.workspace_rule({ workspace = "special:whatsapp", gaps_out = 30 })
hl.workspace_rule({ workspace = "special:term", gaps_out = 30 })
hl.workspace_rule({ workspace = "special:sysmon", gaps_out = 30 })

-- ######## Layer rules ########
hl.layer_rule({ match = { namespace = ".*" }, xray = true})
hl.layer_rule({ match = { namespace = "walker" }, no_anim = true})
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true})
hl.layer_rule({ match = { namespace = "overview" }, no_anim = true})
hl.layer_rule({ match = { namespace = "anyrun" }, no_anim = true})
hl.layer_rule({ match = { namespace = "indicator.*" }, no_anim = true})
hl.layer_rule({ match = { namespace = "osk" }, no_anim = true})
hl.layer_rule({ match = { namespace = "hyprpicker" }, no_anim = true})

hl.layer_rule({ match = { namespace = "noanim" }, no_anim = true})
hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true})
hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, ignore_alpha = 0})
hl.layer_rule({ match = { namespace = "launcher" }, blur = true})
hl.layer_rule({ match = { namespace = "launcher" }, ignore_alpha = 0.5})
hl.layer_rule({ match = { namespace = "notifications" }, blur = true})
hl.layer_rule({ match = { namespace = "notifications" }, ignore_alpha = 0.69})
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true}) -- wlogout

-- ags
hl.layer_rule({ match = { namespace = "sideleft.*" }, animation = "slide left"})
hl.layer_rule({ match = { namespace = "sideright.*" }, animation = "slide right"})
hl.layer_rule({ match = { namespace = "session[0-9]*" }, blur = true})
hl.layer_rule({ match = { namespace = "bar[0-9]*" }, blur = true})
hl.layer_rule({ match = { namespace = "bar[0-9]*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "barcorner.*" }, blur = true})
hl.layer_rule({ match = { namespace = "barcorner.*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "dock[0-9]*" }, blur = true})
hl.layer_rule({ match = { namespace = "dock[0-9]*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "indicator.*" }, blur = true})
hl.layer_rule({ match = { namespace = "indicator.*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "overview[0-9]*" }, blur = true})
hl.layer_rule({ match = { namespace = "overview[0-9]*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "cheatsheet[0-9]*" }, blur = true})
hl.layer_rule({ match = { namespace = "cheatsheet[0-9]*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "sideright[0-9]*" }, blur = true})
hl.layer_rule({ match = { namespace = "sideright[0-9]*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "sideleft[0-9]*" }, blur = true})
hl.layer_rule({ match = { namespace = "sideleft[0-9]*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "indicator.*" }, blur = true})
hl.layer_rule({ match = { namespace = "indicator.*" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "osk[0-9]*" }, blur = true})
hl.layer_rule({ match = { namespace = "osk[0-9]*" }, ignore_alpha = 0.6})

-- Quickshell
-- Quickshell: koompi
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur_popups = true})
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true})
hl.layer_rule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.79})
hl.layer_rule({ match = { namespace = "quickshell:bar" }, animation = "slide"})
hl.layer_rule({ match = { namespace = "quickshell:actionCenter" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:cheatsheet" }, animation = "slide bottom"})
hl.layer_rule({ match = { namespace = "quickshell:dock" }, animation = "slide bottom"})
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" }, animation = "popin 120%"})
hl.layer_rule({ match = { namespace = "quickshell:lockWindowPusher" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:notificationPopup" }, animation = "fade"})
hl.layer_rule({ match = { namespace = "quickshell:overlay" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:overlay" }, ignore_alpha = 1})
hl.layer_rule({ match = { namespace = "quickshell:overview" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:osk" }, animation = "slide bottom"})
hl.layer_rule({ match = { namespace = "quickshell:polkit" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:popup" }, xray = false}) -- No weird color for bar tooltips (this in theory should suffice)
hl.layer_rule({ match = { namespace = "quickshell:popup" }, ignore_alpha = 1}) -- No weird color for bar tooltips (but somehow this is necessary)
hl.layer_rule({ match = { namespace = "quickshell:mediaControls" }, ignore_alpha = 1}) -- Same as above
hl.layer_rule({ match = { namespace = "quickshell:reloadPopup" }, animation = "slide"})
hl.layer_rule({ match = { namespace = "quickshell:regionSelector" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:screenshot" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:session" }, blur = true})
hl.layer_rule({ match = { namespace = "quickshell:session" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:session" }, ignore_alpha = 0})
hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" }, animation = "slide right"})
hl.layer_rule({ match = { namespace = "quickshell:sidebarLeft" }, animation = "slide left"})
hl.layer_rule({ match = { namespace = "quickshell:verticalBar" }, animation = "slide"})
hl.layer_rule({ match = { namespace = "quickshell:osk" }, order = -1})
-- Quickshell: waffles
hl.layer_rule({ match = { namespace = "quickshell:wallpaperSelector" }, animation = "slide top"})
hl.layer_rule({ match = { namespace = "quickshell:wNotificationCenter" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:wOnScreenDisplay" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:wStartMenu" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:wTaskView" }, ignore_alpha = 0})
hl.layer_rule({ match = { namespace = "quickshell:wTaskView" }, no_anim = true})

-- Launchers need to be FAST
hl.layer_rule({ match = { namespace = "gtk4-layer-shell" }, no_anim = true})
