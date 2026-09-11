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
    icon = iconpath .. "computation-core-mk1.png",
    small_icon = iconpath .. "computation-core-mk1.png",
    associated_control_input = PREFIX .. "control-center-hotkey",
}

data.extend({control_center_hotkey, control_center_shortcut})

-------------------------------------------------------------------------------
--------------------------------- GUI STYLES ----------------------------------
-------------------------------------------------------------------------------

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

-- Cluster IO table style
data.raw["gui-style"]["default"]["cluster_io_table"] = {
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
        {column = 1, width = 32},
        {column = 2, width = 204},
        {column = 3, width = 40},
        {column = 4, width = 40}
    },
}

-- Cluster IO table style
data.raw["gui-style"]["default"]["cluster_info_table"] = {
    type = "table_style",
    parent = "bordered_table",
    right_cell_padding = 8,
    column_alignments = {
        {column = 1, alignment = "left"},
        {column = 2, alignment = "left"},
    },
    column_widths = {
        {column = 1, width = 120},
        {column = 2, width = 236},
    },
}

-- Vsurface info table style
data.raw["gui-style"]["default"]["vsurface_info_table"] = {
    type = "table_style",
    parent = "bordered_table",
    right_cell_padding = 8,
    column_alignments = {
        {column = 1, alignment = "left"},
        {column = 2, alignment = "left"},
    },
    column_widths = {
        {column = 1, width = 140},
        {column = 2, width = 216},
    },
}

-- Compilation io table style
data.raw["gui-style"]["default"]["compilation_io_table"] = {
    type = "table_style",
    parent = "bordered_table",
    right_cell_padding = 8,
    column_alignments = {
        {column = 1, alignment = "center"},
        {column = 2, alignment = "center"},
        {column = 3, alignment = "center"},
        {column = 4, alignment = "center"},
        {column = 5, alignment = "center"},
    },
    column_widths = {
        {column = 1, width = 32},
        {column = 2, width = 66},
        {column = 3, width = 66},
        {column = 4, width = 66},
        {column = 5, width = 66},
    },
}

-- Validation report table style
data.raw["gui-style"]["default"]["validation_report_table"] = {
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
        {column = 1, width = 32},
        {column = 2, width = 80},
        {column = 3, width = 80},
        {column = 4, width = 124},
    },
}

-------------------------------------------------------------------------------
-------------------------------- ALERT SPRITES --------------------------------
-------------------------------------------------------------------------------

local alert_red = {
    type = "sprite",
    name = PREFIX .. "entity-config-alert-red",
    filename = iconpath .. "entity-config-alert-red.png",
    width = 64,
    height = 64,
    scale = 0.5
}

local alert_yellow = {
    type = "sprite",
    name = PREFIX .. "entity-config-alert-yellow",
    filename = iconpath .. "entity-config-alert-yellow.png",
    width = 64,
    height = 64,
    scale = 0.5
}

data.extend{alert_red, alert_yellow}