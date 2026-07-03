local iconpath = "__factory-virtualization__/graphics/icons/"
local entitypath = "__factory-virtualization__/graphics/entity/"
local names = require("scripts.gui.names")


local item_uplink = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 10000,
        stack_size_max = 10000,
    },
    name = names.prefix .. "item-uplink",
    icon = iconpath.."item-uplink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "item-uplink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath..'item-uplink.png',
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

local item_downlink = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 10000,
        stack_size_max = 10000,
    },
    name = names.prefix .. "item-downlink",
    icon = iconpath.."item-downlink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "item-downlink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath..'item-downlink.png',
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

local fluid_uplink = {
    type = "storage-tank",
    fluid_box = {
        volume = 10000000,
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
    name = names.prefix .. "fluid-uplink",
    icon = iconpath.."fluid-uplink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "fluid-uplink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    pictures = {
        picture = {
            filename = entitypath..'fluid-uplink.png',
                width = 384,
                height = 384,
                scale = 0.5,
        },
    }
}

local fluid_downlink = {
    type = "storage-tank",
    fluid_box = {
        volume = 10000000,
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
    name = names.prefix .. "fluid-downlink",
    icon = iconpath.."fluid-downlink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "fluid-downlink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    pictures = {
        picture = {
            filename = entitypath..'fluid-downlink.png',
                width = 384,
                height = 384,
                scale = 0.5,
        },
    }
}

local energy_uplink = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10GJ",
        usage_priority = "secondary-input",
        input_flow_limit = "1GW",
    },
    name = names.prefix .. "energy-uplink",
    icon = iconpath.."energy-uplink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "energy-uplink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath..'energy-uplink.png',
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

local energy_downlink = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10GJ",
        usage_priority = "primary-output",
        output_flow_limit = "1GW",
    },
    name = names.prefix .. "energy-downlink",
    icon = iconpath.."energy-downlink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "energy-downlink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath..'energy-downlink.png',
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

local virtualization_mainframe = {
    type = "logistic-container",
    name = names.prefix .. "virtualization-mainframe",
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
    minable = {mining_time = 0.1, result = "virtualization-mainframe"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    icon = iconpath .. "virtualization-mainframe.png",
    icon_size = 64,
    picture = {
        layers = {
            {
                filename = entitypath.."virtualization-mainframe.png",
                width = 768,
                height = 768,
                scale = 0.5,
            }
        },
    },
}

data:extend({
    item_uplink,
    item_downlink,
    fluid_uplink,
    fluid_downlink,
    energy_uplink,
    energy_downlink,
    virtualization_mainframe
})