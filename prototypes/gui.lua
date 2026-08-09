local iconpath = "__factory-virtualization__/graphics/icons/"


local control_center_hotkey = {
    type = "custom-input",
    name = PREFIX .. "control-center-hotkey",
    key_sequence = "CONTROL + SPACE",
}

local control_center_shortcut = {
    type = "shortcut",
    name = PREFIX .. "control-center-shortcut",
    action = "lua",
    icon = iconpath .. "control-center-shortcut.png",
    small_icon = iconpath .. "control-center-shortcut.png",
    associated_control_input = PREFIX .. "control-center-hotkey",
}

data.extend({control_center_hotkey, control_center_shortcut})