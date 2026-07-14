local iconpath = "__factory-virtualization__/graphics/icons/"
local entitypath = "__factory-virtualization__/graphics/entity/"


local mainframe_item_io = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 10000,
        stack_size_max = 10000,
    },
    name = PREFIX .. "mainframe-item-io",
    icon = iconpath .. "mainframe-item-io.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = PREFIX .. "mainframe-item-io"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath .. "mainframe-item-io.png",
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

local template_item_io = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 10000,
        stack_size_max = 10000,
    },
    name = PREFIX .. "template-item-io",
    icon = iconpath .. "template-item-io.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = PREFIX .. "template-item-io"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath .. "template-item-io.png",
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

local mainframe_fluid_io = {
    type = "storage-tank",
    fluid_box = {
        volume = 100000,
        pipe_connections = {
            {direction = defines.direction.south, position = {1.5, 2.5}},
            {direction = defines.direction.south, position = {-1.5, 2.5}},
            {direction = defines.direction.north, position = {1.5, -2.5}},
            {direction = defines.direction.north, position = {-1.5, -2.5}},
            {direction = defines.direction.east, position = {2.5, 1.5}},
            {direction = defines.direction.east, position = {2.5, -1.5}},
            {direction = defines.direction.west, position = {-2.5, 1.5}},
            {direction = defines.direction.west, position = {-2.5, -1.5}},
        },
    },
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    name = PREFIX .. "mainframe-fluid-io",
    icon = iconpath .. "mainframe-fluid-io.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = PREFIX .. "mainframe-fluid-io"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    pictures = {
        picture = {
            filename = entitypath .. "mainframe-fluid-io.png",
                width = 384,
                height = 384,
                scale = 0.5,
        },
    }
}

local template_fluid_io = {
    type = "storage-tank",
    fluid_box = {
        volume = 100000,
        pipe_connections = {
            {direction = defines.direction.south, position = {1.5, 2.5}},
            {direction = defines.direction.south, position = {-1.5, 2.5}},
            {direction = defines.direction.north, position = {1.5, -2.5}},
            {direction = defines.direction.north, position = {-1.5, -2.5}},
            {direction = defines.direction.east, position = {2.5, 1.5}},
            {direction = defines.direction.east, position = {2.5, -1.5}},
            {direction = defines.direction.west, position = {-2.5, 1.5}},
            {direction = defines.direction.west, position = {-2.5, -1.5}},
        },
    },
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    name = PREFIX .. "template-fluid-io",
    icon = iconpath .. "template-fluid-io.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = PREFIX .. "template-fluid-io"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    pictures = {
        picture = {
            filename = entitypath .. "template-fluid-io.png",
                width = 384,
                height = 384,
                scale = 0.5,
        },
    }
}

local template_energy_io = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10GJ",
        usage_priority = "dynamic",
    },
    name = PREFIX .. "template-energy-io",
    icon = iconpath .. "template-energy-io.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = PREFIX .. "template-energy-io"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath .. "template-energy-io.png",
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

local mainframe_energy_io = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10GJ",
        usage_priority = "dynamic",
    },
    name = PREFIX .. "mainframe-energy-io",
    icon = iconpath .. "mainframe-energy-io.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = PREFIX .. "mainframe-energy-io"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath .. "mainframe-energy-io.png",
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

local virtualization_mainframe = {
    type = "logistic-container",
    name = PREFIX .. "virtualization-mainframe",
    logistic_mode = "requester",
    trash_inventory_size = 32,
    render_not_in_network_icon = true,
    use_exact_mode = true,
    inventory_size = 32,
    quality_affects_inventory_size = false,
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 100000,
        stack_size_max = 100000,
    },
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = PREFIX .. "virtualization-mainframe"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    icon = iconpath .. "virtualization-mainframe.png",
    icon_size = 64,
    picture = {
        layers = {
            {
                filename = entitypath .. "virtualization-mainframe.png",
                width = 768,
                height = 768,
                scale = 0.5,
            }
        },
    },
}

data:extend({
    template_item_io,
    template_fluid_io,
    template_energy_io,
    mainframe_item_io,
    mainframe_fluid_io,
    mainframe_energy_io,
    virtualization_mainframe,
})