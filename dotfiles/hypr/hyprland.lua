-- ~/.config/hypr/hyprland.lua

-- ==========================================
-- VARIABLES
-- ==========================================
local terminal = "kitty"
local fileManager = "thunar"
-- Escaping the quotes properly for the bash command
local menu = "bash -c 'quickshell ipc call launcher-$(hyprctl activeworkspace -j | jq -r \".monitor\") toggle'"
local mainMod = "SUPER"

-- ==========================================
-- MONITORS
-- ==========================================
-- Monitor 2 (Left, 1080p LG MP59G)
hl.monitor({
    output = "DP-2",
    mode = "1920x1080@75",
    position = "0x0",
    scale = 1
})

-- Monitor 1 (Right, 1440p LG UltraGear)
hl.monitor({
    output = "DP-1",
    mode = "2560x1440@165",
    position = "1920x0",
    scale = 1
})

-- ==========================================
-- ENVIRONMENT VARIABLES
-- ==========================================
hl.env("GTK_THEME", "Dracula")
hl.env("COLOR_SCHEME", "prefer-dark")
hl.env("QT_SCALE_FACTOR_ROUNDING_POLICY", "Round")

-- Qt Theme Overrides
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "Dracula")

-- ==========================================
-- AUTOSTART
-- ==========================================
hl.on("hyprland.start", function()
    hl.exec_cmd("kdeconnect-indicator &")
    hl.exec_cmd("quickshell &")
    hl.exec_cmd("[workspace 1 silent] zen &")
    hl.exec_cmd("[workspace 3 silent] antigravity &")
    hl.exec_cmd("discord --minimized &")

    hl.exec_cmd("~/nixos-config/scripts/WallpaperSetup/init-hyprpaper.sh &")
    hl.exec_cmd("~/nixos-config/scripts/KeychronMouse/mouse-battery &")
    
    -- GTK, KDE and Cursor Theming
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Dracula'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE")
    
    -- Cliphist Daemons
    hl.exec_cmd("wl-paste --type text --watch cliphist store &")
    hl.exec_cmd("wl-paste --type image --watch cliphist store &")
end)

-- ==========================================
-- CORE CONFIGURATION
-- ==========================================
hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 5,
        border_size = 3,
        ["col.active_border"] = {
            colors = { "rgba(cba6f7ee)", "rgba(89b4faee)" },
            angle = 45
        },
        ["col.inactive_border"] = "rgba(595959aa)",
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle"
    },
    decoration = {
        rounding = 12,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)"
        },
        blur = {
            enabled = true,
            size = 1,
            passes = 5,
            vibrancy = 0.2
        }
    },
    animations = {
        enabled = true
    },
    dwindle = {
        preserve_split = true
    },
    master = {
        new_status = "master"
    },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        focus_on_activate = true
    },
    input = {
        kb_layout = "hu",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        follow_mouse_threshold = 0,
        focus_on_close = 2,
        sensitivity = 0,
        scroll_method = "on_button_down",
        scroll_button = 274,
        touchpad = {
            natural_scroll = false
        }
    }
})

-- ==========================================
-- GESTURES
-- ==========================================
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- ==========================================
-- LAYER RULES
-- ==========================================
hl.layer_rule({
    match = { namespace = "quickshell" },
    blur = true,
    ignore_alpha = 0.8
})

-- ==========================================
-- WINDOW RULES
-- ==========================================
hl.window_rule({
    match = { class = "^(discord)$" },
    workspace = "2 silent"
})
-- ==========================================
-- ANIMATIONS (Lua API)
-- ==========================================
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- Workspaces configuration (linear curve so it doesn't drag at the end)
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "linear", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "linear", style = "slide" })

-- ==========================================
-- KEYBINDINGS
-- ==========================================

-- Core Execution Binds
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("bash -c 'pkill quickshell; quickshell'"))
hl.bind(mainMod .. " + K", hl.dsp.window.close()) -- Replaces killactive
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("[workspace 2] discord"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
-- Core Window Dispatchers
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("pkill wlsunset || wlsunset -l 47.5 -L 19.0 -t 3500 -T 6500"))

-- Move Focus (Now uses the hl.dsp.focus module)
hl.bind(mainMod .. " + left", hl.dsp.focus({direction = "left"}))
hl.bind(mainMod .. " + right", hl.dsp.focus({direction = "right"}))
hl.bind(mainMod .. " + up", hl.dsp.focus({direction = "up"}))
hl.bind(mainMod .. " + down", hl.dsp.focus({direction = "down"}))

-- Switch Workspaces & Move Windows to Workspaces
for i = 1, 9 do
    -- Switch workspace
    hl.bind(mainMod .. " + " .. tostring(i), hl.dsp.focus({ workspace = i }))
    -- Move active window to workspace
    hl.bind(mainMod .. " + SHIFT + " .. tostring(i), hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "empty" }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "empty" }))

-- Scroll through existing workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "-1" }))

-- Move between existing workspaces on the active monitor
hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("XF86Tools", hl.dsp.focus({ workspace = "m-1" }))

-- Mouse Binds (Now handled via window.move and window.resize)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse:274", hl.dsp.window.close(), { mouse = true })
-- Multimedia & Brightness (Includes repeating and locked flags)
local media_opts = { repeating = true, locked = true }

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), media_opts)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), media_opts)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), media_opts)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), media_opts)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), media_opts)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), media_opts)

-- Playerctl
local locked_opts = { locked = true }
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), locked_opts)
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), locked_opts)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), locked_opts)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), locked_opts)

-- Screenshot
hl.bind("Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

-- Utilities (Lock, Calc, Cliphist, RBW)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("[float; size 800 600] qalculate-gtk"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("bash -c 'quickshell ipc call cliphist-$(hyprctl activeworkspace -j | jq -r \".monitor\") toggle'"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("bash -c 'quickshell ipc call rbw-$(hyprctl activeworkspace -j | jq -r \".monitor\") toggle'"))