-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Built-in laptop display.
hl.monitor({
  output = "desc:Apple Computer Inc Color LCD",
  mode = "2304x1440@59.945",
  position = "0x0",
  scale = omarchy_monitor_scale,
  transform = 0,
  vrr = 0,
})

-- External HP 527sa, placed to the right of the built-in display.
hl.monitor({
  output = "desc:HP Inc. HP 527sa 3CM4470D7F",
  mode = "1920x1080@60",
  position = "1440x0",
  scale = omarchy_monitor_scale,
  transform = 0,
  vrr = 0,
})

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
