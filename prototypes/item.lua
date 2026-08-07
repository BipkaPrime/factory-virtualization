local iconpath = "__factory-virtualization__/graphics/icons/"

---This mod has its own inventory group (tab)
local virtualization_group = {
	type = "item-group",
	name = PREFIX .. "inventory-tab",
    icon = iconpath .. "virtualization-inventory-tab.png",
    icon_size = 128,
    order = "g",
}

---Subgroup for crafting intermadiates
local intermediates_subgroup = {
	type = "item-subgroup",
    name = PREFIX .. "intermediates",
    group = PREFIX .. "inventory-tab",
    order = "a"
}

---Subgroup for buildings that are used to transfer items/fluids/energy
---between physical factorio world and cluster internal storage.
local simple_cluster_io_subgroup = {
	type = "item-subgroup",
    name = PREFIX .. "simple-cluster-io",
    group = PREFIX .. "inventory-tab",
    order = "b"
}

---Subgroup for buildings that are used for logistics but do not interact
---with physical items/fluids/energy, like inter-cluster bridge.
local advanced_cluster_io_subgroup = {
	type = "item-subgroup",
    name = PREFIX .. "advanced-cluster-io",
    group = PREFIX .. "inventory-tab",
    order = "c"
}

---Subgroup for buildings that can be members of a cluster. They provide something
---for the cluster. Like virtualization mainframe, which provides crafting capability.
local cluster_members_subgroup = {
	type = "item-subgroup",
    name = PREFIX .. "cluster-members",
    group = PREFIX .. "inventory-tab",
    order = "d"
}

---Subgroup for buildings that are used on virtualization surfaces to compile a template.
---They serve as an IO for items/fluids/energy.
local template_io_subgroup = {
	type = "item-subgroup",
    name = PREFIX .. "template-io",
    group = PREFIX .. "inventory-tab",
    order = "e"
}

---Subgroup for buidlings that are used for template creation/management
local template_subgroup = {
	type = "item-subgroup",
    name = PREFIX .. "template",
    group = PREFIX .. "inventory-tab",
    order = "f"
}

data.extend{
	virtualization_group,
	intermediates_subgroup,
	simple_cluster_io_subgroup,
	advanced_cluster_io_subgroup,
	cluster_members_subgroup,
	template_io_subgroup,
	template_subgroup,
}

-------------------------------------------------------------------------------
-- INTERMEDIATES SUBGROUP
-------------------------------------------------------------------------------

local computation_core_mk1 = {
	type = "item",
	name = PREFIX .. "computation-core-mk1",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "computation-core-mk1.png",
	icon_size = 64,
	stack_size = 200,
}

local computation_core_mk2 = {
	type = "item",
	name = PREFIX .. "computation-core-mk2",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "computation-core-mk2.png",
	icon_size = 64,
	stack_size = 200,
}

local computation_core_mk3 = {
	type = "item",
	name = PREFIX .. "computation-core-mk3",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "computation-core-mk3.png",
	icon_size = 64,
	stack_size = 200,
}

local transmission_core_mk1 = {
	type = "item",
	name = PREFIX .. "transmission-core-mk1",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "transmission-core-mk1.png",
	icon_size = 64,
	stack_size = 200,
}

local transmission_core_mk2 = {
	type = "item",
	name = PREFIX .. "transmission-core-mk2",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "transmission-core-mk2.png",
	icon_size = 64,
	stack_size = 200,
}

local transmission_core_mk3 = {
	type = "item",
	name = PREFIX .. "transmission-core-mk3",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "transmission-core-mk3.png",
	icon_size = 64,
	stack_size = 200,
}

local storage_core_mk1 = {
	type = "item",
	name = PREFIX .. "storage-core-mk1",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "storage-core-mk1.png",
	icon_size = 128,
	stack_size = 200,
}

local storage_core_mk2 = {
	type = "item",
	name = PREFIX .. "storage-core-mk2",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "storage-core-mk2.png",
	icon_size = 128,
	stack_size = 200,
}

local storage_core_mk3 = {
	type = "item",
	name = PREFIX .. "storage-core-mk3",
	subgroup = PREFIX .. "intermediates",
	icon = iconpath .. "storage-core-mk3.png",
	icon_size = 128,
	stack_size = 200,
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
	type = "item",
	name = PREFIX .. "cluster-item-io-mk1",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-item-io-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-item-io-mk1",
	stack_size = 20,
}

local cluster_item_io_mk2 = {
	type = "item",
	name = PREFIX .. "cluster-item-io-mk2",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-item-io-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-item-io-mk2",
	stack_size = 20,
}

local cluster_item_io_mk3 = {
	type = "item",
	name = PREFIX .. "cluster-item-io-mk3",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-item-io-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-item-io-mk3",
	stack_size = 20,
}

local cluster_fluid_io_mk1 = {
	type = "item",
	name = PREFIX .. "cluster-fluid-io-mk1",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-fluid-io-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-fluid-io-mk1",
	stack_size = 20,
}

local cluster_fluid_io_mk2 = {
	type = "item",
	name = PREFIX .. "cluster-fluid-io-mk2",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-fluid-io-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-fluid-io-mk2",
	stack_size = 20,
}

local cluster_fluid_io_mk3 = {
	type = "item",
	name = PREFIX .. "cluster-fluid-io-mk3",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-fluid-io-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-fluid-io-mk3",
	stack_size = 20,
}

local cluster_energy_io_mk1 = {
	type = "item",
	name = PREFIX .. "cluster-energy-io-mk1",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-energy-io-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-energy-io-mk1",
	stack_size = 20,
}

local cluster_energy_io_mk2 = {
	type = "item",
	name = PREFIX .. "cluster-energy-io-mk2",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-energy-io-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-energy-io-mk2",
	stack_size = 20,
}

local cluster_energy_io_mk3 = {
	type = "item",
	name = PREFIX .. "cluster-energy-io-mk3",
	subgroup = PREFIX .. "simple-cluster-io",
	icon = iconpath .. "cluster-energy-io-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-energy-io-mk3",
	stack_size = 20,
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
	type = "item",
	name = PREFIX .. "inter-cluster-bridge-mk1",
	subgroup = PREFIX .. "advanced-cluster-io",
	icon = iconpath .. "inter-cluster-bridge-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "inter-cluster-bridge-mk1",
	stack_size = 20,
}

local inter_cluster_bridge_mk2 = {
	type = "item",
	name = PREFIX .. "inter-cluster-bridge-mk2",
	subgroup = PREFIX .. "advanced-cluster-io",
	icon = iconpath .. "inter-cluster-bridge-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "inter-cluster-bridge-mk2",
	stack_size = 20,
}

local inter_cluster_bridge_mk3 = {
	type = "item",
	name = PREFIX .. "inter-cluster-bridge-mk3",
	subgroup = PREFIX .. "advanced-cluster-io",
	icon = iconpath .. "inter-cluster-bridge-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "inter-cluster-bridge-mk3",
	stack_size = 20,
}

local cluster_overflow_controller_mk1 = {
	type = "item",
	name = PREFIX .. "cluster-overflow-controller-mk1",
	subgroup = PREFIX .. "advanced-cluster-io",
	icon = iconpath .. "cluster-overflow-controller-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-overflow-controller-mk1",
	stack_size = 20,
}

local cluster_overflow_controller_mk2 = {
	type = "item",
	name = PREFIX .. "cluster-overflow-controller-mk2",
	subgroup = PREFIX .. "advanced-cluster-io",
	icon = iconpath .. "cluster-overflow-controller-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-overflow-controller-mk2",
	stack_size = 20,
}

local cluster_overflow_controller_mk3 = {
	type = "item",
	name = PREFIX .. "cluster-overflow-controller-mk3",
	subgroup = PREFIX .. "advanced-cluster-io",
	icon = iconpath .. "cluster-overflow-controller-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-overflow-controller-mk3",
	stack_size = 20,
}


data.extend{
	inter_cluster_bridge_mk1,
	inter_cluster_bridge_mk2,
	inter_cluster_bridge_mk3,
	cluster_overflow_controller_mk1,
	cluster_overflow_controller_mk2,
	cluster_overflow_controller_mk3,
}

-------------------------------------------------------------------------------
-- CLUSTER MEMBERS SUBGROUP
-------------------------------------------------------------------------------

local virtualization_mainframe_mk1 = {
	type = "item",
	name = PREFIX .. "virtualization-mainframe-mk1",
	subgroup = PREFIX .. "cluster-members",
	icon = iconpath .. "virtualization-mainframe-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "virtualization-mainframe-mk1",
	stack_size = 20,
}

local virtualization_mainframe_mk2 = {
	type = "item",
	name = PREFIX .. "virtualization-mainframe-mk2",
	subgroup = PREFIX .. "cluster-members",
	icon = iconpath .. "virtualization-mainframe-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "virtualization-mainframe-mk2",
	stack_size = 20,
}

local virtualization_mainframe_mk3 = {
	type = "item",
	name = PREFIX .. "virtualization-mainframe-mk3",
	subgroup = PREFIX .. "cluster-members",
	icon = iconpath .. "virtualization-mainframe-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "virtualization-mainframe-mk3",
	stack_size = 20,
}

local cluster_storage_unit_mk1 = {
	type = "item",
	name = PREFIX .. "cluster-storage-unit-mk1",
	subgroup = PREFIX .. "cluster-members",
	icon = iconpath .. "cluster-storage-unit-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-storage-unit-mk1",
	stack_size = 20,
}

local cluster_storage_unit_mk2 = {
	type = "item",
	name = PREFIX .. "cluster-storage-unit-mk2",
	subgroup = PREFIX .. "cluster-members",
	icon = iconpath .. "cluster-storage-unit-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-storage-unit-mk2",
	stack_size = 20,
}

local cluster_storage_unit_mk3 = {
	type = "item",
	name = PREFIX .. "cluster-storage-unit-mk3",
	subgroup = PREFIX .. "cluster-members",
	icon = iconpath .. "cluster-storage-unit-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "cluster-storage-unit-mk3",
	stack_size = 20,
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
-- TEMPLATE IO SUBGROUP
-------------------------------------------------------------------------------

local template_item_io_mk1 = {
	type = "item",
	name = PREFIX .. "template-item-io-mk1",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-item-io-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "template-item-io-mk1",
	stack_size = 20,
}

local template_item_io_mk2 = {
	type = "item",
	name = PREFIX .. "template-item-io-mk2",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-item-io-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "template-item-io-mk2",
	stack_size = 20,
}

local template_item_io_mk3 = {
	type = "item",
	name = PREFIX .. "template-item-io-mk3",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-item-io-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "template-item-io-mk3",
	stack_size = 20,
}

local template_fluid_io_mk1 = {
	type = "item",
	name = PREFIX .. "template-fluid-io-mk1",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-fluid-io-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "template-fluid-io-mk1",
	stack_size = 20,
}

local template_fluid_io_mk2 = {
	type = "item",
	name = PREFIX .. "template-fluid-io-mk2",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-fluid-io-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "template-fluid-io-mk2",
	stack_size = 20,
}

local template_fluid_io_mk3 = {
	type = "item",
	name = PREFIX .. "template-fluid-io-mk3",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-fluid-io-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "template-fluid-io-mk3",
	stack_size = 20,
}

local template_energy_io_mk1 = {
	type = "item",
	name = PREFIX .. "template-energy-io-mk1",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-energy-io-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "template-energy-io-mk1",
	stack_size = 20,
}

local template_energy_io_mk2 = {
	type = "item",
	name = PREFIX .. "template-energy-io-mk2",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-energy-io-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "template-energy-io-mk2",
	stack_size = 20,
}

local template_energy_io_mk3 = {
	type = "item",
	name = PREFIX .. "template-energy-io-mk3",
	subgroup = PREFIX .. "template-io",
	icon = iconpath .. "template-energy-io-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "template-energy-io-mk3",
	stack_size = 20,
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
-- TEMPLATE SUBGROUP
-------------------------------------------------------------------------------

local template_computation_array_mk1 = {
	type = "item",
	name = PREFIX .. "template-computation-array-mk1",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-computation-array-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "template-computation-array-mk1",
	stack_size = 20,
}

local template_computation_array_mk2 = {
	type = "item",
	name = PREFIX .. "template-computation-array-mk2",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-computation-array-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "template-computation-array-mk2",
	stack_size = 20,
}

local template_computation_array_mk3 = {
	type = "item",
	name = PREFIX .. "template-computation-array-mk3",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-computation-array-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "template-computation-array-mk3",
	stack_size = 20,
}

local template_control_center_mk1 = {
	type = "item",
	name = PREFIX .. "template-control-center-mk1",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-control-center-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "template-control-center-mk1",
	stack_size = 20,
}

local template_control_center_mk2 = {
	type = "item",
	name = PREFIX .. "template-control-center-mk2",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-control-center-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "template-control-center-mk2",
	stack_size = 20,
}

local template_control_center_mk3 = {
	type = "item",
	name = PREFIX .. "template-control-center-mk3",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-control-center-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "template-control-center-mk3",
	stack_size = 20,
}

local template_access_interface_mk1 = {
	type = "item",
	name = PREFIX .. "template-access-interface-mk1",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-access-interface-mk1.png",
	icon_size = 64,
	place_result = PREFIX .. "template-access-interface-mk1",
	stack_size = 20,
}

local template_access_interface_mk2 = {
	type = "item",
	name = PREFIX .. "template-access-interface-mk2",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-access-interface-mk2.png",
	icon_size = 64,
	place_result = PREFIX .. "template-access-interface-mk2",
	stack_size = 20,
}

local template_access_interface_mk3 = {
	type = "item",
	name = PREFIX .. "template-access-interface-mk3",
	subgroup = PREFIX .. "template",
	icon = iconpath .. "template-access-interface-mk3.png",
	icon_size = 64,
	place_result = PREFIX .. "template-access-interface-mk3",
	stack_size = 20,
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