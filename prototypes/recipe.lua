-------------------------------------------------------------------------------
-- INTERMEDIATES SUBGROUP
-------------------------------------------------------------------------------

local computation_core_mk1 = {
	type = "recipe",
	name = PREFIX .. "computation-core-mk1",
	enabled = true,
	ingredients = {
		{type = "item", name = "processing-unit", amount = 100},
		{type = "item", name = "advanced-circuit", amount = 100},
		{type = "item", name = "productivity-module-3", amount = 10},
		{type = "item", name = "speed-module-3", amount = 10},
		{type = "item", name = "efficiency-module-3", amount = 10},
		{type = "item", name = "quality-module-3", amount = 10},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1}},
}

local computation_core_mk2 = {
	type = "recipe",
	name = PREFIX .. "computation-core-mk2",
	enabled = true,
	ingredients = {
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 100},
		{type = "item", name = "quantum-processor", amount = 1000},
		{type = "item", name = "superconductor", amount = 1000},
		{type = "item", name = "supercapacitor", amount = 1000},
		{type = "item", name = "fission-reactor-equipment", amount = 100},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1}},
}

local computation_core_mk3 = {
	type = "recipe",
	name = PREFIX .. "computation-core-mk3",
	enabled = true,
	ingredients = {
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 100},
		{type = "item", name = "fusion-reactor-equipment", amount = 100},
		{type = "item", name = "battery-mk3-equipment", amount = 100},
		{type = "item", name = "energy-shield-mk2-equipment", amount = 100},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1}},
}

local transmission_core_mk1 = {
	type = "recipe",
	name = PREFIX .. "transmission-core-mk1",
	enabled = true,
	ingredients = {
		{type = "item", name = "electronic-circuit", amount = 100},
		{type = "item", name = "processing-unit", amount = 100},
		{type = "item", name = "advanced-circuit", amount = 100},
		{type = "item", name = "beacon", amount = 20},
		{type = "item", name = "substation", amount = 20},
		{type = "item", name = "radar", amount = 20},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1}},
}

local transmission_core_mk2 = {
	type = "recipe",
	name = PREFIX .. "transmission-core-mk2",
	enabled = true,
	ingredients = {
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 100},
		{type = "item", name = "speed-module-3", amount = 100},
		{type = "item", name = "efficiency-module-3", amount = 100},
		{type = "item", name = "fission-reactor-equipment", amount = 100},
		{type = "item", name = "superconductor", amount = 1000},
		{type = "item", name = "supercapacitor", amount = 1000},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1}},
}

local transmission_core_mk3 = {
	type = "recipe",
	name = PREFIX .. "transmission-core-mk3",
	enabled = true,
	ingredients = {
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 100},
		{type = "item", name = "fusion-reactor-equipment", amount = 100},
		{type = "item", name = "battery-mk3-equipment", amount = 100},
		{type = "item", name = "energy-shield-mk2-equipment", amount = 100},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1}},
}

local storage_core_mk1 = {
	type = "recipe",
	name = PREFIX .. "storage-core-mk1",
	enabled = true,
	ingredients = {
		{type = "item", name = "electronic-circuit", amount = 100},
		{type = "item", name = "processing-unit", amount = 100},
		{type = "item", name = "advanced-circuit", amount = 100},
		{type = "item", name = "steel-chest", amount = 20},
		{type = "item", name = "accumulator", amount = 20},
		{type = "item", name = "storage-tank", amount = 20},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1}},
}

local storage_core_mk2 = {
	type = "recipe",
	name = PREFIX .. "storage-core-mk2",
	enabled = true,
	ingredients = {
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 100},
		{type = "item", name = "fission-reactor-equipment", amount = 100},
		{type = "item", name = "speed-module-3", amount = 100},
		{type = "item", name = "efficiency-module-3", amount = 100},
		{type = "item", name = "superconductor", amount = 1000},
		{type = "item", name = "supercapacitor", amount = 1000},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1}},
}

local storage_core_mk3 = {
	type = "recipe",
	name = PREFIX .. "storage-core-mk3",
	enabled = true,
	ingredients = {
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 100},
		{type = "item", name = "fusion-reactor-equipment", amount = 100},
		{type = "item", name = "battery-mk3-equipment", amount = 100},
		{type = "item", name = "energy-shield-mk2-equipment", amount = 100},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "storage-core-mk3", amount = 1}},
}

data.extend{
	computation_core_mk1,
	computation_core_mk2,
	computation_core_mk3,
	transmission_core_mk1,
	transmission_core_mk2,
	transmission_core_mk3,
	storage_core_mk1,
	storage_core_mk2,
	storage_core_mk3,
}

-------------------------------------------------------------------------------
-- SIMPLE CLUSTER IO SUBGROUP
-------------------------------------------------------------------------------

local cluster_item_io_mk1 = {
	type = "recipe",
	name = PREFIX .. "cluster-item-io-mk1",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-item-io-mk1", amount = 1}},
}

local cluster_item_io_mk2 = {
	type = "recipe",
	name = PREFIX .. "cluster-item-io-mk2",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-item-io-mk2", amount = 1}},
}

local cluster_item_io_mk3 = {
	type = "recipe",
	name = PREFIX .. "cluster-item-io-mk3",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-item-io-mk3", amount = 1}},
}

local cluster_fluid_io_mk1 = {
	type = "recipe",
	name = PREFIX .. "cluster-fluid-io-mk1",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-fluid-io-mk1", amount = 1}},
}

local cluster_fluid_io_mk2 = {
	type = "recipe",
	name = PREFIX .. "cluster-fluid-io-mk2",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-fluid-io-mk2", amount = 1}},
}

local cluster_fluid_io_mk3 = {
	type = "recipe",
	name = PREFIX .. "cluster-fluid-io-mk3",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-fluid-io-mk3", amount = 1}},
}

local cluster_energy_io_mk1 = {
	type = "recipe",
	name = PREFIX .. "cluster-energy-io-mk1",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-energy-io-mk1", amount = 1}},
}

local cluster_energy_io_mk2 = {
	type = "recipe",
	name = PREFIX .. "cluster-energy-io-mk2",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-energy-io-mk2", amount = 1}},
}

local cluster_energy_io_mk3 = {
	type = "recipe",
	name = PREFIX .. "cluster-energy-io-mk3",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "cluster-energy-io-mk3", amount = 1}},
}

data.extend{
	cluster_item_io_mk1,
	cluster_item_io_mk2,
	cluster_item_io_mk3,
	cluster_fluid_io_mk1,
	cluster_fluid_io_mk2,
	cluster_fluid_io_mk3,
	cluster_energy_io_mk1,
	cluster_energy_io_mk2,
	cluster_energy_io_mk3,
}

-------------------------------------------------------------------------------
-- ADVANCED CLUSTER IO SUBGROUP
-------------------------------------------------------------------------------

local inter_cluster_bridge_mk1 = {
	type = "recipe",
	name = PREFIX .. "inter-cluster-bridge-mk1",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 100},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 5},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 5},
	},
	energy_required = 300,
	results = {{type = "item", name = PREFIX .. "inter-cluster-bridge-mk1", amount = 1}},
}

local inter_cluster_bridge_mk2 = {
	type = "recipe",
	name = PREFIX .. "inter-cluster-bridge-mk2",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 100},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 5},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 5},
	},
	energy_required = 300,
	results = {{type = "item", name = PREFIX .. "inter-cluster-bridge-mk2", amount = 1}},
}

local inter_cluster_bridge_mk3 = {
	type = "recipe",
	name = PREFIX .. "inter-cluster-bridge-mk3",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 100},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 5},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 5},
	},
	energy_required = 300,
	results = {{type = "item", name = PREFIX .. "inter-cluster-bridge-mk3", amount = 1}},
}

data.extend{
	inter_cluster_bridge_mk1,
	inter_cluster_bridge_mk2,
	inter_cluster_bridge_mk3,
}

-------------------------------------------------------------------------------
-- CLUSTER MEMBERS SUBGROUP
-------------------------------------------------------------------------------

local virtualization_mainframe_mk1 = {
	type = "recipe",
	name = PREFIX .. "virtualization-mainframe-mk1",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 10},
	},
	energy_required = 300,
	results = {{type = "item", name = PREFIX .. "virtualization-mainframe-mk1", amount = 1}},
}

local virtualization_mainframe_mk2 = {
	type = "recipe",
	name = PREFIX .. "virtualization-mainframe-mk2",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 10},
	},
	energy_required = 300,
	results = {{type = "item", name = PREFIX .. "virtualization-mainframe-mk2", amount = 1}},
}

local virtualization_mainframe_mk3 = {
	type = "recipe",
	name = PREFIX .. "virtualization-mainframe-mk3",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 10},
	},
	energy_required = 300,
	results = {{type = "item", name = PREFIX .. "virtualization-mainframe-mk3", amount = 1}},
}

data.extend{
	virtualization_mainframe_mk1,
	virtualization_mainframe_mk2,
	virtualization_mainframe_mk3,
}

-------------------------------------------------------------------------------
-- TEMPLATE IO SUBGROUP
-------------------------------------------------------------------------------

local template_item_io_mk1 = {
	type = "recipe",
	name = PREFIX .. "template-item-io-mk1",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-item-io-mk1", amount = 1}},
}

local template_item_io_mk2 = {
	type = "recipe",
	name = PREFIX .. "template-item-io-mk2",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-item-io-mk2", amount = 1}},
}

local template_item_io_mk3 = {
	type = "recipe",
	name = PREFIX .. "template-item-io-mk3",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-item-io-mk3", amount = 1}},
}

local template_fluid_io_mk1 = {
	type = "recipe",
	name = PREFIX .. "template-fluid-io-mk1",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-fluid-io-mk1", amount = 1}},
}

local template_fluid_io_mk2 = {
	type = "recipe",
	name = PREFIX .. "template-fluid-io-mk2",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-fluid-io-mk2", amount = 1}},
}

local template_fluid_io_mk3 = {
	type = "recipe",
	name = PREFIX .. "template-fluid-io-mk3",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-fluid-io-mk3", amount = 1}},
}

local template_energy_io_mk1 = {
	type = "recipe",
	name = PREFIX .. "template-energy-io-mk1",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-energy-io-mk1", amount = 1}},
}

local template_energy_io_mk2 = {
	type = "recipe",
	name = PREFIX .. "template-energy-io-mk2",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-energy-io-mk2", amount = 1}},
}

local template_energy_io_mk3 = {
	type = "recipe",
	name = PREFIX .. "template-energy-io-mk3",
	enabled = true,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 500},
		{type = "item", name = "tungsten-plate", amount = 500},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 1},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1},
	},
	energy_required = 30,
	results = {{type = "item", name = PREFIX .. "template-energy-io-mk3", amount = 1}},
}

data.extend{
	template_item_io_mk1,
	template_item_io_mk2,
	template_item_io_mk3,
	template_fluid_io_mk1,
	template_fluid_io_mk2,
	template_fluid_io_mk3,
	template_energy_io_mk1,
	template_energy_io_mk2,
	template_energy_io_mk3,
}