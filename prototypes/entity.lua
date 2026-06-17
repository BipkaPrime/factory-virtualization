ICONPATH = "__factory-virtualization__/graphics/icons/"
ENTITYPATH = "__factory-virtualization__/graphics/entity/"


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


data:extend({item_uplink, item_downlink})