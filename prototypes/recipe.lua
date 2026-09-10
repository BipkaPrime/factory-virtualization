-------------------------------------------------------------------------------
--------------------------- INTERMEDIATES SUBGROUP ----------------------------
-------------------------------------------------------------------------------

local computation_core_mk1 = {
	type = "recipe",
	name = PREFIX .. "computation-core-mk1",
	enabled = false,
	ingredients = {
		{type = "item", name = "processing-unit", amount = 100},
		{type = "item", name = "advanced-circuit", amount = 100},
		{type = "item", name = "quantum-processor", amount = 100},
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
	enabled = false,
	ingredients = {
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 100},
		{type = "item", name = "fission-reactor-equipment", amount = 100},
		{type = "item", name = "speed-module-3", amount = 500},
		{type = "item", name = "efficiency-module-3", amount = 500},
		{type = "item", name = "quantum-processor", amount = 1000},
		{type = "item", name = "supercapacitor", amount = 1000},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1}},
}

local computation_core_mk3 = {
	type = "recipe",
	name = PREFIX .. "computation-core-mk3",
	enabled = false,
	ingredients = {
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1000},
		{type = "item", name = "fusion-reactor-equipment", amount = 1000},
		{type = "item", name = "battery-mk3-equipment", amount = 1000},
		{type = "item", name = "energy-shield-mk2-equipment", amount = 1000},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1}},
}

local transmission_core_mk1 = {
	type = "recipe",
	name = PREFIX .. "transmission-core-mk1",
	enabled = false,
	ingredients = {
		{type = "item", name = "processing-unit", amount = 100},
		{type = "item", name = "advanced-circuit", amount = 100},
		{type = "item", name = "quantum-processor", amount = 100},
		{type = "item", name = "beacon", amount = 50},
		{type = "item", name = "substation", amount = 50},
		{type = "item", name = "radar", amount = 50},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1}},
}

local transmission_core_mk2 = {
	type = "recipe",
	name = PREFIX .. "transmission-core-mk2",
	enabled = false,
	ingredients = {
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 100},
		{type = "item", name = "fission-reactor-equipment", amount = 100},
		{type = "item", name = "speed-module-3", amount = 500},
		{type = "item", name = "efficiency-module-3", amount = 500},
		{type = "item", name = "quantum-processor", amount = 1000},
		{type = "item", name = "supercapacitor", amount = 1000},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1}},
}

local transmission_core_mk3 = {
	type = "recipe",
	name = PREFIX .. "transmission-core-mk3",
	enabled = false,
	ingredients = {
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1000},
		{type = "item", name = "fusion-reactor-equipment", amount = 1000},
		{type = "item", name = "battery-mk3-equipment", amount = 1000},
		{type = "item", name = "energy-shield-mk2-equipment", amount = 1000},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1}},
}

local storage_core_mk1 = {
	type = "recipe",
	name = PREFIX .. "storage-core-mk1",
	enabled = false,
	ingredients = {
		{type = "item", name = "processing-unit", amount = 100},
		{type = "item", name = "advanced-circuit", amount = 100},
		{type = "item", name = "quantum-processor", amount = 100},
		{type = "item", name = "steel-chest", amount = 50},
		{type = "item", name = "accumulator", amount = 50},
		{type = "item", name = "storage-tank", amount = 50},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1}},
}

local storage_core_mk2 = {
	type = "recipe",
	name = PREFIX .. "storage-core-mk2",
	enabled = false,
	ingredients = {
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 100},
		{type = "item", name = "fission-reactor-equipment", amount = 100},
		{type = "item", name = "speed-module-3", amount = 500},
		{type = "item", name = "efficiency-module-3", amount = 500},
		{type = "item", name = "quantum-processor", amount = 1000},
		{type = "item", name = "supercapacitor", amount = 1000},
	},
	energy_required = 100,
	results = {{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1}},
}

local storage_core_mk3 = {
	type = "recipe",
	name = PREFIX .. "storage-core-mk3",
	enabled = false,
	ingredients = {
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1000},
		{type = "item", name = "fusion-reactor-equipment", amount = 1000},
		{type = "item", name = "battery-mk3-equipment", amount = 1000},
		{type = "item", name = "energy-shield-mk2-equipment", amount = 1000},
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
------------------------------ TEMPLATE SUBGROUP ------------------------------
-------------------------------------------------------------------------------

local template_control_center_mk1 = {
	type = "recipe",
	name = PREFIX .. "template-control-center-mk1",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 10000},
		{type = "item", name = "tungsten-plate", amount = 10000},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 1000},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 1000},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 1000},
	},
	energy_required = 600,
	results = {{type = "item", name = PREFIX .. "template-control-center-mk1", amount = 1}},
}

local template_control_center_mk2 = {
	type = "recipe",
	name = PREFIX .. "template-control-center-mk2",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 10000},
		{type = "item", name = "tungsten-plate", amount = 10000},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 1000},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 1000},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 1000},
	},
	energy_required = 600,
	results = {{type = "item", name = PREFIX .. "template-control-center-mk2", amount = 1}},
}

local template_control_center_mk3 = {
	type = "recipe",
	name = PREFIX .. "template-control-center-mk3",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 10000},
		{type = "item", name = "tungsten-plate", amount = 10000},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 1000},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 1000},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 1000},
	},
	energy_required = 600,
	results = {{type = "item", name = PREFIX .. "template-control-center-mk3", amount = 1}},
}

local template_computation_array_mk1 = {
	type = "recipe",
	name = PREFIX .. "template-computation-array-mk1",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 1000},
		{type = "item", name = "tungsten-plate", amount = 1000},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 100},
	},
	energy_required = 60,
	results = {{type = "item", name = PREFIX .. "template-computation-array-mk1", amount = 1}},
}

local template_computation_array_mk2 = {
	type = "recipe",
	name = PREFIX .. "template-computation-array-mk2",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 1000},
		{type = "item", name = "tungsten-plate", amount = 1000},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 100},
	},
	energy_required = 60,
	results = {{type = "item", name = PREFIX .. "template-computation-array-mk2", amount = 1}},
}

local template_computation_array_mk3 = {
	type = "recipe",
	name = PREFIX .. "template-computation-array-mk3",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 1000},
		{type = "item", name = "tungsten-plate", amount = 1000},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 100},
	},
	energy_required = 60,
	results = {{type = "item", name = PREFIX .. "template-computation-array-mk3", amount = 1}},
}

local template_access_interface_mk1 = {
	type = "recipe",
	name = PREFIX .. "template-access-interface-mk1",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 500},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 50},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 10},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "template-access-interface-mk1", amount = 1}},
}

local template_access_interface_mk2 = {
	type = "recipe",
	name = PREFIX .. "template-access-interface-mk2",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 500},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 50},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 10},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "template-access-interface-mk2", amount = 1}},
}

local template_access_interface_mk3 = {
	type = "recipe",
	name = PREFIX .. "template-access-interface-mk3",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 500},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 50},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 10},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "template-access-interface-mk3", amount = 1}},
}

data.extend{
	template_computation_array_mk1,
	template_computation_array_mk2,
	template_computation_array_mk3,
	template_control_center_mk1,
	template_control_center_mk2,
	template_control_center_mk3,
	template_access_interface_mk1,
	template_access_interface_mk2,
	template_access_interface_mk3,
}

-------------------------------------------------------------------------------
---------------------------- TEMPLATE IO SUBGROUP -----------------------------
-------------------------------------------------------------------------------

local template_item_io_mk1 = {
	type = "recipe",
	name = PREFIX .. "template-item-io-mk1",
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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

-------------------------------------------------------------------------------
-------------------------- CLUSTER MEMBERS SUBGROUP ---------------------------
-------------------------------------------------------------------------------

local virtualization_mainframe_mk1 = {
	type = "recipe",
	name = PREFIX .. "virtualization-mainframe-mk1",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 100},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "virtualization-mainframe-mk1", amount = 1}},
}

local virtualization_mainframe_mk2 = {
	type = "recipe",
	name = PREFIX .. "virtualization-mainframe-mk2",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 100},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "virtualization-mainframe-mk2", amount = 1}},
}

local virtualization_mainframe_mk3 = {
	type = "recipe",
	name = PREFIX .. "virtualization-mainframe-mk3",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 100},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "virtualization-mainframe-mk3", amount = 1}},
}

local cluster_storage_unit_mk1 = {
	type = "recipe",
	name = PREFIX .. "cluster-storage-unit-mk1",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 500},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 10},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "cluster-storage-unit-mk1", amount = 1}},
}

local cluster_storage_unit_mk2 = {
	type = "recipe",
	name = PREFIX .. "cluster-storage-unit-mk2",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 500},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 10},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "cluster-storage-unit-mk2", amount = 1}},
}

local cluster_storage_unit_mk3 = {
	type = "recipe",
	name = PREFIX .. "cluster-storage-unit-mk3",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 2000},
		{type = "item", name = "tungsten-plate", amount = 2000},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 500},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 10},
	},
	energy_required = 120,
	results = {{type = "item", name = PREFIX .. "cluster-storage-unit-mk3", amount = 1}},
}

data.extend{
	virtualization_mainframe_mk1,
	virtualization_mainframe_mk2,
	virtualization_mainframe_mk3,
	cluster_storage_unit_mk1,
	cluster_storage_unit_mk2,
	cluster_storage_unit_mk3,
}

-------------------------------------------------------------------------------
-------------------------- SIMPLE CLUSTER IO SUBGROUP -------------------------
-------------------------------------------------------------------------------

local cluster_item_io_mk1 = {
	type = "recipe",
	name = PREFIX .. "cluster-item-io-mk1",
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
	enabled = false,
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
------------------------ ADVANCED CLUSTER IO SUBGROUP -------------------------
-------------------------------------------------------------------------------

local inter_cluster_bridge_mk1 = {
	type = "recipe",
	name = PREFIX .. "inter-cluster-bridge-mk1",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 5000},
		{type = "item", name = "tungsten-plate", amount = 5000},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 500},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 200},
	},
	energy_required = 180,
	results = {{type = "item", name = PREFIX .. "inter-cluster-bridge-mk1", amount = 1}},
}

local inter_cluster_bridge_mk2 = {
	type = "recipe",
	name = PREFIX .. "inter-cluster-bridge-mk2",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 5000},
		{type = "item", name = "tungsten-plate", amount = 5000},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 500},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 200},
	},
	energy_required = 180,
	results = {{type = "item", name = PREFIX .. "inter-cluster-bridge-mk2", amount = 1}},
}

local inter_cluster_bridge_mk3 = {
	type = "recipe",
	name = PREFIX .. "inter-cluster-bridge-mk3",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 5000},
		{type = "item", name = "tungsten-plate", amount = 5000},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 500},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 200},
	},
	energy_required = 180,
	results = {{type = "item", name = PREFIX .. "inter-cluster-bridge-mk3", amount = 1}},
}

local cluster_overflow_controller_mk1 = {
	type = "recipe",
	name = PREFIX .. "cluster-overflow-controller-mk1",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 5000},
		{type = "item", name = "tungsten-plate", amount = 5000},
		{type = "item", name = PREFIX .. "transmission-core-mk1", amount = 200},
		{type = "item", name = PREFIX .. "storage-core-mk1", amount = 20},
		{type = "item", name = PREFIX .. "computation-core-mk1", amount = 200},
	},
	energy_required = 180,
	results = {{type = "item", name = PREFIX .. "cluster-overflow-controller-mk1", amount = 1}},
}

local cluster_overflow_controller_mk2 = {
	type = "recipe",
	name = PREFIX .. "cluster-overflow-controller-mk2",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 5000},
		{type = "item", name = "tungsten-plate", amount = 5000},
		{type = "item", name = PREFIX .. "transmission-core-mk2", amount = 200},
		{type = "item", name = PREFIX .. "storage-core-mk2", amount = 20},
		{type = "item", name = PREFIX .. "computation-core-mk2", amount = 200},
	},
	energy_required = 180,
	results = {{type = "item", name = PREFIX .. "cluster-overflow-controller-mk2", amount = 1}},
}

local cluster_overflow_controller_mk3 = {
	type = "recipe",
	name = PREFIX .. "cluster-overflow-controller-mk3",
	enabled = false,
	ingredients =
	{
		{type = "item", name = "refined-concrete", amount = 5000},
		{type = "item", name = "tungsten-plate", amount = 5000},
		{type = "item", name = PREFIX .. "transmission-core-mk3", amount = 200},
		{type = "item", name = PREFIX .. "storage-core-mk3", amount = 10},
		{type = "item", name = PREFIX .. "computation-core-mk3", amount = 200},
	},
	energy_required = 180,
	results = {{type = "item", name = PREFIX .. "cluster-overflow-controller-mk3", amount = 1}},
}

data.extend{
	inter_cluster_bridge_mk1,
	inter_cluster_bridge_mk2,
	inter_cluster_bridge_mk3,
	cluster_overflow_controller_mk1,
	cluster_overflow_controller_mk2,
	cluster_overflow_controller_mk3,
}