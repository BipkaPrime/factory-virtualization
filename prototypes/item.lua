ICONPATH = "__factory-virtualization__/graphics/icons/"
local item_sounds = require("__base__.prototypes.item_sounds")


data:extend({
	{
		type = "item",
		name = "virtualization-interface",
		icon = ICONPATH.."virtualization-interface.png",
		icon_size = 64,
		inventory_move_sound = item_sounds.metal_chest_inventory_move,
		pick_sound = item_sounds.metal_chest_inventory_pickup,
		drop_sound = item_sounds.metal_chest_inventory_move,
		--subgroup = "storage",
		--order = "a[items]-c[warehouse]",
		place_result = "virtualization-interface",
		stack_size = 10,
	}})