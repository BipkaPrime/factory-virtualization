local iconpath = "__factory-virtualization__/graphics/icons/"


local vcluster_subgroup = {
	type = "item-subgroup",
    name = "vcluster",
    group = "production",
    order = "y"
}

local template_io_subgroup = {
	type = "item-subgroup",
    name = "template-io",
    group = "production",
    order = "z"
}

local template_item_io = {
	type = "item",
	name = PREFIX .. "template-item-io",
	subgroup = "template-io",
	icon = iconpath .. "template-item-io.png",
	icon_size = 64,
	place_result = PREFIX .. "template-item-io",
	stack_size = 10,
}

local template_fluid_io = {
	type = "item",
	name = PREFIX .. "template-fluid-io",
	subgroup = "template-io",
	icon = iconpath .. "template-fluid-io.png",
	icon_size = 64,
	place_result = PREFIX .. "template-fluid-io",
	stack_size = 10,
}

local template_energy_io = {
	type = "item",
	name = PREFIX .. "template-energy-io",
	subgroup = "template-io",
	icon = iconpath .. "template-energy-io.png",
	icon_size = 64,
	place_result = PREFIX .. "template-energy-io",
	stack_size = 10,
}

local mainframe_item_io = {
	type = "item",
	name = PREFIX .. "mainframe-item-io",
	subgroup = "vcluster",
	icon = iconpath .. "mainframe-item-io.png",
	icon_size = 64,
	place_result = PREFIX .. "mainframe-item-io",
	stack_size = 10,
}

local mainframe_fluid_io = {
	type = "item",
	name = PREFIX .. "mainframe-fluid-io",
	subgroup = "vcluster",
	icon = iconpath .. "mainframe-fluid-io.png",
	icon_size = 64,
	place_result = PREFIX .. "mainframe-fluid-io",
	stack_size = 10,
}

local mainframe_energy_io = {
	type = "item",
	name = PREFIX .. "mainframe-energy-io",
	subgroup = "vcluster",
	icon = iconpath .. "mainframe-energy-io.png",
	icon_size = 64,
	place_result = PREFIX .. "mainframe-energy-io",
	stack_size = 10,
}

local virtualization_mainframe = {
	type = "item",
	name = PREFIX .. "virtualization-mainframe",
	subgroup = "vcluster",
	icon = iconpath .. "virtualization-mainframe.png",
	icon_size = 64,
	place_result = PREFIX .. "virtualization-mainframe",
	stack_size = 10,
}

data.extend({
	vcluster_subgroup,
	template_io_subgroup,
	template_item_io,
	template_fluid_io,
	template_energy_io,
	mainframe_item_io,
	mainframe_fluid_io,
	mainframe_energy_io,
	virtualization_mainframe,
})