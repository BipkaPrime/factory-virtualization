local template_item_io = {
	type = "recipe",
	name = PREFIX .. "template-item-io",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-item-io", amount = 1}},
}

local template_fluid_io = {
	type = "recipe",
	name = PREFIX .. "template-fluid-io",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-fluid-io", amount = 1}},
}

local template_energy_io = {
	type = "recipe",
	name = PREFIX .. "template-energy-io",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-energy-io", amount = 1}},
}

local mainframe_item_io = {
	type = "recipe",
	name = PREFIX .. "mainframe-item-io",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "mainframe-item-io", amount = 1}},
}

local mainframe_fluid_io = {
	type = "recipe",
	name = PREFIX .. "mainframe-fluid-io",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "mainframe-fluid-io", amount = 1}},
}

local mainframe_energy_io = {
	type = "recipe",
	name = PREFIX .. "mainframe-energy-io",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "mainframe-energy-io", amount = 1}},
}

local virtualization_mainframe = {
	type = "recipe",
	name = PREFIX .. "virtualization-mainframe",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "virtualization-mainframe", amount = 1}},
}



data:extend({
	template_item_io,
	template_fluid_io,
	template_energy_io,
	mainframe_item_io,
	mainframe_fluid_io,
	mainframe_energy_io,
	virtualization_mainframe,
})