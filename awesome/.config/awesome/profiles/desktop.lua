-- Shared desktop defaults. Per-computer overrides belong in machine.lua.
return {
    battery = false,
    brightness = false,
    compositor = true,
    monitor_script = "scripts/set_monitors.sh",
    app_rules = {
        -- This workstation: Cliq on the portrait monitor, IDEs on the right.
        { rule = { class = "Cliq" },
          properties = { screen = "HDMI-A-0" } },
        { rule = { class = "^jetbrains%-" },
          properties = { screen = "DisplayPort-1" } },
        { rule = { class = "^jetbrains%-", name = "^webapp%-frontend" },
          properties = { screen = "DisplayPort-1", tag = "1" } },
        { rule = { class = "^jetbrains%-", name = "^services" },
          properties = { screen = "DisplayPort-1", tag = "2" } },
        { rule = { class = "^jetbrains%-", name = "^document%-engine" },
          properties = { screen = "DisplayPort-1", tag = "3" } },
    },
}
