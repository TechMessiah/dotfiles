-- Tychone theme borders (Lua port of the pre-quattro hyprland.conf).
-- This file wins over the generated template because omarchy-theme-set-templates
-- only writes hyprland.lua when the theme doesn't already ship one.

local cyan = "rgba(90f1ef88)" -- default focus / calm apps
local mint = "rgba(7bf1a888)" -- terminals
local blush = "rgba(ffd6e088)" -- browsers
local butter = "rgba(ffef9f88)" -- editors / fullscreen
local sage = "rgba(c1fba488)" -- file managers
local inactive = "rgba(5c637044)" -- neutral, unfocused stays quiet

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

-- Per-app active border colors. The window rule only carries the ACTIVE color
-- (as a gradient table); unfocused windows keep the global `inactive` above.

-- Terminals - mint
o.window("^(kitty|Alacritty|com.mitchellh.ghostty|foot)$", { border_color = { colors = { mint } } })

-- Browsers - blush pink
o.window("^(firefox|Chromium|brave-browser|google-chrome|zen|zen-alpha)$", { border_color = { colors = { blush } } })

-- Editors - pale yellow
o.window("^(Code|nvim|neovide|zed|Helix)$", { border_color = { colors = { butter } } })

-- File managers - sage green
o.window("^(nautilus|org.gnome.Nautilus|dolphin)$", { border_color = { colors = { sage } } })

-- Media / games - cyan (same as default, low-priority visual)
o.window("^(Spotify|steam)$", { border_color = { colors = { cyan } } })

-- Uncomment to make every fullscreen window pale yellow regardless of app:
-- o.window({ fullscreen = true }, { border_color = { colors = { butter } } })
