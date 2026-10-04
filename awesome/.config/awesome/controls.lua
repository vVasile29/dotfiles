local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")
local dpi = beautiful.xresources.apply_dpi
local p = beautiful.palette
local controls = {}

local label = wibox.widget {
    font = "Lato Bold 11",
    align = "center",
    widget = wibox.widget.textbox,
}
local meter = wibox.widget {
    max_value = 100,
    color = p.accent,
    background_color = p.surface,
    forced_height = dpi(6),
    shape = gears.shape.rounded_bar,
    bar_shape = gears.shape.rounded_bar,
    widget = wibox.widget.progressbar,
}
local osd = wibox {
    visible = false,
    ontop = true,
    type = "notification",
    width = dpi(280),
    height = dpi(88),
    bg = p.bg,
    fg = p.fg,
    border_width = dpi(1),
    border_color = p.surface,
    shape = beautiful.rounded_shape,
    widget = wibox.widget {
        {
            label,
            meter,
            spacing = dpi(14),
            layout = wibox.layout.fixed.vertical,
        },
        margins = dpi(20),
        widget = wibox.container.margin,
    },
}
local hide = gears.timer {
    timeout = 1.5,
    single_shot = true,
    callback = function() osd.visible = false end,
}

local function show(title, value, muted)
    osd.screen = awful.screen.focused()
    label.text = title .. "  " .. (muted and "Muted" or tostring(value) .. "%")
    meter.value = muted and 0 or math.min(value, 100)
    meter.color = muted and p.muted or p.accent
    awful.placement.bottom(osd, { honor_workarea = true, margins = dpi(32) })
    osd.visible = true
    hide:again()
end

local function failed(title, stderr)
    naughty.notify {
        preset = naughty.config.presets.critical,
        title = title,
        text = gears.string.xml_escape(stderr ~= "" and stderr or "Command failed"),
    }
end

function controls.brightness(up)
    awful.spawn.easy_async({ "brightnessctl", "--class=backlight", "--min-value=1",
        "--machine-readable", "set", up and "+5%" or "5%-" },
        function(stdout, stderr, _, code)
            if code ~= 0 then
                failed("Brightness unavailable", stderr)
                return
            end
            local value = tonumber(stdout:match(",(%d+)%%,"))
            if value then show("Brightness", value) end
        end)
end

function controls.audio(action)
    local commands = {
        up = "pactl set-sink-volume @DEFAULT_SINK@ +5%",
        down = "pactl set-sink-volume @DEFAULT_SINK@ -5%",
        mute = "pactl set-sink-mute @DEFAULT_SINK@ toggle",
        mic = "pactl set-source-mute @DEFAULT_SOURCE@ toggle",
    }
    local target = action == "mic" and "source" or "sink"
    local device = action == "mic" and "@DEFAULT_SOURCE@" or "@DEFAULT_SINK@"
    awful.spawn.easy_async_with_shell(commands[action]
        .. " && pactl get-" .. target .. "-volume " .. device
        .. " && LC_ALL=C pactl get-" .. target .. "-mute " .. device,
        function(stdout, stderr, _, code)
            if code ~= 0 then
                failed("Audio unavailable", stderr)
                return
            end
            local value = tonumber(stdout:match("(%d+)%%"))
            if value then show(action == "mic" and "Microphone" or "Volume", value,
                stdout:match("Mute: yes") ~= nil) end
        end)
end

function controls.lock(after)
    -- Only suspend after the existing lock daemon accepts the lock request.
    awful.spawn.easy_async({ "xscreensaver-command", "-lock" },
        function(_, stderr, _, code)
            if code ~= 0 then
                failed("Could not lock the screen", stderr)
            elseif after then
                after()
            end
        end)
end

function controls.power_menu()
    awful.spawn.easy_async_with_shell(
        "printf '%s\\n' Lock Suspend 'Log out' Reboot 'Power off' | "
        .. "rofi -dmenu -i -no-custom -no-show-icons -p Session "
        .. "-theme-str 'listview { lines: 5; }'",
        function(stdout, _, _, code)
            if code ~= 0 then return end
            local choice = stdout:gsub("%s+$", "")
            if choice == "Lock" then
                controls.lock()
            elseif choice == "Suspend" then
                controls.lock(function() awful.spawn({ "systemctl", "suspend" }) end)
            elseif choice == "Log out" or choice == "Reboot" or choice == "Power off" then
                awful.spawn.easy_async_with_shell(
                    "printf '%s\\n' Cancel Confirm | rofi -dmenu -i -no-custom "
                    .. "-no-show-icons -p '" .. choice
                    .. "?' -theme-str 'listview { lines: 2; }'",
                    function(answer, _, _, status)
                        if status ~= 0 or answer:gsub("%s+$", "") ~= "Confirm" then return end
                        if choice == "Log out" then
                            awesome.quit()
                        else
                            awful.spawn({ "systemctl", choice == "Reboot" and "reboot" or "poweroff" })
                        end
                    end)
            end
        end)
end

return controls
