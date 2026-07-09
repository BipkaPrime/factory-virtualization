local iconpath = "__factory-virtualization__/graphics/icons/"


local td_hotkey = {
    type = "custom-input",
    name = PREFIX .. "td-hotkey",
    key_sequence = "CONTROL + SPACE",
}

local td_shortcut = {
    type = "shortcut",
    name = PREFIX .. "td-shortcut",
    action = "lua",
    icon = iconpath .. "template-dashboard.png",
    small_icon = iconpath .. "template-dashboard.png",
    associated_control_input = PREFIX .. "td-hotkey",
}

local sm_hotkey = {
    type = "custom-input",
    name = PREFIX .. "sm-hotkey",
    key_sequence = "ALT + V",
}

local sm_shortcut = {
    type = "shortcut",
    name = PREFIX .. "sm-shortcut",
    action = "lua",
    icon = iconpath .. "surface-manager.png",
    small_icon = iconpath .. "surface-manager.png",
    associated_control_input = PREFIX .. "sm-hotkey",
}

data.extend({td_hotkey, td_shortcut, sm_hotkey, sm_shortcut})