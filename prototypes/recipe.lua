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

local inter_cluster_bridge = {
	type = "recipe",
	name = PREFIX .. "inter-cluster-bridge",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "steel-plate", amount = 150},
		{type = "item", name = "stone-brick", amount = 40},
		{type = "item", name = "iron-chest", amount = 40},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "inter-cluster-bridge", amount = 1}},
}

local computation_core_mk1 = {
	type = "recipe",
	name = PREFIX .. "computation-core-mk1",
	enabled = true,
	ingredients = {
		{type = "item", name = "processing-unit", amount = 500},
		{type = "item", name = "advanced-circuit", amount = 500},
		{type = "item", name = "low-density-structure", amount = 200},
		{type = "item", name = "speed-module-3", amount = 100},
		{type = "item", name = "efficiency-module-3", amount = 100},
	},
	energy_required = 100,
	stack_size = 10,
	results = {{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1}},
}

local computation_core_mk2 = {
	type = "recipe",
	name = PREFIX .. "computation-core-mk2",
	enabled = true,
	ingredients = {
		{type = "item", name = "processing-unit", amount = 500},
		{type = "item", name = "advanced-circuit", amount = 500},
		{type = "item", name = "low-density-structure", amount = 200},
		{type = "item", name = "speed-module-3", amount = 100},
		{type = "item", name = "efficiency-module-3", amount = 100},
	},
	energy_required = 100,
	stack_size = 10,
	results = {{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1}},
}

local computation_core_mk3 = {
	type = "recipe",
	name = PREFIX .. "computation-core-mk3",
	enabled = true,
	ingredients = {
		{type = "item", name = "processing-unit", amount = 500},
		{type = "item", name = "advanced-circuit", amount = 500},
		{type = "item", name = "low-density-structure", amount = 200},
		{type = "item", name = "speed-module-3", amount = 100},
		{type = "item", name = "efficiency-module-3", amount = 100},
	},
	energy_required = 100,
	stack_size = 10,
	results = {{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1}},
}

data:extend({
	template_item_io,
	template_fluid_io,
	template_energy_io,
	mainframe_item_io,
	mainframe_fluid_io,
	mainframe_energy_io,
	virtualization_mainframe,
	inter_cluster_bridge,
	computation_core_mk1,
	computation_core_mk2,
	computation_core_mk3,
})