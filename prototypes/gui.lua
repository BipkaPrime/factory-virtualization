local gui_names = require("scripts.gui.gui-names")
local iconpath = "__factory-virtualization__/graphics/icons/"


local dashboard_hotkey = {
    type = "custom-input",
    name = gui_names.prefix .. gui_names.dashboard_hotkey,
    key_sequence = "CONTROL + SPACE",
}

local dashboard_button = {
    type = "shortcut",
    name = gui_names.prefix .. gui_names.template_dashboard,
    action = "lua",
    icon = iconpath .. "template-dashboard.png",
    small_icon = iconpath .. "template-dashboard.png",
    associated_control_input = gui_names.prefix .. gui_names.dashboard_hotkey,
}

local surface_manager_hotkey = {
    type = "custom-input",
    name = gui_names.prefix .. gui_names.surface_manager_hotkey,
    key_sequence = "ALT + V",
}

local surface_manager_button = {
    type = "shortcut",
    name = gui_names.prefix .. gui_names.surface_manager,
    action = "lua",
    icon = iconpath .. "surface-manager.png",
    small_icon = iconpath .. "surface-manager.png",
    associated_control_input = gui_names.prefix .. gui_names.surface_manager_hotkey,
}

data.extend({dashboard_hotkey, dashboard_button, surface_manager_hotkey, surface_manager_button})