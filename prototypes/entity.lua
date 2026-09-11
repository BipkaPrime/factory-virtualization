local iconpath = "__factory-virtualization__/graphics/icons/"
local entitypath = "__factory-virtualization__/graphics/entity/"

--TODO: add sounds, add death explosions.

-------------------------------------------------------------------------------
------------------------------ TEMPLATE SUBGROUP ------------------------------
-------------------------------------------------------------------------------

local template_control_center_mk1 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-control-center-mk1",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "9.6GJ",
        usage_priority = "primary-input",
        input_flow_limit = "9.6GW",
        output_flow_limit = "0W",
    },
    energy_usage = "4.8GW",
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-control-center-mk1"},
    surface_conditions = {
        {property = "solar-power", max = 1},
        {property = "magnetic-field", max = 10},
    },
    max_health = 2000,
    collision_box = {{-7.7, -7.7}, {7.7, 7.7}},
    selection_box = {{-8, -8}, {8, 8}},
    picture = {
        filename = entitypath .. "template-control-center-mk1.png",
        width = 1024,
        height = 1024,
        scale = 0.5,
    },
    icon = iconpath .. "template-control-center-mk1.png",
    icon_size = 64,
}

local template_control_center_mk2 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-control-center-mk2",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "96GJ",
        usage_priority = "primary-input",
        input_flow_limit = "96GW",
        output_flow_limit = "0W",
    },
    energy_usage = "48GW",
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-control-center-mk2"},
    surface_conditions = {
        {property = "solar-power", max = 1},
        {property = "magnetic-field", max = 10},
    },
    max_health = 2000,
    collision_box = {{-7.7, -7.7}, {7.7, 7.7}},
    selection_box = {{-8, -8}, {8, 8}},
    picture = {
        filename = entitypath .. "template-control-center-mk2.png",
        width = 1024,
        height = 1024,
        scale = 0.5,
    },
    icon = iconpath .. "template-control-center-mk2.png",
    icon_size = 64,
}

local template_control_center_mk3 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-control-center-mk3",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "960GJ",
        usage_priority = "primary-input",
        input_flow_limit = "960GW",
        output_flow_limit = "0W",
    },
    energy_usage = "480GW",
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-control-center-mk3"},
    surface_conditions = {
        {property = "solar-power", max = 1},
        {property = "magnetic-field", max = 10},
    },
    max_health = 2000,
    collision_box = {{-7.7, -7.7}, {7.7, 7.7}},
    selection_box = {{-8, -8}, {8, 8}},
    picture = {
        filename = entitypath .. "template-control-center-mk3.png",
        width = 1024,
        height = 1024,
        scale = 0.5,
    },
    icon = iconpath .. "template-control-center-mk3.png",
    icon_size = 64,
}

local template_computation_array_mk1 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-computation-array-mk1",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "2GJ",
        usage_priority = "primary-input",
        input_flow_limit = "2GW",
        output_flow_limit = "0W",
    },
    energy_usage = "30MW",
    surface_conditions = {
        {property = "solar-power", max = 1},
        {property = "magnetic-field", max = 10},
    },
    max_health = 500,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-computation-array-mk1"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        filename = entitypath .. "template-computation-array-mk1.png",
        width = 512,
        height = 512,
        scale = 0.5,
    },
    icon = iconpath .. "template-computation-array-mk1.png",
    icon_size = 64,
}

local template_computation_array_mk2 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-computation-array-mk2",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "20GJ",
        usage_priority = "primary-input",
        input_flow_limit = "20GW",
        output_flow_limit = "0W",
    },
    energy_usage = "300MW",
    surface_conditions = {
        {property = "solar-power", max = 1},
        {property = "magnetic-field", max = 10},
    },
    max_health = 500,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-computation-array-mk2"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        filename = entitypath .. "template-computation-array-mk2.png",
        width = 512,
        height = 512,
        scale = 0.5,
    },
    icon = iconpath .. "template-computation-array-mk2.png",
    icon_size = 64,
}

local template_computation_array_mk3 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-computation-array-mk3",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "200GJ",
        usage_priority = "primary-input",
        input_flow_limit = "200GW",
        output_flow_limit = "0W",
    },
    energy_usage = "3GW",
    surface_conditions = {
        {property = "solar-power", max = 1},
        {property = "magnetic-field", max = 10},
    },
    max_health = 500,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-computation-array-mk3"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        filename = entitypath .. "template-computation-array-mk3.png",
        width = 512,
        height = 512,
        scale = 0.5,
    },
    icon = iconpath .. "template-computation-array-mk3.png",
    icon_size = 64,
}

local template_access_interface_mk1 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-access-interface-mk1",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "2.4GJ",
        usage_priority = "primary-input",
        input_flow_limit = "2.4GW",
        output_flow_limit = "0W",
    },
    energy_usage = "1.2GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-access-interface-mk1"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-access-interface-mk1.png",
                width = 800,
                height = 800,
                scale = 0.5,
            },
            {
                filename = entitypath .. "template-access-interface-sh.png",
                width = 867,
                height = 626,
                scale = 0.5,
                shift = {x = 0.52, y = 1.3},
                draw_as_shadow = true,
            }
        },
    },
    icon = iconpath .. "template-access-interface-mk1.png",
    icon_size = 64,
}

local template_access_interface_mk2 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-access-interface-mk2",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "24GJ",
        usage_priority = "primary-input",
        input_flow_limit = "24GW",
        output_flow_limit = "0W",
    },
    energy_usage = "12GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-access-interface-mk2"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-access-interface-mk2.png",
                width = 800,
                height = 800,
                scale = 0.5,
            },
            {
                filename = entitypath .. "template-access-interface-sh.png",
                width = 867,
                height = 626,
                scale = 0.5,
                shift = {x = 0.52, y = 1.3},
                draw_as_shadow = true,
            }
        },
    },
    icon = iconpath .. "template-access-interface-mk2.png",
    icon_size = 64,
}

local template_access_interface_mk3 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-access-interface-mk3",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "240GJ",
        usage_priority = "primary-input",
        input_flow_limit = "240GW",
        output_flow_limit = "0W",
    },
    energy_usage = "120GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-access-interface-mk3"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-access-interface-mk3.png",
                width = 800,
                height = 800,
                scale = 0.5,
            },
            {
                filename = entitypath .. "template-access-interface-sh.png",
                width = 867,
                height = 626,
                scale = 0.5,
                shift = {x = 0.52, y = 1.3},
                draw_as_shadow = true,
            }
        },
    },
    icon = iconpath .. "template-access-interface-mk3.png",
    icon_size = 64,
}

data.extend{
    template_computation_array_mk1,
    template_computation_array_mk2,
    template_computation_array_mk3,
    template_control_center_mk1,
    template_control_center_mk2,
    template_control_center_mk3,
    template_access_interface_mk1,
    template_access_interface_mk2,
    template_access_interface_mk3,
}

-------------------------------------------------------------------------------
---------------------------- TEMPLATE IO SUBGROUP -----------------------------
-------------------------------------------------------------------------------

local template_item_io_mk1 = {
    type = "container",
    name = PREFIX .. "template-item-io-mk1",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 600,
        stack_size_max = 600,
    },
    inventory_size = 1,
    quality_affects_inventory_size = false,
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-item-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "template-item-io-mk1.png",
        width = 256,
        height = 256,
        scale = 0.5,
    },
    icon = iconpath .. "template-item-io-mk1.png",
    icon_size = 64,
}

local template_item_io_mk2 = {
    type = "container",
    name = PREFIX .. "template-item-io-mk2",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 6000,
        stack_size_max = 6000,
    },
    inventory_size = 1,
    quality_affects_inventory_size = false,
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-item-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "template-item-io-mk2.png",
        width = 256,
        height = 256,
        scale = 0.5,
    },
    icon = iconpath .. "template-item-io-mk2.png",
    icon_size = 64,
}

local template_item_io_mk3 = {
    type = "container",
    name = PREFIX .. "template-item-io-mk3",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 60000,
        stack_size_max = 60000,
    },
    inventory_size = 1,
    quality_affects_inventory_size = false,
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-item-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "template-item-io-mk3.png",
        width = 256,
        height = 256,
        scale = 0.5,
    },
    icon = iconpath .. "template-item-io-mk3.png",
    icon_size = 64,
}

local template_fluid_io_connections = {
    {direction = defines.direction.south, position = {1.5, 1.5}},
    {direction = defines.direction.south, position = {-1.5, 1.5}},
    {direction = defines.direction.north, position = {1.5, -1.5}},
    {direction = defines.direction.north, position = {-1.5, -1.5}},
    {direction = defines.direction.east, position = {1.5, 1.5}},
    {direction = defines.direction.east, position = {1.5, -1.5}},
    {direction = defines.direction.west, position = {-1.5, 1.5}},
    {direction = defines.direction.west, position = {-1.5, -1.5}},
}

local template_fluid_io_mk1 = {
    type = "storage-tank",
    name = PREFIX .. "template-fluid-io-mk1",
    fluid_box = {
        volume = 6000,
        pipe_connections = template_fluid_io_connections,
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-fluid-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    pictures = {
        picture = {
            filename = entitypath .. "template-fluid-io-mk1.png",
            width = 256,
            height = 256,
            scale = 0.5,
        }
    },
    icon = iconpath .. "template-fluid-io-mk1.png",
    icon_size = 64,
}

local template_fluid_io_mk2 = {
    type = "storage-tank",
    name = PREFIX .. "template-fluid-io-mk2",
    fluid_box = {
        volume = 60000,
        pipe_connections = template_fluid_io_connections,
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-fluid-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    pictures = {
        picture = {
            filename = entitypath .. "template-fluid-io-mk2.png",
            width = 256,
            height = 256,
            scale = 0.5,
        }
    },
    icon = iconpath .. "template-fluid-io-mk2.png",
    icon_size = 64,
}

local template_fluid_io_mk3 = {
    type = "storage-tank",
    name = PREFIX .. "template-fluid-io-mk3",
    fluid_box = {
        volume = 600000,
        pipe_connections = template_fluid_io_connections,
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-fluid-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    pictures = {
        picture = {
            filename = entitypath .. "template-fluid-io-mk3.png",
            width = 256,
            height = 256,
            scale = 0.5,
        }
    },
    icon = iconpath .. "template-fluid-io-mk3.png",
    icon_size = 64,
}

local template_energy_io_mk1 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-energy-io-mk1",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "1.2GJ",
        input_flow_limit = "600MW",
        output_flow_limit = "600MW",
        usage_priority = "dynamic",
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-energy-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "template-energy-io-mk1.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "template-energy-io-mk1.png",
    icon_size = 64,
}

local template_energy_io_mk2 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-energy-io-mk2",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "12GJ",
        input_flow_limit = "6GW",
        output_flow_limit = "6GW",
        usage_priority = "dynamic",
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-energy-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "template-energy-io-mk2.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "template-energy-io-mk2.png",
    icon_size = 64,
}

local template_energy_io_mk3 = {
    type = "electric-energy-interface",
    name = PREFIX .. "template-energy-io-mk3",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "120GJ",
        input_flow_limit = "60GW",
        output_flow_limit = "60GW",
        usage_priority = "dynamic",
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-energy-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "template-energy-io-mk3.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "template-energy-io-mk3.png",
    icon_size = 64,
}

data.extend{
    template_item_io_mk1,
	template_item_io_mk2,
	template_item_io_mk3,
	template_fluid_io_mk1,
	template_fluid_io_mk2,
	template_fluid_io_mk3,
	template_energy_io_mk1,
	template_energy_io_mk2,
	template_energy_io_mk3,
}

-------------------------------------------------------------------------------
-------------------------- CLUSTER MEMBERS SUBGROUP ---------------------------
-------------------------------------------------------------------------------

local virtualization_mainframe_mk1 = {
    type = "logistic-container",
    name = PREFIX .. "virtualization-mainframe-mk1",
    logistic_mode = "requester",
    trash_inventory_size = 30,
    render_not_in_network_icon = true,
    use_exact_mode = true,
    inventory_size = 30,
    quality_affects_inventory_size = false,
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e5,
        stack_size_max = 1e5,
    },
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "virtualization-mainframe-mk1"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "virtualization-mainframe-mk1.png",
        width = 1024,
        height = 1024,
        scale = 0.45,
        shift = {x = 1.5, y = -0.5}
    },
    icon = iconpath .. "virtualization-mainframe-mk1.png",
    icon_size = 64,
}

local virtualization_mainframe_mk2 = {
    type = "logistic-container",
    name = PREFIX .. "virtualization-mainframe-mk2",
    logistic_mode = "requester",
    trash_inventory_size = 30,
    render_not_in_network_icon = true,
    use_exact_mode = true,
    inventory_size = 30,
    quality_affects_inventory_size = false,
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e5,
        stack_size_max = 1e5,
    },
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "virtualization-mainframe-mk2"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "virtualization-mainframe-mk2.png",
        width = 1024,
        height = 1024,
        scale = 0.45,
        shift = {x = 1.5, y = -0.5}
    },
    icon = iconpath .. "virtualization-mainframe-mk2.png",
    icon_size = 64,
}

local virtualization_mainframe_mk3 = {
    type = "logistic-container",
    name = PREFIX .. "virtualization-mainframe-mk3",
    logistic_mode = "requester",
    trash_inventory_size = 30,
    render_not_in_network_icon = true,
    use_exact_mode = true,
    inventory_size = 30,
    quality_affects_inventory_size = false,
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e5,
        stack_size_max = 1e5,
    },
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "virtualization-mainframe-mk3"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "virtualization-mainframe-mk3.png",
        width = 1024,
        height = 1024,
        scale = 0.45,
        shift = {x = 1.5, y = -0.5}
    },
    icon = iconpath .. "virtualization-mainframe-mk3.png",
    icon_size = 64,
}

local cluster_storage_unit_mk1 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-storage-unit-mk1",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        usage_priority = "primary-input",
        buffer_capacity = "480MJ",
        input_flow_limit = "480MW",
        output_flow_limit = "0W",
    },
    energy_usage = "240MW",
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-storage-unit-mk1"},
    collision_box = {{-3.2, -2.7}, {3.2, 2.7}},
    selection_box = {{-3.5, -3}, {3.5, 3}},
    picture = {
        filename = entitypath .. "cluster-storage-unit-mk1.png",
        width = 512,
        height = 512,
        scale = 0.5,
        shift = {x = -0.12, y = 0}
    },
    icon = iconpath .. "cluster-storage-unit-mk1.png",
    icon_size = 64,
}

local cluster_storage_unit_mk2 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-storage-unit-mk2",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        usage_priority = "primary-input",
        buffer_capacity = "4.8GJ",
        input_flow_limit = "4.8GW",
        output_flow_limit = "0W",
    },
    energy_usage = "2.4GW",
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-storage-unit-mk2"},
    collision_box = {{-3.2, -2.7}, {3.2, 2.7}},
    selection_box = {{-3.5, -3}, {3.5, 3}},
    picture = {
        filename = entitypath .. "cluster-storage-unit-mk2.png",
        width = 512,
        height = 512,
        scale = 0.5,
        shift = {x = -0.12, y = 0}
    },
    icon = iconpath .. "cluster-storage-unit-mk2.png",
    icon_size = 64,
}

local cluster_storage_unit_mk3 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-storage-unit-mk3",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        usage_priority = "primary-input",
        buffer_capacity = "48GJ",
        input_flow_limit = "48GW",
        output_flow_limit = "0W",
    },
    energy_usage = "24GW",
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-storage-unit-mk3"},
    collision_box = {{-3.2, -2.7}, {3.2, 2.7}},
    selection_box = {{-3.5, -3}, {3.5, 3}},
    picture = {
        filename = entitypath .. "cluster-storage-unit-mk3.png",
        width = 512,
        height = 512,
        scale = 0.5,
        shift = {x = -0.12, y = 0}
    },
    icon = iconpath .. "cluster-storage-unit-mk3.png",
    icon_size = 64,
}

data.extend{
    virtualization_mainframe_mk1,
    virtualization_mainframe_mk2,
    virtualization_mainframe_mk3,
    cluster_storage_unit_mk1,
    cluster_storage_unit_mk2,
    cluster_storage_unit_mk3,
}

-------------------------------------------------------------------------------
------------------------- SIMPLE CLUSTER IO SUBGROUP --------------------------
-------------------------------------------------------------------------------

local cluster_item_io_mk1 = {
    type = "container",
    name = PREFIX .. "cluster-item-io-mk1",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 600,
        stack_size_max = 600,
    },
    quality_affects_inventory_size = false,
    inventory_size = 1,
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-item-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "cluster-item-io-mk1.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "cluster-item-io-mk1.png",
    icon_size = 64,
}

local cluster_item_io_mk2 = {
    type = "container",
    name = PREFIX .. "cluster-item-io-mk2",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 6000,
        stack_size_max = 6000,
    },
    quality_affects_inventory_size = false,
    inventory_size = 1,
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-item-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "cluster-item-io-mk2.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "cluster-item-io-mk2.png",
    icon_size = 64,
}

local cluster_item_io_mk3 = {
    type = "container",
    name = PREFIX .. "cluster-item-io-mk3",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 60000,
        stack_size_max = 60000,
    },
    quality_affects_inventory_size = false,
    inventory_size = 1,
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-item-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "cluster-item-io-mk3.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "cluster-item-io-mk3.png",
    icon_size = 64,
}

local cluster_fluid_io_pipe_connections = {
    {direction = defines.direction.south, position = {1.5, 1.5}},
    {direction = defines.direction.south, position = {-1.5, 1.5}},
    {direction = defines.direction.north, position = {1.5, -1.5}},
    {direction = defines.direction.north, position = {-1.5, -1.5}},
    {direction = defines.direction.east, position = {1.5, 1.5}},
    {direction = defines.direction.east, position = {1.5, -1.5}},
    {direction = defines.direction.west, position = {-1.5, 1.5}},
    {direction = defines.direction.west, position = {-1.5, -1.5}},
}

local cluster_fluid_io_mk1 = {
    type = "storage-tank",
    name = PREFIX .. "cluster-fluid-io-mk1",
    fluid_box = {
        volume = 6000,
        pipe_connections = cluster_fluid_io_pipe_connections,
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-fluid-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    pictures = {
        picture = {
            filename = entitypath .. "cluster-fluid-io-mk1.png",
            width = 512,
            height = 512,
            scale = 0.25,
        },
    },
    icon = iconpath .. "cluster-fluid-io-mk1.png",
    icon_size = 64,
}

local cluster_fluid_io_mk2 = {
    type = "storage-tank",
    name = PREFIX .. "cluster-fluid-io-mk2",
    fluid_box = {
        volume = 60000,
        pipe_connections = cluster_fluid_io_pipe_connections,
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-fluid-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    pictures = {
        picture = {
            filename = entitypath .. "cluster-fluid-io-mk2.png",
            width = 512,
            height = 512,
            scale = 0.25,
        },
    },
    icon = iconpath .. "cluster-fluid-io-mk2.png",
    icon_size = 64,
}

local cluster_fluid_io_mk3 = {
    type = "storage-tank",
    name = PREFIX .. "cluster-fluid-io-mk3",
    fluid_box = {
        volume = 600000,
        pipe_connections = cluster_fluid_io_pipe_connections,
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-fluid-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    pictures = {
        picture = {
            filename = entitypath .. "cluster-fluid-io-mk3.png",
            width = 512,
            height = 512,
            scale = 0.25,
        },
    },
    icon = iconpath .. "cluster-fluid-io-mk3.png",
    icon_size = 64,
}

local cluster_energy_io_mk1 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-energy-io-mk1",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "1.2GJ",
        input_flow_limit = "600MW",
        output_flow_limit = "600MW",
        usage_priority = "dynamic",
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-energy-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "cluster-energy-io-mk1.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "cluster-energy-io-mk1.png",
    icon_size = 64,
}

local cluster_energy_io_mk2 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-energy-io-mk2",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "12GJ",
        input_flow_limit = "6GW",
        output_flow_limit = "6GW",
        usage_priority = "dynamic",
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-energy-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "cluster-energy-io-mk2.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "cluster-energy-io-mk2.png",
    icon_size = 64,
}

local cluster_energy_io_mk3 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-energy-io-mk3",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "120GJ",
        input_flow_limit = "60GW",
        output_flow_limit = "60GW",
        usage_priority = "dynamic",
    },
    max_health = 300,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-energy-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        filename = entitypath .. "cluster-energy-io-mk3.png",
        width = 512,
        height = 512,
        scale = 0.25,
    },
    icon = iconpath .. "cluster-energy-io-mk3.png",
    icon_size = 64,
}

data.extend{
    cluster_item_io_mk1,
	cluster_item_io_mk2,
	cluster_item_io_mk3,
	cluster_fluid_io_mk1,
	cluster_fluid_io_mk2,
	cluster_fluid_io_mk3,
	cluster_energy_io_mk1,
	cluster_energy_io_mk2,
	cluster_energy_io_mk3,
}

-------------------------------------------------------------------------------
------------------------ ADVANCED CLUSTER IO SUBGROUP -------------------------
-------------------------------------------------------------------------------

local inter_cluster_bridge_mk1 = {
    type = "electric-energy-interface",
    name = PREFIX .. "inter-cluster-bridge-mk1",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "4.8GJ",
        usage_priority = "primary-input",
        input_flow_limit = "4.8GW",
        output_flow_limit = "0W",
    },
    energy_usage = "2.4GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "inter-cluster-bridge-mk1"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "inter-cluster-bridge-mk1.png",
        width = 1024,
        height = 1024,
        scale = 0.45,
        shift = {x = 0.8, y = -0.5},
    },
    icon = iconpath .. "inter-cluster-bridge-mk1.png",
    icon_size = 64,
}

local inter_cluster_bridge_mk2 = {
    type = "electric-energy-interface",
    name = PREFIX .. "inter-cluster-bridge-mk2",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "48GJ",
        usage_priority = "primary-input",
        input_flow_limit = "48GW",
        output_flow_limit = "0W",
    },
    energy_usage = "24GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "inter-cluster-bridge-mk2"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "inter-cluster-bridge-mk2.png",
        width = 1024,
        height = 1024,
        scale = 0.45,
        shift = {x = 0.8, y = -0.5},
    },
    icon = iconpath .. "inter-cluster-bridge-mk2.png",
    icon_size = 64,
}

local inter_cluster_bridge_mk3 = {
    type = "electric-energy-interface",
    name = PREFIX .. "inter-cluster-bridge-mk3",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "480GJ",
        usage_priority = "primary-input",
        input_flow_limit = "480GW",
        output_flow_limit = "0W",
    },
    energy_usage = "240GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "inter-cluster-bridge-mk3"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "inter-cluster-bridge-mk3.png",
        width = 1024,
        height = 1024,
        scale = 0.45,
        shift = {x = 0.8, y = -0.5},
    },
    icon = iconpath .. "inter-cluster-bridge-mk3.png",
    icon_size = 64,
}

local cluster_overflow_controller_mk1 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-overflow-controller-mk1",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "4.8GJ",
        usage_priority = "primary-input",
        input_flow_limit = "4.8GW",
        output_flow_limit = "0W",
    },
    energy_usage = "2.4GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-overflow-controller-mk1"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "cluster-overflow-controller-mk1.png",
        width = 1024,
        height = 1024,
        scale = 0.375,
    },
    icon = iconpath .. "cluster-overflow-controller-mk1.png",
    icon_size = 64,
}

local cluster_overflow_controller_mk2 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-overflow-controller-mk2",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "48GJ",
        usage_priority = "primary-input",
        input_flow_limit = "48GW",
        output_flow_limit = "0W",
    },
    energy_usage = "24GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-overflow-controller-mk2"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "cluster-overflow-controller-mk2.png",
        width = 1024,
        height = 1024,
        scale = 0.375,
    },
    icon = iconpath .. "cluster-overflow-controller-mk2.png",
    icon_size = 64,
}

local cluster_overflow_controller_mk3 = {
    type = "electric-energy-interface",
    name = PREFIX .. "cluster-overflow-controller-mk3",
    gui_mode = "all",
    -- allow_copy_paste = true,
    energy_source = {
        type = "electric",
        buffer_capacity = "480GJ",
        usage_priority = "primary-input",
        input_flow_limit = "480GW",
        output_flow_limit = "0W",
    },
    energy_usage = "240GW",
    max_health = 1000,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-overflow-controller-mk3"},
    collision_box = {{-5.7, -5.7}, {5.7, 5.7}},
    selection_box = {{-6, -6}, {6, 6}},
    picture = {
        filename = entitypath .. "cluster-overflow-controller-mk3.png",
        width = 1024,
        height = 1024,
        scale = 0.375,
    },
    icon = iconpath .. "cluster-overflow-controller-mk3.png",
    icon_size = 64,
}

data.extend{
    inter_cluster_bridge_mk1,
    inter_cluster_bridge_mk2,
    inter_cluster_bridge_mk3,
    cluster_overflow_controller_mk1,
    cluster_overflow_controller_mk2,
    cluster_overflow_controller_mk3,
}