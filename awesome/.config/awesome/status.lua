local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")
local GLib = require("lgi").GLib
local controls = require("controls")
local dpi = beautiful.xresources.apply_dpi
local p = beautiful.palette
local status = {}

-- One sampler and one audio subscription, shared by all monitors.
local views = setmetatable({}, { __mode = "k" })
local state = { volume = nil, muted = false, sink = "", down = 0, up = 0 }
local previous_cpu, previous_net

local function read(path)
    local file = io.open(path, "r")
    if not file then return "" end
    local text = file:read("*a") or ""
    file:close()
    return text
end

local function numbers(text)
    local values = {}
    for value in text:gmatch("%d+") do values[#values + 1] = tonumber(value) end
    return values
end

local function span(text, color, font)
    return '<span foreground="' .. color .. '" font_desc="' .. (font or "Lato Bold 8")
        .. '">' .. gears.string.xml_escape(text) .. '</span>'
end

local function load_color(value, normal)
    if value and value >= 90 then return p.urgent end
    if value and value >= 75 then return p.warning end
    return normal
end

local function rate(value)
    local scaled, unit = value / 1024, "K"
    for _, next_unit in ipairs({ "M", "G", "T" }) do
        if scaled < 999.5 then break end
        scaled, unit = scaled / 1024, next_unit
    end
    return string.format(scaled < 9.95 and unit ~= "K" and "%.1f%s" or "%.0f%s", scaled, unit)
end

local function route_interface()
    local interface, lowest = nil, math.huge
    for line in read("/proc/net/route"):gmatch("[^\n]+") do
        local name, destination, flags, metric = line:match(
            "^(%S+)%s+(%x+)%s+%x+%s+(%x+)%s+%d+%s+%d+%s+(%d+)")
        if destination == "00000000" and tonumber(flags, 16) % 2 == 1
            and tonumber(metric) < lowest then
            interface, lowest = name, tonumber(metric)
        end
    end
    if interface then return interface end
    -- Also work on IPv6-only networks.
    for line in read("/proc/net/ipv6_route"):gmatch("[^\n]+") do
        local destination, prefix, metric, flags, name = line:match(
            "^(%x+)%s+(%x+)%s+%x+%s+%x+%s+%x+%s+(%x+)%s+%x+%s+%x+%s+(%x+)%s+(%S+)")
        if destination == string.rep("0", 32) and prefix == "00" and name ~= "lo"
            and tonumber(flags, 16) % 2 == 1 and tonumber(metric, 16) < lowest then
            interface, lowest = name, tonumber(metric, 16)
        end
    end
    return interface
end

local function sample()
    local cpu = numbers(read("/proc/stat"):match("^cpu%s+([^\n]+)") or "")
    if #cpu >= 4 then
        local total = 0
        -- Guest time is already included in user/nice; don't count it twice.
        for i = 1, math.min(#cpu, 8) do total = total + cpu[i] end
        local idle = cpu[4] + (cpu[5] or 0)
        if previous_cpu and total > previous_cpu.total then
            state.cpu = math.max(0, math.min(100,
                100 * (1 - (idle - previous_cpu.idle) / (total - previous_cpu.total))))
        end
        previous_cpu = { total = total, idle = idle }
    end
    state.load = read("/proc/loadavg"):match("^(%S+%s+%S+%s+%S+)") or "Unavailable"

    local memory = read("/proc/meminfo")
    state.total = tonumber(memory:match("MemTotal:%s+(%d+)"))
    state.available = tonumber(memory:match("MemAvailable:%s+(%d+)"))
    if state.total and state.total > 0 and state.available then
        state.used = state.total - state.available
        state.ram = 100 * state.used / state.total
    end

    state.interface = route_interface()
    local now = GLib.get_monotonic_time() / 1000000
    state.down, state.up = 0, 0
    for line in read("/proc/net/dev"):gmatch("[^\n]+") do
        local name, counters = line:match("^%s*([^:%s]+):%s*(.*)")
        if name == state.interface then
            local values = numbers(counters)
            if values[1] and values[9] then
                if previous_net and previous_net.name == name and now > previous_net.time then
                    local elapsed = now - previous_net.time
                    state.down = math.max(0, (values[1] - previous_net.rx) / elapsed)
                    state.up = math.max(0, (values[9] - previous_net.tx) / elapsed)
                end
                previous_net = { name = name, time = now, rx = values[1], tx = values[9] }
            end
        end
    end
    if not state.interface then previous_net = nil end
end

local function refresh_views()
    for view in pairs(views) do view.update() end
end

local audio_busy = false
local function refresh_audio()
    if audio_busy then return end
    audio_busy = true
    awful.spawn.easy_async_with_shell(
        "LC_ALL=C pactl get-sink-volume @DEFAULT_SINK@ && "
        .. "LC_ALL=C pactl get-sink-mute @DEFAULT_SINK@ && pactl get-default-sink",
        function(stdout, _, _, code)
            audio_busy = false
            state.volume = code == 0 and tonumber(stdout:match("(%d+)%%")) or nil
            state.muted = stdout:match("Mute: yes") ~= nil
            state.sink = stdout:match("\n([^\n]+)\n?$") or ""
            refresh_views()
        end)
end

local audio_debounce = gears.timer {
    timeout = 0.15, single_shot = true, callback = refresh_audio,
}
local subscriber, stopping
local audio_retry = gears.timer { timeout = 5, single_shot = true }
local function subscribe_audio()
    if stopping then return end
    local pid = awful.spawn.with_line_callback({ "env", "LC_ALL=C", "pactl", "subscribe" }, {
        stdout = function(line)
            if line:match("on sink") or line:match("on server") then audio_debounce:again() end
        end,
        exit = function()
            subscriber = nil
            state.volume = nil
            refresh_views()
            if not stopping then audio_retry:again() end
        end,
    })
    if type(pid) == "number" then
        subscriber = pid
        refresh_audio()
    else
        audio_retry:again()
    end
end
audio_retry:connect_signal("timeout", subscribe_audio)
awesome.connect_signal("exit", function()
    stopping = true
    audio_retry:stop()
    audio_debounce:stop()
    if subscriber then awesome.kill(subscriber, 15) end
end)

local function card(glyph, label, color, value_width, meter)
    local icon = wibox.widget {
        text = glyph, font = "FontAwesome 11", align = "center",
        forced_width = dpi(17), widget = wibox.widget.textbox,
    }
    local value = wibox.widget {
        font = "DejaVu Sans Mono Bold 9", align = "right",
        forced_width = value_width and dpi(value_width), widget = wibox.widget.textbox,
    }
    local row = wibox.widget {
        {
            icon,
            left = dpi(meter and 2 or 0), right = dpi(meter and 4 or 0),
            top = dpi(meter and 1 or 0), bottom = dpi(meter and 1 or 0),
            widget = wibox.container.margin,
        },
        spacing = dpi(6), layout = wibox.layout.fixed.horizontal,
    }
    if label ~= "" then
        row:add(wibox.widget { markup = span(label, p.muted), widget = wibox.widget.textbox })
    end
    row:add(value)
    local content = wibox.layout.fixed.vertical()
    content.spacing = dpi(2)
    content:add(row)
    local gauge
    if meter then
        gauge = wibox.widget {
            max_value = 100, value = 0, forced_height = dpi(2),
            background_color = p.surface, color = color,
            shape = gears.shape.rounded_bar, bar_shape = gears.shape.rounded_bar,
            widget = wibox.widget.progressbar,
        }
        content:add(gauge)
    end
    local widget = wibox.widget {
        {
            content, left = dpi(9), right = dpi(9), top = dpi(meter and 2 or 4),
            bottom = dpi(meter and 2 or 4), widget = wibox.container.margin,
        },
        bg = p.backdrop, fg = color, shape = beautiful.rounded_shape,
        forced_width = meter and dpi(value_width + 84),
        shape_border_width = dpi(1), shape_border_color = p.surface .. "80",
        widget = wibox.container.background,
    }
    widget:connect_signal("mouse::enter", function() widget.shape_border_color = color end)
    widget:connect_signal("mouse::leave", function() widget.shape_border_color = p.surface .. "80" end)
    local tip = awful.tooltip { objects = { widget }, delay_show = 0.35, preferred_positions = { "bottom" } }
    return {
        widget = widget,
        set = function(text, tint, percent, tooltip, symbol)
            value.markup = span(text, tint, "DejaVu Sans Mono Bold 9")
            icon.markup = span(symbol or glyph, tint, "FontAwesome 11")
            if gauge then gauge.value = percent or 0; gauge.color = tint end
            tip:set_text(tooltip)
        end,
    }
end

function status.new(terminal)
    local cpu = card("", "CPU", p.accent, 36, true)
    local ram = card("", "RAM", p.pink, 49, true)
    -- Reserve room for both rates even while idle/offline, avoiding bar reflows.
    local net = card("", "", p.green, 80)
    local volume = card("", "", p.accent, 36)
    local function monitor() awful.spawn({ terminal or "alacritty", "-e", "htop" }) end
    cpu.widget:buttons(gears.table.join(awful.button({}, 1, monitor)))
    ram.widget:buttons(gears.table.join(awful.button({}, 1, monitor)))
    net.widget:buttons(gears.table.join(
        awful.button({}, 1, function() awful.spawn("nm-connection-editor") end)))
    volume.widget:buttons(gears.table.join(
        awful.button({}, 1, function() controls.audio("mute") end),
        awful.button({}, 3, function() awful.spawn("pavucontrol") end),
        awful.button({}, 4, function() controls.audio("up") end),
        awful.button({}, 5, function() controls.audio("down") end)))

    local view = wibox.widget {
        cpu.widget, ram.widget, net.widget, volume.widget,
        spacing = dpi(6), layout = wibox.layout.fixed.horizontal,
    }
    view.update = function()
        cpu.set(state.cpu and string.format("%.0f%%", state.cpu) or "—",
            load_color(state.cpu, p.accent), state.cpu,
            string.format("CPU usage: %s\nLoad average (1 / 5 / 15 min): %s\nClick: open htop",
                state.cpu and string.format("%.1f%%", state.cpu) or "Sampling…", state.load or "—"))
        ram.set(state.used and string.format("%.1fG", state.used / 1024 / 1024) or "—",
            load_color(state.ram, p.pink), state.ram,
            state.used and string.format("Memory: %.1f / %.1f GiB (%.0f%%)\nAvailable: %.1f GiB\nClick: open htop",
                state.used / 1024 / 1024, state.total / 1024 / 1024, state.ram,
                state.available / 1024 / 1024) or "Memory unavailable")
        local busy = math.max(state.down, state.up) >= 1024
        net.set(not state.interface and "OFF" or busy
            and ("↓" .. rate(state.down) .. " ↑" .. rate(state.up)) or "LINK",
            state.interface and p.green or p.urgent, nil,
            (state.interface and string.format("Default route: %s\nDownload: %.1f KiB/s\nUpload: %.1f KiB/s",
                state.interface, state.down / 1024, state.up / 1024) or "No default network route")
                .. "\nClick: connection settings")
        volume.set(state.volume and (state.muted and "MUTE" or state.volume .. "%") or "—",
            state.volume and (state.muted and p.muted or p.accent) or p.muted, nil,
            (state.volume and string.format("Volume: %d%%%s\nOutput: %s", state.volume,
                state.muted and " (muted)" or "", state.sink) or "Audio unavailable")
                .. "\nScroll: volume · Click: mute\nRight-click: audio settings",
            state.muted and "" or (state.volume and state.volume > 50 and "" or ""))
    end
    views[view] = true
    view.update()
    return view
end

status.timer = gears.timer {
    timeout = 2, autostart = true, call_now = true,
    callback = function() sample(); refresh_views() end,
}
subscribe_audio()

return status
