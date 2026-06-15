ICONPATH = "__factory-virtualization__/graphics/icons/"
local item_sounds = require("__base__.prototypes.item_sounds")


local item_uplink = {
	type = "item",
	name = "item-uplink",
	icon = ICONPATH.."item-uplink.png",
	icon_size = 64,
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = "item-uplink",
	stack_size = 10,
}

local item_downlink = {
	type = "item",
	name = "item-downlink",
	icon = ICONPATH.."item-downlink.png",
	icon_size = 64,
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = "item-downlink",
	stack_size = 10,
}


data.extend({item_uplink, item_downlink})