--[[
Cluster item IO is used to transfer items from physical factorio world
to internal virtual buffers of clusters and vice versa.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Mandatory entity configuration is provided:
    1. first_cluster. Used to determine the cluster entity should connect to.
    2. selected_item (name and quality). Used to determine buffer_key.
    3. io_mode. Used to determine the entity operation.
II. Entity is not located on a vsurface.
III. Selected cluster exists and this entity can be added to it.

Optional entity controls this building can have:
1. capability_override. Used to artificially lower flow limit of this entity.

Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. buffer_key. Used to access a specific cluster buffer entry
3. is_output. Used to determine entity operation
4. flow_limit. Determines maximum flow rate for this entity
5. inventory. Used to make calls to factorio API
6. io_request. Used to make calls to factorio API
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick processing:
1. ls_flow. Used to display entity work in the gui
2. operational. true if entity is marked operational in its clusters

Entity is considered operational when specified buffer entry is found in the
associated cluster. If it's not, entity is considered not operational.
If cluster is not found during an update, entity is moved to "incorrect".
--]]

local ClusterProcessor = require("scripts.simulation.cluster-processor")
local VSurfaceManager = require("scripts.world.vsurface-manager")
local Utilities = require("scripts.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local ClusterItemIO = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
ClusterItemIO.configuration = {
    "first_cluster",
    "selected_item_name",
    "selected_item_quality",
    "io_mode",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "cluster-item-io-mk1"] = 120,
    [PREFIX .. "cluster-item-io-mk2"] = 1200,
    [PREFIX .. "cluster-item-io-mk3"] = 12000,
}

---Maps entity names to their weights as cluster members
local weights = {
    [PREFIX .. "cluster-item-io-mk1"] = 1e-6,
    [PREFIX .. "cluster-item-io-mk2"] = 1e-5,
    [PREFIX .. "cluster-item-io-mk3"] = 1e-4,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function ClusterItemIO.initialize(properties)
    -- Checking that first cluster is provided
    local cluster_uuid = properties.first_cluster
    if not cluster_uuid then
        properties.status = Utilities.entity_status.no_primary_cluster
        return Utilities.registry_sections.incorrect
    end
    -- Checking that io mode is selected
    local io_mode = properties.io_mode
    if not io_mode then
        properties.status = Utilities.entity_status.no_io_mode
        return Utilities.registry_sections.incorrect
    end
    -- Checking that item and quality are selected
    local item_name = properties.selected_item_name
    local item_quality = properties.selected_item_quality
    if not item_name or not item_quality then
        properties.status = Utilities.entity_status.no_selected_item
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
    properties.buffer_key = item_name .. "//" .. item_quality
    properties.is_output = (io_mode == "output")
    local base_flow = flow_limits[entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    local override = properties.capability_override or 1
    properties.flow_limit = base_flow * quality_mult * override
    properties.inventory = entity.get_inventory(defines.inventory.chest)
    properties.io_request = {
        name = item_name,
        quality = item_quality,
        count = 0
    }
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function ClusterItemIO.uninitialize(properties)
    ClusterProcessor.remove_member_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.buffer_key = nil
    properties.is_output = nil
    properties.flow_limit = nil
    properties.inventory = nil
    properties.io_request = nil
    properties.ls_flow = nil
    properties.operational = nil
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function ClusterItemIO.update(properties)
    properties.ls_flow = 0

    -- Attempting to reach specified cluster buffer entry
    local buffer_entry = ClusterProcessor.get_buffer_entry(
        properties.first_cluster,
        properties.buffer_key,
        properties.io_mode
    )
    if not buffer_entry then
        -- buffer not found: checking for cluster existence
        if not ClusterProcessor.does_cluster_exist(properties.first_cluster) then
            properties.status = Utilities.entity_status.cluster_deleted
            return Utilities.registry_sections.incorrect
        end
        -- cluster exists: marking entity as not operational
        if properties.operational then
            ClusterProcessor.mark_member_not_operational(
                properties.first_cluster,
                properties.unit_number
            )
            properties.operational = false
        end
        properties.status = Utilities.entity_status.entry_not_found
        return Utilities.registry_sections.stalled
    end
    -- buffer entry found: marking entity as operational in the cluster
    if not properties.operational then
        properties.operational = true
        ClusterProcessor.mark_member_operational(
            properties.first_cluster,
            properties.unit_number
        )
        properties.status = Utilities.entity_status.operational
    end

    -- Buffer entry is found: attempting to transfer items
    if properties.is_output then
        -- Output mode: from cluster to world
        local current_amount = ClusterProcessor.get_current_amount(
            buffer_entry
        )
        local to_transfer = math.min(
            properties.flow_limit,
            current_amount
        )
        if to_transfer >= 1 then
            local io_request = properties.io_request
            ---@cast io_request ItemStackDefinition
            io_request.count = to_transfer
            local inserted_count = properties.inventory.insert(io_request)
            ClusterProcessor.remove_from_buffer_entry(
                buffer_entry,
                inserted_count
            )
            properties.ls_flow = inserted_count
        end
    else
        -- Input mode: from world to cluster
        local available_space = ClusterProcessor.get_available_space(
            buffer_entry
        )
        local to_transfer = math.min(
            properties.flow_limit,
            available_space
        )
        if to_transfer >= 1 then
            local io_request = properties.io_request
            ---@cast io_request ItemStackDefinition
            io_request.count = to_transfer
            local removed_count = properties.inventory.remove(io_request)
            ClusterProcessor.add_to_buffer_entry(
                buffer_entry,
                removed_count
            )
            properties.ls_flow = removed_count
        end
    end
    return Utilities.registry_sections.active
end

return ClusterItemIO