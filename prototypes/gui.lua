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

-- Template routing table style
data.raw["gui-style"]["default"]["template_routing_table"] = {
    type = "table_style",
    parent = "bordered_table",
    right_cell_padding = 8,
    column_alignments = {
        {column = 1, alignment = "left"},
        {column = 2, alignment = "center"},
        {column = 3, alignment = "center"},
    },
    column_widths = {
      {column = 1, width = 216},
      {column = 2, width = 60},
      {column = 3, width = 60}
    },
}

-- Cluster members table style
data.raw["gui-style"]["default"]["cluster_members_table"] = {
    type = "table_style",
    parent = "bordered_table",
    right_cell_padding = 8,
    column_alignments = {
        {column = 1, alignment = "center"},
        {column = 2, alignment = "center"},
        {column = 3, alignment = "center"},
        {column = 4, alignment = "center"},
    },
    column_widths = {
      {column = 1, width = 50},
      {column = 2, width = 70},
      {column = 3, width = 70},
      {column = 4, width = 126}
    },
}