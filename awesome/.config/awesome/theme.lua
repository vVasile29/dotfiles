local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local theme = dofile(gears.filesystem.get_themes_dir() .. "default/theme.lua")

theme.palette = {
    backdrop = "#1e1f29",
    bg = "#282a36",
    surface = "#44475a",
    fg = "#f8f8f2",
    muted = "#6272a4",
    accent = "#bd93f9",
    pink = "#ff79c6",
    green = "#50fa7b",
    urgent = "#ff5555",
    warning = "#f1fa8c",
    font = "Lato 10",
}
local p = theme.palette
theme.rounded_shape = function(cr, width, height)
    gears.shape.rounded_rect(cr, width, height, dpi(10))
end

theme.font = p.font
theme.bg_normal = p.bg
theme.fg_normal = p.fg
theme.bg_focus = p.accent
theme.fg_focus = p.bg
theme.bg_urgent = p.urgent
theme.fg_urgent = p.bg
theme.bg_minimize = p.bg
theme.fg_minimize = p.muted
theme.bg_systray = p.bg
theme.border_width = dpi(1)
theme.border_normal = p.surface
theme.border_focus = p.accent
theme.border_marked = p.pink
theme.useless_gap = dpi(5)
theme.gap_single_client = true
theme.icon_theme = "Adwaita"
theme.taglist_squares_sel = nil
theme.taglist_squares_unsel = nil

theme.menu_height = dpi(28)
theme.menu_width = dpi(220)
theme.menu_bg_normal = p.bg
theme.menu_fg_normal = p.fg
theme.menu_bg_focus = p.accent
theme.menu_fg_focus = p.bg
theme.menu_border_color = p.surface
theme.menu_border_width = dpi(1)
theme.awesome_icon = require("beautiful.theme_assets").awesome_icon(dpi(20), p.bg, p.accent)

theme.tooltip_bg = p.bg
theme.tooltip_fg = p.fg
theme.tooltip_font = p.font
theme.tooltip_border_color = p.surface
theme.tooltip_border_width = dpi(1)
theme.tooltip_shape = theme.rounded_shape

theme.notification_bg = p.bg
theme.notification_fg = p.fg
theme.notification_font = p.font
theme.notification_border_color = p.surface
theme.notification_border_width = dpi(1)
theme.notification_margin = dpi(12)
theme.notification_max_width = dpi(360)
theme.notification_icon_size = dpi(32)
theme.notification_shape = theme.rounded_shape
theme.notification_opacity = 1

theme.hotkeys_bg = p.bg
theme.hotkeys_fg = p.fg
theme.hotkeys_font = "Lato Bold 10"
theme.hotkeys_description_font = p.font
theme.hotkeys_border_color = p.surface
theme.hotkeys_border_width = dpi(1)
theme.hotkeys_modifiers_fg = p.accent
theme.hotkeys_label_bg = p.surface
theme.hotkeys_label_fg = p.fg
theme.hotkeys_shape = theme.rounded_shape
theme.hotkeys_opacity = 1

theme.prompt_fg_cursor = p.bg
theme.prompt_bg_cursor = p.accent
theme.calendar_style = {
    bg_color = p.bg,
    fg_color = p.fg,
    border_width = 0,
    padding = dpi(5),
}
theme.calendar_month_padding = dpi(12)
theme.calendar_month_border_width = dpi(1)
theme.calendar_month_border_color = p.surface
theme.calendar_month_shape = theme.rounded_shape
theme.calendar_header_fg_color = p.accent
theme.calendar_weekday_fg_color = p.muted
theme.calendar_focus_bg_color = p.accent
theme.calendar_focus_fg_color = p.bg
theme.calendar_focus_shape = theme.rounded_shape

return theme
