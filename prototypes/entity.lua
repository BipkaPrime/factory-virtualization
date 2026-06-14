ICONPATH = "__factory-virtualization__/graphics/icons/"
ENTITYPATH = "__factory-virtualization__/graphics/entity/"


data:extend({
    {
		type = "container",
        inventory_type = "with_custom_stack_size",
        inventory_properties = {
            stack_size_multiplier = 1000,
        },
        name = "virtualization-interface",
        icon = ICONPATH.."virtualization-interface.png",
		icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {mining_time = 2, result = "virtualization-interface"},
        max_health = 450,
        collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
		selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        inventory_size = 1,
        picture = {
			layers = {
				{
					filename = ENTITYPATH..'virtualization-interface-basic.png',
					width = 64,
					height = 80,
					scale = 1,
				}
			},
        }
	}})