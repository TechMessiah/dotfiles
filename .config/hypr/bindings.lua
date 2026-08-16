-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Personal bindings carried over from the pre-quattro bindings.conf. The other
-- ~24 bindings in that file are now identical Omarchy defaults.

-- Activity on the key it used to live on. Omarchy's default moved btop to
-- SUPER + CTRL + T, which stays bound as well.
o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })

-- Workspace overview via the hyprexpo plugin (loaded by hypr/autostart.lua).
-- Plugin dispatchers live on hl.plugin.<plugin>.<dispatcher> and fire when
-- called, so they have to be wrapped in a function rather than passed directly.
o.bind("SUPER + GRAVE", "Workspace overview", function()
  hl.plugin.hyprexpo.expo("toggle")
end)

-- Typora on SUPER + SHIFT + W. Not installed right now (quattro's default binds
-- that key to Omawrite, which also isn't installed). Uncomment both lines after
-- installing typora.
-- hl.unbind("SUPER + SHIFT + W")
-- o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- Quickapps shell on ALT + SPACE. ~/.local/share/omarchy-quickapps/shell.qml no
-- longer exists, so this stays off until that shell is restored.
-- o.bind("ALT + SPACE", "Quickapps", "quickshell -p " ..
--   (os.getenv("HOME") or "") .. "/.local/share/omarchy-quickapps/shell.qml")
