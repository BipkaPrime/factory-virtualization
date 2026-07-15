--[[
Mainframe IOs are used for transfering items to/from vclusters.

-------------------------------------------------------------------------------
MAINFRAME IO PROPERTIES
-------------------------------------------------------------------------------
entity LuaEntity: reference to entity object 
unit_number number: unique entity identifier
selected_template string|nil: name of selected template (user input)
active_template string|nil: name of template in operation (assigned by processor)
cluster table|nil: reference to virtualization cluster that includes this entity
is_output bool|nil: true if entity is output
selected_item table|nil (item-io): {name = string, quality = string} (user input)
buffer_key string|nil (item-io): "name//quality" (assigned by processor for fast access)
selected_fluid string|nil (fluid-io): name of selected fluid if any (user input)
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")

local PREFIX = "FV-"
local MainframeIO = {}

local flow_limits = {
    [PREFIX .. "mainframe-item-io"] = 500,
    [PREFIX .. "mainframe-fluid-io"] = 10000,
    [PREFIX .. "mainframe-energy-io"] = 1e9,
}

---Checks if template change has occured and in case it did,
---moves mainframe IO to the new virtualization cluster
---@param properties table entity data from entity registry
local function process_template_change(properties)
    if properties.selected_template ~= properties.active_template then
        -- removing entity from its old cluster
        local old_cluster = properties.cluster
        local unit_number = properties.unit_number
        ClusterProcessor.remove_from_cluster(old_cluster, unit_number)

        -- adding entity to its new cluster
        local entity = properties.entity
        local template_name = properties.selected_template
        local new_cluster = ClusterProcessor.add_to_cluster(entity, template_name)
        properties.cluster = new_cluster

        properties.active_template = properties.selected_template
    end
end

---Updates given mainframe item io
---@param properties table entity data from entity registry
function MainframeIO.process_mainframe_item_io(properties)
    -- giving this entity a chance to change active template
    process_template_change(properties)

    -- does not operate without selected item
    local buffer_key = properties.buffer_key
    if not buffer_key then return end

    -- does not operate without connection to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting inventory and flow limit
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local flow_limit = flow_limits[entity.name]

    local item = properties.selected_item
    if properties.is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available <= 1 then return end

        -- moving items from cluster to entity inventory
        local inserted_count = inventory.insert{
            name = item.name,
            quality = item.quality,
            count = math.min(flow_limit, available)
        }
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, inserted_count)
    else
        local available_space = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available_space <= 1 then return end

        -- moving items from physical inventory to cluster
        local removed_count = inventory.remove{
            name = item.name,
            quality = item.quality,
            count = math.min(flow_limit, available_space)
        }
        ClusterProcessor.add_to_buffer(cluster, buffer_key, removed_count)
    end
end

---Updates given mainframe fluid io
---@param properties table entity data from entity registry
function MainframeIO.process_mainframe_fluid_io(properties)
    -- giving this entity a chance to change active template
    process_template_change(properties)

    -- does not operate without selected fluid
    local fluid_name = properties.selected_fluid
    if not fluid_name then return end

    -- does not operate without connecting to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    local entity = properties.entity
    local flow_limit = flow_limits[entity.name]
    if properties.is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, fluid_name)
        if available <= 0 then return end

        -- moving fluid from vcluster to physical inventory
        local inserted_amount = entity.insert_fluid({
            name = fluid_name,
            amount = math.min(flow_limit, available)
        })
        ClusterProcessor.remove_from_buffer(cluster, fluid_name, inserted_amount)
    else
        -- getting available space
        local available = ClusterProcessor.get_input_space(cluster, fluid_name)
        if available <= 0 then return end

        -- moving fluid from physical inventory to vcluster
        local removed_amount = entity.extract_fluid({
            name = fluid_name,
            amount = math.min(flow_limit, available)
        })
        ClusterProcessor.add_to_buffer(cluster, fluid_name, removed_amount)
    end
end

---Updates given mainframe energy io
---@param properties table entity data from entity registry
function MainframeIO.process_mainframe_energy_io(properties)
    -- giving this entity a chance to change active template
    process_template_change(properties)

    -- making sure entity is connected to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    local buffer_key = "electric_energy"
    local entity = properties.entity
    local flow_limit = flow_limits[entity.name]
    if properties.is_output then
        -- getting available products
        local available_amount = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available_amount <= 0 then return end

        -- moving energy from vcluster to entity
        local available_space = entity.electric_buffer_size - entity.energy
        local transfered = math.min(flow_limit, available_amount, available_space)
        entity.energy = entity.energy + transfered
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, transfered)
    else
        -- getting available space in cluster input
        local available_space = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available_space <= 0 then return end

        -- moving energy from entity to vcluster
        local transfered = math.min(available_space, flow_limit, entity.energy)
        entity.energy = entity.energy - transfered
        ClusterProcessor.add_to_buffer(cluster, buffer_key, transfered)
    end
end

return MainframeIO