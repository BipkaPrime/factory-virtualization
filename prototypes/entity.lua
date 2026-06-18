local ICONPATH = "__factory-virtualization__/graphics/icons/"
local ENTITYPATH = "__factory-virtualization__/graphics/entity/"


local item_uplink = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 10000,
        stack_size_max = 10000,
    },
    name = "item-uplink",
    icon = ICONPATH.."item-uplink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "item-uplink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = ENTITYPATH..'item-uplink.png',
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
    name = "item-downlink",
    icon = ICONPATH.."item-downlink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "item-downlink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = ENTITYPATH..'item-downlink.png',
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
    name = "fluid-uplink",
    icon = ICONPATH.."fluid-uplink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "fluid-uplink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    pictures = {
        picture = {
            filename = ENTITYPATH..'fluid-uplink.png',
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
    name = "fluid-downlink",
    icon = ICONPATH.."fluid-downlink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "fluid-downlink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    pictures = {
        picture = {
            filename = ENTITYPATH..'fluid-downlink.png',
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
    name = "energy-uplink",
    icon = ICONPATH.."energy-uplink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "energy-uplink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = ENTITYPATH..'energy-uplink.png',
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
    name = "energy-downlink",
    icon = ICONPATH.."energy-downlink.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "energy-downlink"},
    collision_box = {{-2.7, -2.7}, {2.7, 2.7}},
    selection_box = {{-3, -3}, {3, 3}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = ENTITYPATH..'energy-downlink.png',
                width = 384,
                height = 384,
                scale = 0.5,
            }
        },
    }
}

data:extend({item_uplink, item_downlink, fluid_uplink, fluid_downlink, energy_uplink, energy_downlink})