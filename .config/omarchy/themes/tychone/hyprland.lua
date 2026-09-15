-- Tychone theme borders (Lua port of the pre-quattro hyprland.conf).
-- This file wins over the generated template because omarchy-theme-set-templates
-- only writes hyprland.lua when the theme doesn't already ship one.
--
-- Each active border is a three-stop gradient that travels in HUE at constant
-- brightness, not from bright to dark. Luminance ramps read as "one lit end,
-- one faint end" and pull the eye; a flat-brightness hue arc reads as a border
-- that shifts color along its run. Alpha is a constant 99 on every stop, which
-- keeps the overall weight near the theme's original flat 88 borders.

local cyan = { colors = { "rgba(90f1ef99)", "rgba(86c8f299)", "rgba(9fb6f099)" }, angle = 45 } -- default focus / calm apps
local mint = { colors = { "rgba(7bf1a899)", "rgba(78ead099)", "rgba(86e0f099)" }, angle = 45 } -- terminals
local blush = { colors = { "rgba(ffd6e099)", "rgba(f2c9f099)", "rgba(d9c9ff99)" }, angle = 45 } -- browsers
local butter = { colors = { "rgba(ffef9f99)", "rgba(ffd9a399)", "rgba(ffc7b099)" }, angle = 45 } -- editors / fullscreen
local sage = { colors = { "rgba(c1fba499)", "rgba(a8f0b899)", "rgba(93e8cf99)" }, angle = 45 } -- file managers
local inactive = "rgba(5c637044)" -- neutral, unfocused stays quiet and flat

hl.config({
  general = {
    col = {
      active_border = cyan,
      inactive_border = inactive,
    },
  },

  group = {
    col = {
      border_active = cyan,
      border_inactive = inactive,
    },
  },
})

-- Per-app active border colors. The window rule only carries the ACTIVE gradient;
-- unfocused windows keep the global `inactive` above.

-- Terminals - mint into cyan
o.window("^(kitty|Alacritty|com.mitchellh.ghostty|foot)$", { border_color = mint })

-- Browsers - blush into rose
o.window("^(firefox|Chromium|brave-browser|google-chrome|zen|zen-alpha)$", { border_color = blush })

-- Editors - butter into blush
o.window("^(Code|nvim|neovide|zed|Helix)$", { border_color = butter })

-- File managers - sage into mint
o.window("^(nautilus|org.gnome.Nautilus|dolphin)$", { border_color = sage })

-- Media / games - cyan (same as default, low-priority visual)
o.window("^(Spotify|steam)$", { border_color = cyan })

-- Uncomment to make every fullscreen window butter regardless of app:
-- o.window({ fullscreen = true }, { border_color = butter })
