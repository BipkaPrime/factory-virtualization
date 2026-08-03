--[[
Cluster storage unit is used to increase buffer size of a cluster.
It connects to one buffer entry and provides buffer capacity as long as
the building is powered. If energy stored in the entity is not sufficient,
it stops working and buffer capacity provided to cluster is disabled until
enough energy is provided.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. First template. Used to determine the cluster that gets
        capacity increase.
    2. IO mode (input/output). If "input" then entry from the cluster
        input buffer will get capacity increase.
    3. Operation mode (item/fluid/energy). Used to determine the entry
        that gets capacity increase.
    4. Selected item (only for "item" mode). Used to determine the entry
        that gets capacity increase.
    5. Selected fluid (only for "fluid" mode). Used to determine the entry
        that gets capacity increase.
II. Entity is not located on a vsurface.

Optional entity controls this building can have:
1. Capability override. Used to artificially lower capacity provided
    by the building.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. First cluster ClusterData. Used to make calls to cluster processor.
2. Buffer entry ClusterBufferEntry. Used to make calls to cluster processor.
3. Capacity number. Used to make calls to cluster processor.

Properties that can be assigned during on-tick processing:
1. Operational boolean. True if entity is currently providing capacity to cluster.
--]]


local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.entity-processor-members.utilities")


local PREFIX = "FV-"
local StorageUnit = {}

---List of all copyable properties of this entity
StorageUnit.copyable = {
    "first_template",
    "io_mode",
    "operation_mode",
    "selected_item",
    "selected_fluid",
    "capability_override",
}

---Maps entity names to their capacity limits
local capacity_limits = {
    [PREFIX .. "cluster-storage-unit-mk1"] = {
        item = 1e6,
        fluid = 1e6,
        energy = 1e12,
    },
    [PREFIX .. "cluster-storage-unit-mk2"] = {
        item = 1e9,
        fluid = 1e9,
        energy = 1e15,
    },
    [PREFIX .. "cluster-storage-unit-mk3"] = {
        item = 1e12,
        fluid = 1e12,
        energy = 1e18,
    },
}

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "cluster-storage-unit-mk1"] = 1,
    [PREFIX .. "cluster-storage-unit-mk2"] = 10,
    [PREFIX .. "cluster-storage-unit-mk3"] = 100,
}

---Checks that all requirements for operation of cluster storage unit are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function StorageUnit.attempt_entity_initialization(properties)
    -- 1. First template is selected
    local first_template = properties.first_template
    if not first_template then return false end
    -- 2. IO mode is selected
    local io_mode = properties.io_mode
    if not io_mode then return false end
    -- 3. Operation mode is selected
    local operation_mode = properties.operation_mode
    if not operation_mode then return false end
    -- 4. Item is selected in "item" mode
    local selected_item = properties.selected_item
    if operation_mode == "item" and not selected_item then return false end
    -- 5. Fluid is selected in "fluid" mode
    local selected_fluid = properties.selected_fluid
    if operation_mode == "fluid" and not selected_fluid then return false end
    -- 6. Entity is not located on a vsurface
    local entity = properties.entity
    if VSurfaceManager.get_vsurface_data(entity.surface_index) then return false end

    ---All requirements are met. Preparing properties for on-tick processing
    -- attempting to connect entity to cluster
    local entity_name = properties.entity_name
    local cluster = ClusterProcessor.add_to_cluster(
        entity,
        first_template,
        weights[entity_name]
    )
    if not cluster then return false end
    properties.first_cluster = cluster
    -- attempting to assign buffer entry to entity
    local buffer_key = Utilities.generate_multimode_buffer_key(properties)
    local buffer_entry = ClusterProcessor.get_buffer_entry(cluster, buffer_key, io_mode)
    if not buffer_entry then return false end
    properties.first_buffer_entry = buffer_entry
    -- caching storage unit capacity considering base capacity and capability override
    local capacity_override = (properties.capability_override or 1)
    local base_capacity = capacity_limits[entity_name][operation_mode]
    properties.capacity = base_capacity * capacity_override
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function StorageUnit.on_processing_stopped(properties)
    properties.operational = nil
    properties.capacity = nil
    properties.first_buffer_entry = nil
    -- removing entity from associated cluster
    ClusterProcessor.remove_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.first_cluster = nil
end

-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------

---Adds storage capacity of cluster storage unit to cluster
---@param properties EntityProperties
local function enable_storage_capacity(properties)
    properties.operational = ClusterProcessor.add_storage_capacity(
        properties.first_cluster,
        properties.unit_number,
        properties.first_buffer_entry,
        properties.capacity
    )
end

---Removes storage capacity of cluster storage unit from cluster
---@param properties EntityProperties
local function disable_storage_capacity(properties)
    ClusterProcessor.remove_storage_capacity(
        properties.first_cluster,
        properties.unit_number
    )
    properties.operational = false
end

---Used for on-tick processing of cluster storage units. Manages storage capacity
---provided by storage unit to cluster based on current entity.energy.
---@param properties EntityProperties
function StorageUnit.process_entity(properties)
    local entity = properties.entity
    ---@type number assuming storage unit has energy drain
    local energy_drain = entity.electric_drain
    local current_energy = entity.energy

    -- enabling/disabling storage unit based on energy level
    if current_energy < energy_drain then
        disable_storage_capacity(properties)
    elseif not properties.operational then
        enable_storage_capacity(properties)
    end
end

return StorageUnit