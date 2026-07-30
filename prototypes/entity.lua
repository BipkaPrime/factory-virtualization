local iconpath = "__factory-virtualization__/graphics/icons/"
local entitypath = "__factory-virtualization__/graphics/entity/"

-------------------------------------------------------------------------------
-- SIMPLE CLUSTER IO SUBGROUP
-------------------------------------------------------------------------------

local cluster_item_io_mk1 = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e4,
        stack_size_max = 1e4,
    },
    quality_affects_inventory_size = false,
    name = PREFIX .. "cluster-item-io-mk1",
    icon = iconpath .. "cluster-item-io-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-item-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-item-io-mk1.png",
                width = 256,
                height = 256,
                scale = 0.5,
            }
        },
    }
}

local cluster_item_io_mk2 = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e5,
        stack_size_max = 1e5,
    },
    quality_affects_inventory_size = false,
    name = PREFIX .. "cluster-item-io-mk2",
    icon = iconpath .. "cluster-item-io-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-item-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-item-io-mk2.png",
                width = 256,
                height = 256,
                scale = 0.5,
            }
        },
    }
}

local cluster_item_io_mk3 = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e6,
        stack_size_max = 1e6,
    },
    quality_affects_inventory_size = false,
    name = PREFIX .. "cluster-item-io-mk3",
    icon = iconpath .. "cluster-item-io-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-item-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    inventory_size = 1,
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-item-io-mk3.png",
                width = 256,
                height = 256,
                scale = 0.5,
            }
        },
    }
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
    fluid_box = {
        volume = 1e5,
        pipe_connections = cluster_fluid_io_pipe_connections,
    },
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    name = PREFIX .. "cluster-fluid-io-mk1",
    icon = iconpath .. "cluster-fluid-io-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-fluid-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    pictures = {
        picture = {
            filename = entitypath .. "cluster-fluid-io-mk1.png",
            width = 256,
            height = 256,
            scale = 0.5,
        },
    }
}

local cluster_fluid_io_mk2 = {
    type = "storage-tank",
    fluid_box = {
        volume = 1e6,
        pipe_connections = cluster_fluid_io_pipe_connections,
    },
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    name = PREFIX .. "cluster-fluid-io-mk2",
    icon = iconpath .. "cluster-fluid-io-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-fluid-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    pictures = {
        picture = {
            filename = entitypath .. "cluster-fluid-io-mk2.png",
            width = 256,
            height = 256,
            scale = 0.5,
        },
    }
}

local cluster_fluid_io_mk3 = {
    type = "storage-tank",
    fluid_box = {
        volume = 1e7,
        pipe_connections = cluster_fluid_io_pipe_connections,
    },
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    name = PREFIX .. "cluster-fluid-io-mk3",
    icon = iconpath .. "cluster-fluid-io-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-fluid-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    pictures = {
        picture = {
            filename = entitypath .. "cluster-fluid-io-mk3.png",
            width = 256,
            height = 256,
            scale = 0.5,
        },
    }
}

local cluster_energy_io_mk1 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10GJ",
        usage_priority = "tertiary",
    },
    name = PREFIX .. "cluster-energy-io-mk1",
    icon = iconpath .. "cluster-energy-io-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-energy-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-energy-io-mk1.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    }
}

local cluster_energy_io_mk2 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "100GJ",
        usage_priority = "tertiary",
    },
    name = PREFIX .. "cluster-energy-io-mk2",
    icon = iconpath .. "cluster-energy-io-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-energy-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-energy-io-mk2.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    }
}

local cluster_energy_io_mk3 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "1000GJ",
        usage_priority = "tertiary",
    },
    name = PREFIX .. "cluster-energy-io-mk3",
    icon = iconpath .. "cluster-energy-io-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-energy-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-energy-io-mk3.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    }
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
-- ADVANCED CLUSTER IO SUBGROUP
-------------------------------------------------------------------------------

local inter_cluster_bridge_mk1 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10TJ",
        usage_priority = "primary-input",
    },
    name = PREFIX .. "inter-cluster-bridge-mk1",
    icon = iconpath .. "inter-cluster-bridge-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "inter-cluster-bridge-mk1"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "inter-cluster-bridge-mk1.png",
                width = 512,
                height = 512,
                scale = 0.5,
            }
        },
    }
}

local inter_cluster_bridge_mk2 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10TJ",
        usage_priority = "primary-input",
    },
    name = PREFIX .. "inter-cluster-bridge-mk2",
    icon = iconpath .. "inter-cluster-bridge-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "inter-cluster-bridge-mk2"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "inter-cluster-bridge-mk2.png",
                width = 512,
                height = 512,
                scale = 0.5,
            }
        },
    }
}

local inter_cluster_bridge_mk3 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10TJ",
        usage_priority = "primary-input",
    },
    name = PREFIX .. "inter-cluster-bridge-mk3",
    icon = iconpath .. "inter-cluster-bridge-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "inter-cluster-bridge-mk3"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "inter-cluster-bridge-mk3.png",
                width = 512,
                height = 512,
                scale = 0.5,
            }
        },
    }
}

local cluster_overflow_controller_mk1 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10GJ",
        usage_priority = "primary-input",
        drain = "100MW",
    },
    name = PREFIX .. "cluster-overflow-controller-mk1",
    icon = iconpath .. "cluster-overflow-controller-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-overflow-controller-mk1"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-overflow-controller-mk1.png",
                width = 1024,
                height = 1024,
                scale = 0.25,
            }
        },
    }
}

local cluster_overflow_controller_mk2 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "100GJ",
        usage_priority = "primary-input",
        drain = "1GW",
    },
    name = PREFIX .. "cluster-overflow-controller-mk2",
    icon = iconpath .. "cluster-overflow-controller-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-overflow-controller-mk2"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-overflow-controller-mk2.png",
                width = 1024,
                height = 1024,
                scale = 0.25,
            }
        },
    }
}

local cluster_overflow_controller_mk3 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "1TJ",
        usage_priority = "primary-input",
        drain = "10GW",
    },
    name = PREFIX .. "cluster-overflow-controller-mk3",
    icon = iconpath .. "cluster-overflow-controller-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-overflow-controller-mk3"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-overflow-controller-mk3.png",
                width = 1024,
                height = 1024,
                scale = 0.25,
            }
        },
    }
}

data.extend{
    inter_cluster_bridge_mk1,
    inter_cluster_bridge_mk2,
    inter_cluster_bridge_mk3,
    cluster_overflow_controller_mk1,
    cluster_overflow_controller_mk2,
    cluster_overflow_controller_mk3,
}

-------------------------------------------------------------------------------
-- CLUSTER MEMBERS SUBGROUP
-------------------------------------------------------------------------------

local virtualization_mainframe_mk1 = {
    type = "logistic-container",
    name = PREFIX .. "virtualization-mainframe-mk1",
    logistic_mode = "requester",
    trash_inventory_size = 30,
    render_not_in_network_icon = true,
    use_exact_mode = true,
    inventory_size = 50,
    quality_affects_inventory_size = false,
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e6,
        stack_size_max = 1e6,
    },
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "virtualization-mainframe-mk1"},
    collision_box = {{-7.7, -7.7}, {7.7, 7.7}},
    selection_box = {{-8, -8}, {8, 8}},
    icon = iconpath .. "virtualization-mainframe-mk1.png",
    icon_size = 64,
    picture = {
        layers = {
            {
                filename = entitypath .. "virtualization-mainframe-mk1.png",
                width = 1024,
                height = 1024,
                scale = 0.5,
            }
        },
    },
}

local virtualization_mainframe_mk2 = {
    type = "logistic-container",
    name = PREFIX .. "virtualization-mainframe-mk2",
    logistic_mode = "requester",
    trash_inventory_size = 30,
    render_not_in_network_icon = true,
    use_exact_mode = true,
    inventory_size = 50,
    quality_affects_inventory_size = false,
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e6,
        stack_size_max = 1e6,
    },
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "virtualization-mainframe-mk2"},
    collision_box = {{-7.7, -7.7}, {7.7, 7.7}},
    selection_box = {{-8, -8}, {8, 8}},
    icon = iconpath .. "virtualization-mainframe-mk2.png",
    icon_size = 64,
    picture = {
        layers = {
            {
                filename = entitypath .. "virtualization-mainframe-mk2.png",
                width = 1024,
                height = 1024,
                scale = 0.5,
            }
        },
    },
}

local virtualization_mainframe_mk3 = {
    type = "logistic-container",
    name = PREFIX .. "virtualization-mainframe-mk3",
    logistic_mode = "requester",
    trash_inventory_size = 30,
    render_not_in_network_icon = true,
    use_exact_mode = true,
    inventory_size = 50,
    quality_affects_inventory_size = false,
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e6,
        stack_size_max = 1e6,
    },
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "virtualization-mainframe-mk3"},
    collision_box = {{-7.7, -7.7}, {7.7, 7.7}},
    selection_box = {{-8, -8}, {8, 8}},
    icon = iconpath .. "virtualization-mainframe-mk3.png",
    icon_size = 64,
    picture = {
        layers = {
            {
                filename = entitypath .. "virtualization-mainframe-mk3.png",
                width = 1024,
                height = 1024,
                scale = 0.5,
            }
        },
    },
}

local cluster_storage_unit_mk1 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10GJ",
        usage_priority = "primary-input",
        drain = "100MW",
    },
    name = PREFIX .. "cluster-storage-unit-mk1",
    icon = iconpath .. "cluster-storage-unit-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-storage-unit-mk1"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-storage-unit-mk1.png",
                width = 512,
                height = 512,
                scale = 0.5,
            }
        },
    }
}

local cluster_storage_unit_mk2 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "100GJ",
        usage_priority = "primary-input",
        drain = "1GW",
    },
    name = PREFIX .. "cluster-storage-unit-mk2",
    icon = iconpath .. "cluster-storage-unit-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-storage-unit-mk2"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-storage-unit-mk2.png",
                width = 512,
                height = 512,
                scale = 0.5,
            }
        },
    }
}

local cluster_storage_unit_mk3 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "1TJ",
        usage_priority = "primary-input",
        drain = "10GW",
    },
    name = PREFIX .. "cluster-storage-unit-mk3",
    icon = iconpath .. "cluster-storage-unit-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "cluster-storage-unit-mk3"},
    collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
    selection_box = {{-4, -4}, {4, 4}},
    picture = {
        layers = {
            {
                filename = entitypath .. "cluster-storage-unit-mk3.png",
                width = 512,
                height = 512,
                scale = 0.5,
            }
        },
    }
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
-- TEMPLATE IO SUBGROUP
-------------------------------------------------------------------------------

local template_item_io_mk1 = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e4,
        stack_size_max = 1e4,
    },
    inventory_size = 1,
    quality_affects_inventory_size = false,
    name = PREFIX .. "template-item-io-mk1",
    icon = iconpath .. "template-item-io-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-item-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-item-io-mk1.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    }
}

local template_item_io_mk2 = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e5,
        stack_size_max = 1e5,
    },
    inventory_size = 1,
    quality_affects_inventory_size = false,
    name = PREFIX .. "template-item-io-mk2",
    icon = iconpath .. "template-item-io-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-item-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-item-io-mk2.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    }
}

local template_item_io_mk3 = {
    type = "container",
    inventory_type = "with_custom_stack_size",
    inventory_properties = {
        stack_size_min = 1e4,
        stack_size_max = 1e4,
    },
    inventory_size = 1,
    quality_affects_inventory_size = false,
    name = PREFIX .. "template-item-io-mk3",
    icon = iconpath .. "template-item-io-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-item-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-item-io-mk3.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    }
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
    fluid_box = {
        volume = 1e5,
        pipe_connections = template_fluid_io_connections,
    },
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    name = PREFIX .. "template-fluid-io-mk1",
    icon = iconpath .. "template-fluid-io-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-fluid-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    pictures = {
        picture = {
            filename = entitypath .. "template-fluid-io-mk1.png",
                width = 512,
                height = 512,
                scale = 0.25,
        },
    }
}

local template_fluid_io_mk2 = {
    type = "storage-tank",
    fluid_box = {
        volume = 1e6,
        pipe_connections = template_fluid_io_connections,
    },
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    name = PREFIX .. "template-fluid-io-mk2",
    icon = iconpath .. "template-fluid-io-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-fluid-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    pictures = {
        picture = {
            filename = entitypath .. "template-fluid-io-mk2.png",
                width = 512,
                height = 512,
                scale = 0.25,
        },
    }
}

local template_fluid_io_mk3 = {
    type = "storage-tank",
    fluid_box = {
        volume = 1e5,
        pipe_connections = template_fluid_io_connections,
    },
    window_bounding_box = {{-0.4, -0.4}, {0.4, 0.4}},
    flow_length_in_ticks = 60,
    name = PREFIX .. "template-fluid-io-mk3",
    icon = iconpath .. "template-fluid-io-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-fluid-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    pictures = {
        picture = {
            filename = entitypath .. "template-fluid-io-mk3.png",
                width = 512,
                height = 512,
                scale = 0.25,
        },
    }
}

local template_energy_io_mk1 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "10GJ",
        usage_priority = "tertiary",
    },
    name = PREFIX .. "template-energy-io-mk1",
    icon = iconpath .. "template-energy-io-mk1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-energy-io-mk1"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-energy-io-mk1.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    },
}

local template_energy_io_mk2 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "100GJ",
        usage_priority = "tertiary",
    },
    name = PREFIX .. "template-energy-io-mk2",
    icon = iconpath .. "template-energy-io-mk2.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-energy-io-mk2"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-energy-io-mk2.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    },
}

local template_energy_io_mk3 = {
    type = "electric-energy-interface",
    gui_mode = "all",
    energy_source = {
        type = "electric",
        buffer_capacity = "100GJ",
        usage_priority = "tertiary",
    },
    name = PREFIX .. "template-energy-io-mk3",
    icon = iconpath .. "template-energy-io-mk3.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = PREFIX .. "template-energy-io-mk3"},
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    picture = {
        layers = {
            {
                filename = entitypath .. "template-energy-io-mk3.png",
                width = 512,
                height = 512,
                scale = 0.25,
            }
        },
    },
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