--[[
Cluster overflow controller is used to void overflow in one
cluster buffer entry. It consumes electric energy and works only
when building has enough power.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Mandatory entity configuration is provided:
    1. first_cluster. Used to determine the cluster entity should connect to.
    2. operation_mode. Used to determine buffer_key.
    3. selected_item (only for "item" mode). Used to determine buffer_key.
    4. selected_fluid (only for "fluid" mode). Used to determine buffer_key.
    5. overflow_threshold. Used to determine what is considered an overflow.
II. Entity is not located on a vsurface.
III. Selected cluster exists and this entity can be added to it.

Optional entity controls this building can have:
1. capability_override. Used to artificially lower flow rate of this entity.

Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. buffer_key. Used to access a specific cluster buffer entry
3. flow_limit. Determines maximum flow rate for this entity
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick processing:
1. ls_flow. Used to display entity work in the gui
2. operational. true if entity is marked operational in its clusters

Entity is considered operational when:
1. Specified buffer entry is found in the associated cluster.
2. Entity has enough electric energy stored.

If cluster is not found during an update, entity is moved to "incorrect".
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local OverflowController = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
OverflowController.configuration = {
    "first_cluster",
    "operation_mode",
    "overflow_threshold",
    "selected_item_name",
    "selected_item_quality",
    "selected_fluid",
    "capability_override",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "cluster-overflow-controller-mk1"] = {
        item = 1e6,
        fluid = 1e7,
        energy = 1e12,
    },
    [PREFIX .. "cluster-overflow-controller-mk2"] = {
        item = 1e9,
        fluid = 1e10,
        energy = 1e15,
    },
    [PREFIX .. "cluster-overflow-controller-mk3"] = {
        item = 1e12,
        fluid = 1e13,
        energy = 1e18,
    },
}

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "cluster-overflow-controller-mk1"] = 2e-5,
    [PREFIX .. "cluster-overflow-controller-mk2"] = 2e-4,
    [PREFIX .. "cluster-overflow-controller-mk3"] = 2e-3,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function OverflowController.initialize(properties)
    -- Checking that first cluster is provided
    local cluster_uuid = properties.first_cluster
    if not cluster_uuid then
        properties.status = Utilities.entity_status.no_primary_cluster
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
    -- Checking that fluid name is provided in "fluid" mode
    local selected_fluid = properties.selected_fluid
    if operation_mode == "fluid" and not selected_fluid then
        properties.status = Utilities.entity_status.no_selected_fluid
        return Utilities.registry_sections.incorrect
    end
    -- Checking that overflow threshold is provided
    local overflow_threshold = properties.overflow_threshold
    if not overflow_threshold then
        properties.status = Utilities.entity_status.no_overflow_threshold
        return Utilities.registry_sections.incorrect
    end
    -- Checking that entity is not located on a virtualization surface
    local entity = properties.entity
    if VSurfaceManager.is_vsurface(entity.surface_index) then
        properties.status = Utilities.entity_status.vsurface_no_work
        return Utilities.registry_sections.incorrect
    end
    -- Checking that cluster exists
    if not ClusterProcessor.does_cluster_exist(cluster_uuid) then
        properties.status = Utilities.entity_status.cluster_not_found
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
        properties.status = Utilities.entity_status.cluster_cant_connect
        return Utilities.registry_sections.incorrect
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    properties.buffer_key = Utilities.generate_multimode_buffer_key(properties)
    local base_flow = flow_limits[entity_name][operation_mode]
    local quality_mult = 1 + 0.5 * entity.quality.level
    local override = (properties.capability_override or 1)
    properties.flow_limit = base_flow * quality_mult * override
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function OverflowController.uninitialize(properties)
    ClusterProcessor.remove_member_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.buffer_key = nil
    properties.flow_limit = nil
    properties.ls_flow = nil
    properties.operational = nil
end

---Switches entity to operational state
---@param properties EntityProperties
local function switch_to_operational(properties)
    if properties.operational then return end
    ClusterProcessor.mark_member_operational(
        properties.first_cluster,
        properties.unit_number
    )
    properties.operational = true
    properties.status = Utilities.entity_status.operational
end

---Switches entity to not operational state
---@param properties EntityProperties
local function switch_to_not_operational(properties)
    if not properties.operational then return end
    ClusterProcessor.mark_member_not_operational(
        properties.first_cluster,
        properties.unit_number
    )
    properties.operational = false
end

local output = "output"
---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function OverflowController.update(properties)
    properties.ls_flow = 0

    -- Attempting to reach specified cluster buffer entry
    local buffer_entry = ClusterProcessor.get_buffer_entry(
        properties.first_cluster,
        properties.buffer_key,
        output
    )
    if not buffer_entry then
        -- buffer not found: checking for cluster existence
        if not ClusterProcessor.does_cluster_exist(properties.first_cluster) then
            properties.status = Utilities.entity_status.cluster_deleted
            return Utilities.registry_sections.incorrect
        end
        -- cluster exists: marking entity as not operational
        switch_to_not_operational(properties)
        properties.status = Utilities.entity_status.entry_not_found
        return Utilities.registry_sections.stalled
    end

    -- Everything ok: normal operation
    local entity = properties.entity
    local power_usage = entity.power_usage
    local current_energy = entity.energy
    if current_energy > power_usage then
        -- there is enough energy: entity is operational
        switch_to_operational(properties)
        properties.ls_flow = ClusterProcessor.void_overflow(
            buffer_entry,
            properties.flow_limit,
            properties.overflow_threshold
        )
    else
        -- there is not enough energy: entity is not operational
        switch_to_not_operational(properties)
        properties.status = Utilities.entity_status.not_enough_power
    end
    return Utilities.registry_sections.active
end

return OverflowController