local lgi = require("lgi")
local gears = require("gears")
local Gio, GLib = lgi.Gio, lgi.GLib
local appearance = {}

function appearance.apply()
    -- These plugins are supplied by qt5/qt6-gtk-platformtheme on Debian/Ubuntu.
    -- Respect an explicit per-machine environment override if one already exists.
    if not os.getenv("QT_QPA_PLATFORMTHEME") then GLib.setenv("QT_QPA_PLATFORMTHEME", "gtk3", false) end
    if not os.getenv("QT_STYLE_OVERRIDE") then GLib.setenv("QT_STYLE_OVERRIDE", "Fusion", false) end

    local source = Gio.SettingsSchemaSource.get_default()
    local schema = source and source:lookup("org.gnome.desktop.interface", true)
    if not schema then return end
    local settings = Gio.Settings.new("org.gnome.desktop.interface")
    local theme = "Adwaita-dark"
    for _, root in ipairs({ GLib.get_user_data_dir() .. "/themes/", os.getenv("HOME") .. "/.themes/",
        "/usr/local/share/themes/", "/usr/share/themes/" }) do
        if gears.filesystem.file_readable(root .. "Dracula/gtk-3.0/gtk.css") then theme = "Dracula"; break end
    end
    for key, value in pairs({
        ["gtk-theme"] = theme, ["color-scheme"] = "prefer-dark", ["accent-color"] = "purple",
        ["icon-theme"] = "Adwaita", ["font-name"] = "Lato 10", ["cursor-theme"] = "Adwaita",
    }) do
        if schema:has_key(key) and settings:is_writable(key) then settings:set_string(key, value) end
    end
    if schema:has_key("cursor-size") and settings:is_writable("cursor-size") then settings:set_int("cursor-size", 24) end
    if schema:has_key("enable-animations") and settings:is_writable("enable-animations") then
        settings:set_boolean("enable-animations", false)
    end
    Gio.Settings.sync()
end

return appearance
