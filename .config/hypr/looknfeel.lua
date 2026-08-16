-- Change the default Omarchy look'n'feel.
-- Lua port of the pre-quattro looknfeel.conf.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 3,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    rounding = 0,

    -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
    dim_inactive = true,
    dim_strength = 0.2,

    active_opacity = 0.95,
    inactive_opacity = 1,

    blur = {
      enabled = true,
      size = 20,
      passes = 3,
      new_optimizations = true,
      xray = false,
      ignore_opacity = false,

      -- Blur popups too, not just windows.
      popups = true,
      popups_ignorealpha = 0.8,
    },
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
hl.config({
  animations = {
    enabled = true,
  },
})

hl.curve("wind", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1.1 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 }, { 0, 1 } } })
hl.curve("liner", { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "wind", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 6, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner", style = "once" })
hl.animation({ leaf = "fade", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "wind" })

-- hyprpm plugin settings. The plugins themselves are loaded by
-- hypr/autostart.lua; these keywords are accepted even before that happens.
hl.config({
  plugin = {
    hyprexpo = {
      columns = 3,
      gaps_in = 10,
      gaps_out = 10,
      label_enable = 1,
      bg_col = "rgba(00000080)",
      workspace_method = "center current",
    },

    -- NOTE the underscore: the plugin repo is named dynamic-cursors, but the
    -- Lua parser namespaces it as dynamic_cursors. The hyphenated spelling is
    -- rejected as an unknown config key in every form.
    dynamic_cursors = {
      enabled = true,
      mode = "rotate",
      threshold = 1,

      rotate = {
        -- The old .conf set rotate:length_cutoff, which is not a real key and
        -- was silently ignored by the legacy parser. The real one is
        -- rotate:length (px, default 20), left at its default here.
        offset = 0,
      },

      shake = {
        enabled = true,
        effects = true,
      },
    },
  },
})
