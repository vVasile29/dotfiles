local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")
local GLib = require("lgi").GLib
local dpi = beautiful.xresources.apply_dpi
local p = beautiful.palette
local usage_history = {}

function usage_history.new(capacity)
    local history = { values = {}, times = {}, weights = {}, capacity = capacity or 512, averaged = false }
    assert(history.capacity >= 4, "History needs at least four samples")
    function history:push(value, time, weight)
        if type(value) ~= "number" or value ~= value then return false end
        time, weight = time or GLib.get_monotonic_time() / 1000000, weight or 1
        if type(time) ~= "number" or time ~= time or time < 0 or time == math.huge
            or (self.last_time and time <= self.last_time)
            or type(weight) ~= "number" or weight ~= weight or weight < 1 or weight == math.huge then
            return false
        end
        self.first_time, self.started_at = self.first_time or time, self.started_at or os.time()
        self.last_time = time
        self.averaged = self.averaged or weight > 1
        self.values[#self.values + 1] = math.max(0, math.min(100, value))
        self.times[#self.times + 1], self.weights[#self.weights + 1] = time, weight
        if #self.values > self.capacity then
            -- Weighted pairs retain the entire time span instead of dropping old data.
            -- Keep the first and newest readings exact, and average the interior.
            local last = #self.values
            local values, times, weights = { self.values[1] }, { self.times[1] }, { self.weights[1] }
            for i = 2, last - 1, 2 do
                local next_i = i + 1 < last and i + 1 or nil
                local a, b = self.weights[i], next_i and self.weights[next_i] or 0
                local n = #values + 1
                weights[n] = a + b
                values[n] = (self.values[i] * a + (next_i and self.values[next_i] or 0) * b) / weights[n]
                times[n] = (self.times[i] * a + (next_i and self.times[next_i] or 0) * b) / weights[n]
            end
            values[#values + 1], times[#times + 1], weights[#weights + 1] =
                self.values[last], self.times[last], self.weights[last]
            self.values, self.times, self.weights = values, times, weights
            self.averaged = true
        end
        return true
    end
    return history
end

local function fresh(capacity)
    return { cpu = usage_history.new(capacity), ram = usage_history.new(capacity) }
end

local function finite(value)
    value = tonumber(value)
    if value and value == value and math.abs(value) < math.huge then return value end
end

function usage_history.load(path, boot_id, capacity)
    local histories = fresh(capacity)
    local file = boot_id and io.open(path, "r")
    if not file then return histories end
    if file:read("*l") ~= "awesome-usage-v1\t" .. boot_id then file:close(); return histories end
    local loaded, bounds, count = fresh(capacity), {}, 0
    local valid = true
    for line in file:lines() do
        count = count + 1
        if count > 2 * (capacity or 512) + 2 then valid = false; break end
        local fields = {}
        for field in line:gmatch("[^\t]+") do fields[#fields + 1] = field end
        local h = loaded[fields[1]]
        local a, b, c = finite(fields[3]), finite(fields[4]), finite(fields[5])
        if not h or #fields ~= 5 or not a or not b or not c then valid = false; break end
        if fields[2] == "span" and not bounds[fields[1]] and a >= 0 and b >= a and c >= 0 then
            bounds[fields[1]] = { a, b, c }
        elseif fields[2] == "point" then
            if #h.values >= h.capacity or not h:push(b, a, c) then valid = false; break end
        else
            valid = false; break
        end
    end
    file:close()
    for metric, h in pairs(loaded) do
        local span = bounds[metric]
        if #h.values > 0 then
            if not span or span[1] > h.times[1] or span[2] < h.times[#h.times] then
                valid = false
            else
                h.first_time, h.last_time, h.started_at = span[1], span[2], span[3]
            end
        end
    end
    return valid and loaded or histories
end

function usage_history.save(path, boot_id, histories)
    if not boot_id then return true end
    local lines = { "awesome-usage-v1\t" .. boot_id }
    for _, metric in ipairs({ "cpu", "ram" }) do
        local h = histories[metric]
        if h.first_time then
            lines[#lines + 1] = string.format("%s\tspan\t%.17g\t%.17g\t%.17g",
                metric, h.first_time, h.last_time, h.started_at)
        end
        for i, value in ipairs(h.values) do
            lines[#lines + 1] = string.format("%s\tpoint\t%.17g\t%.17g\t%.17g",
                metric, h.times[i], value, h.weights[i])
        end
    end
    local ok, err = gears.filesystem.make_parent_directories(path)
    if not ok then return nil, err end
    local temporary = path .. ".tmp"
    local file
    file, err = io.open(temporary, "w")
    if not file then return nil, err end
    ok, err = file:write(table.concat(lines, "\n") .. "\n")
    local closed, close_error = file:close()
    if not ok or not closed then os.remove(temporary); return nil, err or close_error end
    ok, err = os.rename(temporary, path)
    if not ok then os.remove(temporary) end
    return ok, err
end

local function duration(seconds)
    seconds = math.floor(seconds)
    if seconds >= 86400 then return string.format("%dd %dh", math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600)) end
    if seconds >= 3600 then return string.format("%dh %dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
end

local function textbox(text, font, align)
    return wibox.widget {
        text = text, font = font or "Lato 9", align = align or "left",
        valign = "center", widget = wibox.widget.textbox,
        forced_height = dpi(16),
    }
end

local function colored_text(text, color, font, align)
    return wibox.widget {
        textbox(text, font, align), fg = color,
        widget = wibox.container.background,
    }
end

local function chart(history, color)
    local widget = wibox.widget.base.make_widget(nil, nil, { enable_properties = true })
    widget.forced_height = dpi(112)
    widget.color = color
    function widget:fit(_, width, height) return width, math.min(height, dpi(112)) end
    function widget:draw(_, cr, width, height)
        cr:set_source(gears.color(p.backdrop))
        cr:paint()
        cr:set_source(gears.color(p.surface .. "80"))
        cr:set_line_width(1)
        for _, fraction in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
            local y = 2 + fraction * (height - 4)
            cr:move_to(0, y)
            cr:line_to(width, y)
        end
        cr:stroke()
        local values = history.values
        if #values == 0 then return end
        local elapsed = history.last_time - history.first_time
        local function point(i)
            local fraction = elapsed > 0 and (history.times[i] - history.first_time) / elapsed or 1
            return 2 + fraction * (width - 4),
                2 + (1 - values[i] / 100) * (height - 4)
        end
        -- A fixed 0–100% scale: the same height always means the same usage.
        local first_x = point(1)
        cr:move_to(first_x, height - 2)
        for i = 1, #values do cr:line_to(point(i)) end
        local x, y = point(#values)
        cr:line_to(x, height - 2)
        cr:close_path()
        cr:set_source(gears.color(self.color .. "28"))
        cr:fill()
        cr:move_to(point(1))
        for i = 2, #values do cr:line_to(point(i)) end
        cr:set_source(gears.color(self.color))
        cr:set_line_width(dpi(1.5))
        cr:stroke()
        cr:arc(x, y, dpi(2), 0, 2 * math.pi)
        cr:fill()
    end
    return widget
end

function usage_history.attach(anchor, history, title, color)
    local view = { history = history, color = color }
    local geometry, target_screen
    local function prepare()
        if view.popup then return end
        view.graph = chart(history, color)
        view.value = wibox.widget { font = "DejaVu Sans Mono Bold 13", align = "right",
            widget = wibox.widget.textbox }
        view.details = wibox.widget { font = "Lato 9", widget = wibox.widget.textbox }
        view.range = textbox("THIS BOOT  ·  collecting history", "Lato Bold 8")
        view.start_label = textbox("start", "Lato 8")
        view.popup = awful.popup {
            -- Keep charts opaque; the compositor deliberately dims plain tooltips.
            visible = false, ontop = true, type = "dropdown_menu",
            bg = p.bg, fg = p.fg, border_width = dpi(1), border_color = color,
            shape = beautiful.rounded_shape,
            preferred_positions = { "bottom", "top" }, preferred_anchors = { "middle", "back", "front" },
            offset = dpi(8),
            widget = {
                {
                    {
                        { markup = '<span foreground="' .. color .. '"><b>' .. title .. '</b></span>',
                          font = "Lato 11", widget = wibox.widget.textbox },
                        nil, view.value, layout = wibox.layout.align.horizontal,
                    },
                    { view.range, fg = p.muted, widget = wibox.container.background },
                    {
                        {
                            colored_text("100%", p.muted, "DejaVu Sans Mono 8", "right"),
                            colored_text("50%", p.muted, "DejaVu Sans Mono 8", "right"),
                            colored_text("0%", p.muted, "DejaVu Sans Mono 8", "right"),
                            forced_width = dpi(36), layout = wibox.layout.align.vertical,
                        },
                        view.graph, spacing = dpi(8), forced_height = dpi(112),
                        layout = wibox.layout.fixed.horizontal,
                    },
                    {
                        { view.start_label, fg = p.muted, widget = wibox.container.background }, nil,
                        colored_text("now", p.muted, "Lato 8", "right"),
                        layout = wibox.layout.align.horizontal,
                    },
                    view.details, spacing = dpi(8), forced_width = dpi(344),
                    layout = wibox.layout.fixed.vertical,
                },
                margins = dpi(16), widget = wibox.container.margin,
            },
        }
    end
    function view:update(value, tint, details)
        self.percent, self.color, self.text = value, tint, details
        if not self.popup then return end
        self.value.markup = '<span foreground="' .. tint .. '">'
            .. (value and string.format("%.1f%%", value) or "—") .. '</span>'
        self.details.text = details
        local elapsed = history.first_time and history.last_time - history.first_time or 0
        self.range.text = "THIS BOOT  ·  " .. duration(elapsed) .. " recorded"
        if history.averaged then
            self.range.text = self.range.text .. "  ·  averaged"
        end
        self.start_label.text = history.started_at and os.date("start %d %b %H:%M", math.floor(history.started_at)) or "start"
        self.graph.color = tint
        self.graph:emit_signal("widget::redraw_needed")
    end
    function view:show(anchor_geometry, s)
        prepare()
        self:update(self.percent, self.color, self.text)
        self.popup.screen = s
        self.popup:move_next_to(anchor_geometry)
    end
    function view:hide()
        if self.popup then self.popup.visible = false end
    end
    local show = gears.timer {
        timeout = 0.3, single_shot = true,
        callback = function() view:show(geometry, target_screen) end,
    }
    anchor:connect_signal("mouse::enter", function()
        geometry, target_screen = mouse.current_widget_geometry, mouse.screen
        show:again()
    end)
    anchor:connect_signal("mouse::leave", function()
        show:stop()
        view:hide()
    end)
    return view
end

return usage_history
