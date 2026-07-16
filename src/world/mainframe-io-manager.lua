-- Mainframe IOs are used for transfering items to/from vclusters.

local ClusterProcessor = require("src.simulation.cluster-processor")

local PREFIX = "FV-"
local MainframeIO = {}

local flow_limits = {
    [PREFIX .. "mainframe-item-io"] = 1000,
    [PREFIX .. "mainframe-fluid-io"] = 10000,
    [PREFIX .. "mainframe-energy-io"] = 1e9,
}

---Updates given mainframe item io
---@param properties MItemIOProperties
function MainframeIO.process_mainframe_item_io(properties)
    -- does not operate without selected item
    local item = properties.selected_item
    if not item then return end

    -- does not operate without connection to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting inventory and flow limit
    local entity = properties.entity
    local inventory = properties.inventory
    local flow_limit = flow_limits[entity.name]

    ---@type string assuming buffer key is generated
    local buffer_key = properties.buffer_key
    if properties.is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available <= 1 then return end

        -- moving items from cluster to entity inventory
        item.count = math.min(flow_limit, available)
        ---@diagnostic disable-next-line: param-type-mismatch
        local inserted_count = inventory.insert(item)
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, inserted_count)
    else
        local available_space = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available_space <= 1 then return end

        -- moving items from physical inventory to cluster
        item.count = math.min(flow_limit, available_space)
        ---@diagnostic disable-next-line: param-type-mismatch
        local removed_count = inventory.remove(item)
        ClusterProcessor.add_to_buffer(cluster, buffer_key, removed_count)
    end
end

---Updates given mainframe fluid io
---@param properties MFluidIOProperties
function MainframeIO.process_mainframe_fluid_io(properties)
    -- does not operate without selected fluid
    local fluid = properties.selected_fluid
    if not fluid then return end

    -- does not operate without connecting to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    local entity = properties.entity
    local flow_limit = flow_limits[entity.name]
    if properties.is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, fluid.name)
        if available <= 0 then return end

        -- moving fluid from vcluster to physical inventory
        fluid.amount = math.min(flow_limit, available)
        ---@diagnostic disable-next-line: param-type-mismatch
        local inserted_amount = entity.insert_fluid(fluid)
        ClusterProcessor.remove_from_buffer(cluster, fluid.name, inserted_amount)
    else
        -- getting available space
        local available = ClusterProcessor.get_input_space(cluster, fluid.name)
        if available <= 0 then return end

        -- moving fluid from physical inventory to vcluster
        fluid.amount = math.min(flow_limit, available)
        ---@diagnostic disable-next-line: param-type-mismatch
        local removed_amount = entity.extract_fluid(fluid)
        ClusterProcessor.add_to_buffer(cluster, fluid.name, removed_amount)
    end
end

---Updates given mainframe energy io
---@param properties MEnergyIOProperties
function MainframeIO.process_mainframe_energy_io(properties)
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