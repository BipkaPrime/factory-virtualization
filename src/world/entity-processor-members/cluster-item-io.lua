--[[
Cluster item IO is used to transfer items from physical factorio world
to internal virtual buffers of clusters and vice versa. It connects to
one buffer entry and operates with it.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. First template. Used to determine the cluster this entity
        should connect to.
    2. IO mode. Used to determine the entity operation.
    3. Selected item. Used to determine the buffer entry this entity
        should connect to.
II. Entity is not located on a vsurface.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. First cluster. Used to remove entity from cluster when necessery
2. First buffer entry. Used to make calls to cluster processor
3. Is output. Used to determine entity operation
4. Flow limit. Used to make calls to factorio API
5. Inventory. Used to make calls to factorio API

Properties that can be assigned during on-tick processing:
1. Ls flow. Can be used to track entity work.
2. selected_item.count. Used to make calls to factorio API
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")


local PREFIX = "FV-"
local ClusterItemIO = {}

---List of all copyable properties of this entity
ClusterItemIO.copyable = {
    "first_template",
    "io_mode",
    "selected_item"
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "cluster-item-io-mk1"] = 100,
    [PREFIX .. "cluster-item-io-mk2"] = 1000,
    [PREFIX .. "cluster-item-io-mk3"] = 10000,
}

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "cluster-item-io-mk1"] = 1,
    [PREFIX .. "cluster-item-io-mk2"] = 10,
    [PREFIX .. "cluster-item-io-mk3"] = 100,
}

---Checks that all requirements for operation of cluster item IO are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function ClusterItemIO.attempt_entity_initialization(properties)
    -- 1. First template is selected
    local first_template = properties.first_template
    if not first_template then return false end
    -- 2. IO mode is selected
    local io_mode = properties.io_mode
    if not io_mode then return false end
    -- 3. Item is selected
    local selected_item = properties.selected_item
    if not selected_item then return false end
    -- 4. Entity is not located on a vsurface
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
    local buffer_key = selected_item.name .. "//" .. selected_item.quality
    local buffer_entry = ClusterProcessor.get_buffer_entry(cluster, buffer_key, io_mode)
    if not buffer_entry then return false end
    properties.first_buffer_entry = buffer_entry
    -- assigning io mode flag to entity
    properties.is_output = (io_mode == "output")
    -- caching flow limit of the entity
    properties.flow_limit = flow_limits[entity_name]
    -- caching LuaInventory of the entity
    properties.inventory = entity.get_inventory(defines.inventory.chest)
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function ClusterItemIO.on_processing_stopped(properties)
    properties.ls_flow = nil
    properties.selected_item.count = nil
    properties.inventory = nil
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

---Used for on-tick processing of cluster item IOs.
---@param properties EntityProperties
function ClusterItemIO.process_entity(properties)
    properties.ls_flow = 0
    if properties.is_output then
        -- current available amount in the cluster buffer entry
        local current_amount = ClusterProcessor.get_current_amount(
            properties.first_buffer_entry
        )
        local to_transfer = math.min(
            properties.flow_limit,
            current_amount
        )
        if to_transfer >= 1 then
            ---@type ItemSelection assuming selected item is present
            local selected_item = properties.selected_item
            selected_item.count = to_transfer
            ---@diagnostic disable-next-line: param-type-mismatch
            local inserted_count = properties.inventory.insert(selected_item)
            ClusterProcessor.remove_from_buffer_entry(
                properties.first_buffer_entry,
                inserted_count
            )
            properties.ls_flow = inserted_count
        end
    else
        local available_space = ClusterProcessor.get_available_space(
            properties.first_buffer_entry
        )
        local to_transfer = math.min(
            properties.flow_limit,
            available_space
        )
        if to_transfer >= 1 then
            ---@type ItemSelection assuming selected item is present
            local selected_item = properties.selected_item
            selected_item.count = to_transfer
            ---@diagnostic disable-next-line: param-type-mismatch
            local removed_count = properties.inventory.remove(selected_item)
            ClusterProcessor.add_to_buffer_entry(
                properties.first_buffer_entry,
                removed_count
            )
            properties.ls_flow = removed_count
        end
    end
end

return ClusterItemIO