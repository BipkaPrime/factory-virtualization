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
    1. first_cluster. Used to determine the cluster that gets
        capacity increase.
    2. io_mode. Used to determine the buffer entry this entity will
        attempt to reach.
    3. operation_mode. Used to determine the buffer entry this entity will
        attempt to reach.
    4. Selected item (only for "item" mode). Used to determine the buffer
        entry this entity will attempt to reach.
    5. Selected fluid (only for "fluid" mode). Used to determine the buffer
        entry this entity will attempt to reach.
II. Entity is not located on a vsurface.
III. Selected cluster exists and this entity can be added to it.

Optional entity controls this building can have:
1. capability_override. Used to artificially lower provided capacity.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. buffer_key. Used to access a specific cluster buffer entry
3. capacity. Determines how much capacity is provided.

Properties that can be assigned during on-tick processing:
1. operational. true if entity is marked operational in its clusters
--]]


local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local StorageUnit = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
StorageUnit.configuration = {
    "first_cluster",
    "io_mode",
    "operation_mode",
    "selected_item_name",
    "selected_item_quality",
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
    [PREFIX .. "cluster-storage-unit-mk1"] = 1e-6,
    [PREFIX .. "cluster-storage-unit-mk2"] = 1e-5,
    [PREFIX .. "cluster-storage-unit-mk3"] = 1e-4,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function StorageUnit.initialize(properties)
    -- Checking that first cluster is provided
    local cluster_uuid = properties.first_cluster
    if not cluster_uuid then
        properties.status = Utilities.entity_status.no_primary_cluster
        return Utilities.registry_sections.incorrect
    end
    -- Checking that io mode is selected
    local io_mode = properties.io_mode
    if not io_mode then
        properties.status = Utilities.entity_status.no_io_mode_primary
        return Utilities.registry_sections.incorrect
    end
    -- Checking that operation mode is provided
    local operation_mode = properties.operation_mode
    if not operation_mode then
        properties.status = Utilities.entity_status.no_operation_mode
        return Utilities.registry_sections.incorrect
    end
    -- Checking that item name and quality are provided in "item" mode 
    local item_name = properties.selected_item_name
    local item_quality = properties.selected_item_quality
    if operation_mode == "item" and (not item_name or not item_quality) then
        properties.status = Utilities.entity_status.no_selected_item
        return Utilities.registry_sections.incorrect
    end
    -- Checking that fluid names is provided in "fluid" mode
    local selected_fluid = properties.selected_fluid
    if operation_mode == "fluid" and not selected_fluid then
        properties.status = Utilities.entity_status.no_selected_fluid
        return Utilities.registry_sections.incorrect
    end
    -- Checking that entity is not located on a virtualization surface
    local entity = properties.entity
    if VSurfaceManager.is_vsurface(entity.surface_index) then
        properties.status = Utilities.entity_status.vsurface_no_work
        return Utilities.registry_sections.incorrect
    end
    -- Attempting to add entity to its primary cluster
    local entity_name = properties.entity_name
    local status = ClusterProcessor.add_member_to_cluster(
        entity,
        cluster_uuid,
        weights[entity_name]
    )
    if not status then
        properties.status = Utilities.entity_status.cluster_not_found
        return Utilities.registry_sections.incorrect
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    properties.buffer_key = Utilities.generate_multimode_buffer_key(properties)
    local base_capacity = capacity_limits[entity_name][operation_mode]
    local override = (properties.capability_override or 1)
    properties.capacity = base_capacity * override
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function StorageUnit.uninitialize(properties)
    ClusterProcessor.remove_member_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.buffer_key = nil
    properties.capacity = nil
    properties.operational = nil
end

---Switches entity to operational state
---@param properties EntityProperties
local function switch_to_operational(properties)
    if properties.operational then return end
    ---@type string checked on initialization
    local cluster_uuid = properties.first_cluster
    local unit_number = properties.unit_number
    properties.operational = true
    ClusterProcessor.mark_member_operational(cluster_uuid, unit_number)
    ClusterProcessor.assign_member_buffer_capacity(
        cluster_uuid,
        unit_number,
        properties.buffer_key,
        properties.io_mode,
        properties.capacity
    )
end

---Switches entity to not operational state
---@param properties EntityProperties
local function switch_to_not_operational(properties)
    if not properties.operational then return end
    ---@type string checked on initialization
    local cluster_uuid = properties.first_cluster
    local unit_number = properties.unit_number
    properties.operational = false
    ClusterProcessor.mark_member_not_operational(
        cluster_uuid,
        unit_number
    )
    ClusterProcessor.remove_member_buffer_capacity(
        cluster_uuid,
        unit_number
    )
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function StorageUnit.update(properties)
    -- Checking if buffer entry exists in the cluster
    ---@type string checked on initialization
    local cluster_uuid = properties.first_cluster
    local buffer_entry = ClusterProcessor.get_buffer_entry(
        cluster_uuid,
        properties.buffer_key,
        properties.io_mode
    )
    if not buffer_entry then
        -- buffer not found: checking for cluster existence
        if not ClusterProcessor.does_cluster_exist(cluster_uuid) then
            properties.status = Utilities.entity_status.cluster_deleted
            return Utilities.registry_sections.incorrect
        end
        -- cluster exists: marking entity as not operational
        switch_to_not_operational(properties)
        properties.status = Utilities.entity_status.entry_not_found
        return Utilities.registry_sections.stalled
    end

    -- Buffer entry is found: normal operation
    local entity = properties.entity
    local power_usage = entity.power_usage
    local current_energy = entity.energy
    if current_energy > power_usage then
        -- there is enough energy: entity is operational
        switch_to_operational(properties)
        properties.status = Utilities.entity_status.operational
    else
        -- there is not enough energy: entity is not operational
        switch_to_not_operational(properties)
        properties.status = Utilities.entity_status.not_enough_power
    end
    return Utilities.registry_sections.active
end

return StorageUnit