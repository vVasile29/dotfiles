local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = beautiful.xresources.apply_dpi
local p = beautiful.palette
local tray = {}
local buttons = setmetatable({}, { __mode = "k" })
local active

-- XEmbed supports one native tray. Move a single drawer, rather than trying
-- to draw the tray widget into several wibars at the same time.
local icons = wibox.widget.systray()
icons:set_base_size(dpi(22))
icons.forced_height = dpi(26)
local close = wibox.widget {
    text = "×", font = "Lato Bold 14", align = "right", widget = wibox.widget.textbox,
}
tray.popup = awful.popup {
    visible = false, ontop = true, bg = p.backdrop, fg = p.fg,
    border_width = dpi(1), border_color = p.surface, shape = beautiful.rounded_shape,
    preferred_positions = { "bottom", "top" }, preferred_anchors = { "middle", "back", "front" },
    offset = dpi(8),
    widget = {
        {
            {
                { markup = '<span foreground="' .. p.muted .. '"><b>SYSTEM TRAY</b></span>',
                  font = "Lato 8", widget = wibox.widget.textbox },
                nil, close, layout = wibox.layout.align.horizontal,
            },
            icons, spacing = dpi(10), layout = wibox.layout.fixed.vertical,
        },
        margins = dpi(12), widget = wibox.container.margin,
    },
    minimum_width = dpi(160),
}

local function refresh()
    for button in pairs(buttons) do
        button.shape_border_color = button == active and tray.popup.visible and p.accent or p.surface .. "80"
        button.fg = awesome.systray() > 0 and p.fg or p.muted
    end
    if awesome.systray() == 0 and tray.popup.visible then tray.popup.visible = false end
end
awesome.connect_signal("systray::update", refresh)
tray.popup:connect_signal("property::visible", refresh)
local function hide()
    tray.popup.visible, active = false, nil
    refresh()
end
close:buttons(gears.table.join(awful.button({}, 1, hide)))
tray.close = hide
screen.connect_signal("removed", function(s)
    if tray.popup.screen == s then hide() end
end)

function tray.toggle(s, button, geometry)
    if active == button and tray.popup.visible then hide(); return end
    if awesome.systray() == 0 then return end
    active = button
    tray.popup.screen = s
    icons:set_screen(s)
    tray.popup:move_next_to(geometry or mouse.current_widget_geometry or {
        x = s.geometry.x + s.geometry.width - dpi(260), y = s.geometry.y,
        width = dpi(70), height = dpi(46),
    })
    refresh()
end

function tray.new(s)
    local button = wibox.widget {
        {
            {
                { text = "", font = "FontAwesome 10", widget = wibox.widget.textbox },
                { text = "TRAY", font = "Lato Bold 8", widget = wibox.widget.textbox },
                spacing = dpi(6), layout = wibox.layout.fixed.horizontal,
            },
            left = dpi(9), right = dpi(9), widget = wibox.container.margin,
        },
        bg = p.backdrop, fg = p.fg, shape = beautiful.rounded_shape,
        shape_border_width = dpi(1), shape_border_color = p.surface .. "80",
        widget = wibox.container.background,
    }
    button:buttons(gears.table.join(awful.button({}, 1, function()
        tray.toggle(s, button)
    end)))
    button:connect_signal("mouse::enter", function() button.shape_border_color = p.accent end)
    button:connect_signal("mouse::leave", refresh)
    awful.tooltip { objects = { button }, delay_show = 0.5,
        text = "Click to open the system tray here\nClick again or × to close" }
    buttons[button] = true
    refresh()
    return button
end

return tray
