--[[
Cluster energy IO is used to transfer electric energy from physical factorio world
to internal virtual buffers of clusters and vice versa. It connects to one
buffer entry and operates with it.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. First template. Used to determine the cluster this entity
        should connect to.
    2. IO mode. Used to determine the entity operation.
II. Entity is not located on a vsurface.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. First cluster. Used to remove entity from cluster when necessery
2. First buffer entry. Used to make calls to cluster processor
3. Is output. Used to determine entity operation
4. Flow limit. Used to make calls to factorio API

Properties that can be assigned during on-tick processing:
1. Ls flow. Can be used to track entity work.
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")


local PREFIX = "FV-"
local ClusterEnergyIO = {}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "cluster-energy-io-mk1"] = 1e8,
    [PREFIX .. "cluster-energy-io-mk2"] = 1e9,
    [PREFIX .. "cluster-energy-io-mk3"] = 1e10,
}

---Checks that all requirements for operation of cluster energy IO are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function ClusterEnergyIO.attempt_entity_initialization(properties)
    -- 1. First template is selected
    local first_template = properties.first_template
    if not first_template then return false end
    -- 2. IO mode is selected
    local io_mode = properties.io_mode
    if not io_mode then return false end
    -- 3. Entity is not located on a vsurface
    local entity = properties.entity
    if VSurfaceManager.get_vsurface_data(entity.surface_index) then return false end

    ---All requirements are met. Preparing properties for on-tick processing
    -- attempting to connect entity to cluster
    local cluster = ClusterProcessor.add_to_cluster(entity, first_template)
    if not cluster then return false end
    properties.first_cluster = cluster
    -- attempting to assign buffer entry to entity
    local buffer_key = "electric_energy"
    local buffer_entry = ClusterProcessor.get_buffer_entry(cluster, buffer_key, io_mode)
    if not buffer_entry then return false end
    properties.first_buffer_entry = buffer_entry
    -- assigning io mode flag to entity
    properties.is_output = (io_mode == "output")
    -- caching flow limit of the entity
    properties.flow_limit = flow_limits[properties.entity_name]
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function ClusterEnergyIO.on_processing_stopped(properties)
    properties.ls_flow = nil
    properties.flow_limit = nil
    properties.is_output = nil
    properties.first_buffer_entry = nil
    -- removing entity from associated cluster
    ClusterProcessor.remove_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.first_cluster = nil
end

---Used for on-tick processing of cluster energy IOs.
---@param properties EntityProperties
function ClusterEnergyIO.process_entity(properties)
    properties.ls_flow = 0

    local entity = properties.entity
    if properties.is_output then
        ---Moving energy from cluster to physical factorio world
        -- current available amount in the cluster buffer entry
        local available_amount = ClusterProcessor.get_current_amount(
            properties.first_buffer_entry
        )
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
            ClusterProcessor.remove_from_buffer_entry(
                properties.first_buffer_entry,
                to_transfer
            )
            properties.ls_flow = to_transfer
        end
    else
        ---Moving energy from physical factorio world to cluster
        -- getting available space in cluster input
        local available_space = ClusterProcessor.get_available_space(
            properties.first_buffer_entry
        )
        local available_amount = entity.energy
        local to_transfer = math.min(
            available_space,
            available_amount,
            properties.flow_limit
        )
        if to_transfer >= 1 then
            entity.energy = available_amount - to_transfer
            ClusterProcessor.add_to_buffer_entry(
                properties.first_buffer_entry,
                to_transfer
            )
            properties.ls_flow = to_transfer
        end
    end
end

return ClusterEnergyIO