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

local fluid_uplink = {
	type = "recipe",
	name = "fluid-uplink",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type="item", name="fluid-uplink", amount = 1}},
}

local fluid_downlink = {
	type = "recipe",
	name = "fluid-downlink",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type="item", name="fluid-downlink", amount = 1}},
}

local energy_uplink = {
	type = "recipe",
	name = "energy-uplink",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type="item", name="energy-uplink", amount = 1}},
}

local energy_downlink = {
	type = "recipe",
	name = "energy-downlink",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type="item", name="energy-downlink", amount = 1}},
}

local virtualization_mainframe = {
	type = "recipe",
	name = "virtualization-mainframe",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type="item", name="virtualization-mainframe", amount = 1}},
}

data:extend({
	item_uplink,
	item_downlink,
	fluid_uplink,
	fluid_downlink,
	energy_uplink,
	energy_downlink,
	virtualization_mainframe,
})