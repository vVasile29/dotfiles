local lgi = require("lgi")
local Gio, GLib = lgi.Gio, lgi.GLib
local machine_profile = {}

local function read(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local value = file:read("*a")
    file:close()
    return value and value:match("^%s*(.-)%s*$")
end

local function entries(path)
    local result = {}
    local iterator = Gio.File.new_for_path(path):enumerate_children(
        "standard::name", Gio.FileQueryInfoFlags.NONE)
    if not iterator then return result end
    while true do
        local info = iterator:next_file()
        if not info then break end
        result[#result + 1] = info:get_name()
    end
    iterator:close()
    table.sort(result)
    return result
end

function machine_profile.detect(sys_root)
    local root = (sys_root or "/sys") .. "/class/"
    local hardware = { batteries = {}, backlights = {} }
    for _, name in ipairs(entries(root .. "power_supply")) do
        local path = root .. "power_supply/" .. name .. "/"
        local kind = read(path .. "type")
        -- Ignore UPSes and batteries belonging to mice/keyboards/headsets.
        if kind == "Battery" and read(path .. "scope") ~= "Device"
            and read(path .. "present") ~= "0" and tonumber(read(path .. "capacity")) then
            hardware.batteries[#hardware.batteries + 1] = name
        elseif not hardware.ac and (kind == "Mains" or kind == "USB" or kind == "USB_C") then
            hardware.ac = name
        end
    end
    for _, name in ipairs(entries(root .. "backlight")) do
        local path = root .. "backlight/" .. name .. "/"
        if (tonumber(read(path .. "max_brightness")) or 0) > 0
            and tonumber(read(path .. "brightness")) then
            hardware.backlights[#hardware.backlights + 1] = name
        end
    end
    hardware.backlight = hardware.backlights[1]
    return hardware
end

local function validate(config)
    assert(type(config) == "table", "machine.lua must return a table")
    assert(config.profile == "desktop" or config.profile == "laptop",
        'profile must be "desktop" or "laptop"')
    local allowed = { profile = true, battery = true, brightness = true,
        compositor = true, monitor_script = true, app_rules = true }
    for key in pairs(config) do assert(allowed[key], "Unknown machine option: " .. tostring(key)) end
    for _, key in ipairs({ "battery", "brightness", "compositor" }) do
        assert(config[key] == nil or type(config[key]) == "boolean", key .. " must be a boolean")
    end
    assert(config.monitor_script == nil or config.monitor_script == false
        or (type(config.monitor_script) == "string" and config.monitor_script ~= ""),
        "monitor_script must be a path or false")
    assert(config.app_rules == nil or type(config.app_rules) == "table", "app_rules must be a list")
    for _, rule in ipairs(config.app_rules or {}) do
        assert(type(rule) == "table" and type(rule.properties) == "table"
            and (type(rule.rule) == "table" or type(rule.rule_any) == "table"),
            "Each app rule needs rule/rule_any and properties tables")
    end
end

function machine_profile.load(options)
    options = options or {}
    local directory = options.config_dir or require("gears").filesystem.get_configuration_dir()
    directory = directory:gsub("/+$", "")
    local selector = directory .. "/machine.lua"
    local selected, warning
    if read(selector) then
        local ok, result = pcall(function()
            local config = assert(loadfile(selector))()
            validate(config)
            return config
        end)
        if ok then selected = result else warning = tostring(result) end
    end

    -- No selector (or an invalid one): no laptop controls or output-specific actions.
    local name = selected and selected.profile or "desktop"
    local profile = assert(loadfile(directory .. "/profiles/" .. name .. ".lua"))()
    if selected then
        for key, value in pairs(selected) do
            if key ~= "profile" then profile[key] = value end
        end
    else
        profile.monitor_script, profile.app_rules, profile.compositor = false, {}, false
    end
    profile.name, profile.selected, profile.error = name, selected ~= nil, warning
    profile.hardware = machine_profile.detect(options.sys_root)
    local find_program = options.find_program or GLib.find_program_in_path
    profile.battery = profile.battery and #profile.hardware.batteries > 0
    profile.brightness = profile.brightness and profile.hardware.backlight ~= nil
        and find_program("brightnessctl") ~= nil
    if profile.monitor_script then
        local home = options.home or os.getenv("HOME")
        if profile.monitor_script:sub(1, 2) == "~/" then
            profile.monitor_script = home .. profile.monitor_script:sub(2)
        elseif profile.monitor_script:sub(1, 1) ~= "/" then
            profile.monitor_script = home .. "/" .. profile.monitor_script
        end
    end
    return profile
end

return machine_profile
