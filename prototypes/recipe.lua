local item_uplink = {
	type = "recipe",
	name = "item-uplink",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type="item", name="item-uplink", amount = 1}},
}

local item_downlink = {
	type = "recipe",
	name = "item-downlink",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type="item", name="item-downlink", amount = 1}},
}

data:extend({item_uplink, item_downlink})