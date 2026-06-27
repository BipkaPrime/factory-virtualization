local names = require("scripts.gui-v2.names")
local iconpath = "__factory-virtualization__/graphics/icons/"

--[[
local dashboard_hotkey = {
    type = "custom-input",
    name = names.prefix .. names.dashboard_hotkey,
    key_sequence = "CONTROL + SPACE",
}

local dashboard_button = {
    type = "shortcut",
    name = names.prefix .. names.template_dashboard,
    action = "lua",
    icon = iconpath .. "template-dashboard.png",
    small_icon = iconpath .. "template-dashboard.png",
    associated_control_input = names.prefix .. names.dashboard_hotkey,
}
--]]

local sm_hotkey = {
    type = "custom-input",
    name = names.prefix .. names.sm_hotkey,
    key_sequence = "ALT + V",
}

local sm_shortcut = {
    type = "shortcut",
    name = names.prefix .. names.sm_shortcut,
    action = "lua",
    icon = iconpath .. "surface-manager.png",
    small_icon = iconpath .. "surface-manager.png",
    associated_control_input = names.prefix .. names.sm_hotkey,
}

data.extend({sm_hotkey, sm_shortcut})