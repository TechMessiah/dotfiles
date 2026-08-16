-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Load hyprpm plugins (dynamic-cursors, hyprexpo). Not wrapped in uwsm-app:
-- hyprpm talks to the compositor directly, it isn't a session app.
o.exec_on_start("hyprpm reload -n")
