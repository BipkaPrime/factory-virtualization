local iconpath = "__factory-virtualization__/graphics/icons/"
local item_sounds = require("__base__.prototypes.item_sounds")
local names = require("scripts.gui.names")


local virtualization_subgroup = {
	type = "item-subgroup",
    name = "virtualization",
    group = "production",
    order = "z"
}


local item_uplink = {
	type = "item",
	name = "item-uplink",
	subgroup = "virtualization",
	icon = iconpath.."item-uplink.png",
	icon_size = 64,
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = names.prefix .. "item-uplink",
	stack_size = 10,
}

local item_downlink = {
	type = "item",
	name = "item-downlink",
	subgroup = "virtualization",
	icon = iconpath.."item-downlink.png",
	icon_size = 64,
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = names.prefix .. "item-downlink",
	stack_size = 10,
}

local fluid_uplink = {
	type = "item",
	name = "fluid-uplink",
	subgroup = "virtualization",
	icon = iconpath.."fluid-uplink.png",
	icon_size = 64,
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = names.prefix .. "fluid-uplink",
	stack_size = 10,
}

local fluid_downlink = {
	type = "item",
	name = "fluid-downlink",
	subgroup = "virtualization",
	icon = iconpath.."fluid-downlink.png",
	icon_size = 64,
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = names.prefix .. "fluid-downlink",
	stack_size = 10,
}

local energy_uplink = {
	type = "item",
	name = "energy-uplink",
	subgroup = "virtualization",
	icon = iconpath.."energy-uplink.png",
	icon_size = 64,
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = names.prefix .. "energy-uplink",
	stack_size = 10,
}

local energy_downlink = {
	type = "item",
	name = "energy-downlink",
	subgroup = "virtualization",
	icon = iconpath.."energy-downlink.png",
	icon_size = 64,
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = names.prefix .. "energy-downlink",
	stack_size = 10,
}


data.extend({
	virtualization_subgroup,
	item_uplink,
	item_downlink,
	fluid_uplink,
	fluid_downlink,
	energy_uplink,
	energy_downlink
})