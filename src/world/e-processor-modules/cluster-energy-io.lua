--[[
Cluster energy IO is used to transfer electric energy from physical factorio world
to internal virtual buffers of clusters and vice versa. It connects to one
buffer entry and operates with it.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. First cluster. Used to determine the cluster this entity
        should connect to.
    2. IO mode. Used to determine the entity operation.
II. Entity is not located on a vsurface.
III. Selected cluster exists and this entity can be added to it.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. buffer_key. Used to access a specific cluster buffer entry
3. is_output. Used to determine entity operation
4. flow_limit. Determines maximum flow rate for this entity

Properties that can be assigned during on-tick processing:
1. ls_flow. Used to display entity work in the gui
2. operational. true if entity is marked operational in its clusters
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local ClusterEnergyIO = {}


---List of all copyable properties of this entity
---@type table<EntityConfigField, EntityConfigRole>
ClusterEnergyIO.configuration = {
    first_cluster = "primary_cluster",
    io_mode = "io_cluster_logistics",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "cluster-energy-io-mk1"] = 2.4e8,
    [PREFIX .. "cluster-energy-io-mk2"] = 2.4e9,
    [PREFIX .. "cluster-energy-io-mk3"] = 2.4e10,
}

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "cluster-energy-io-mk1"] = 1e-6,
    [PREFIX .. "cluster-energy-io-mk2"] = 1e-5,
    [PREFIX .. "cluster-energy-io-mk3"] = 1e-4,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function ClusterEnergyIO.initialize(properties)
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
    properties.buffer_key = "electric_energy"
    properties.is_output = (io_mode == "output")
    -- TODO: configure electric energy priority
    local base_flow = flow_limits[entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    properties.flow_limit = base_flow * quality_mult
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function ClusterEnergyIO.uninitialize(properties)
    ClusterProcessor.remove_member_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.buffer_key = nil
    properties.is_output = nil
    properties.flow_limit = nil
    properties.ls_flow = nil
    properties.operational = nil
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function ClusterEnergyIO.update(properties)
    properties.ls_flow = 0

    -- Attempting to reach specified cluster buffer entry
    local is_output = properties.is_output
    local buffer_entry = ClusterProcessor.get_buffer_entry(
        properties.first_cluster,
        properties.buffer_key,
        is_output
    )
    if not buffer_entry then
        properties.operational = false
        -- buffer not found: checking for cluster existence
        if not ClusterProcessor.does_cluster_exist(properties.first_cluster) then
            properties.status = Utilities.entity_status.cluster_deleted
            return Utilities.registry_sections.incorrect
        end
        -- cluster exists: marking entity as not operational
        properties.operational = false
        ClusterProcessor.mark_member_not_operational(
            properties.first_cluster,
            properties.unit_number
        )
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

    -- Buffer entry is found: attempting to transfer energy
    local entity = properties.entity
    if properties.is_output then
        -- Output mode: from cluster to world
        local available_amount = ClusterProcessor.get_current_amount(buffer_entry)
        local current_energy = entity.energy
        -- space available in entity.energy
        local available_space = entity.electric_buffer_size - current_energy
        local to_transfer = math.min(
            available_amount,
            available_space,
            properties.flow_limit
        )
        if to_transfer >= 1 then
            entity.energy = current_energy + to_transfer
            ClusterProcessor.remove_from_buffer_entry(buffer_entry, to_transfer)
            properties.ls_flow = to_transfer
        end
    else
        -- Input mode: from world to cluster
        local available_space = ClusterProcessor.get_available_space(buffer_entry)
        local available_amount = entity.energy
        local to_transfer = math.min(
            available_space,
            available_amount,
            properties.flow_limit
        )
        if to_transfer >= 1 then
            entity.energy = available_amount - to_transfer
            ClusterProcessor.add_to_buffer_entry(buffer_entry, to_transfer)
            properties.ls_flow = to_transfer
        end
    end

    return Utilities.registry_sections.active
end

return ClusterEnergyIO