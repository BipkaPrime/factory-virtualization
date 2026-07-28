-- Cluster IOs are used for transfering items to/from vclusters.

local ClusterProcessor = require("src.simulation.cluster-processor")

local MainframeIO = {}

---Updates given cluster item io
---@param properties EntityProperties
function MainframeIO.process_cluster_item_io(properties)
    -- does not operate on vsurfaces
    if properties.on_vsurface then return end

    -- does not operate without selected item
    local item = properties.selected_item
    if not item then return end

    -- does not operate without connection to a cluster
    local cluster = properties.first_cluster
    if not cluster then return end

    ---@type LuaInventory assuming inventory was cached
    local inventory = properties.inventory
    ---@type number assuming flow limit was cached
    local flow_limit = properties.flow_limit
    ---@type string assuming buffer key is generated
    local buffer_key = properties.buffer_key
    if properties.is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available <= 1 then
            properties.ls_flow = 0
            return
        end

        -- moving items from cluster to entity inventory
        item.count = math.min(flow_limit, available)
        ---@diagnostic disable-next-line: param-type-mismatch
        local inserted_count = inventory.insert(item)
        properties.ls_flow = inserted_count
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, inserted_count)
    else
        local available_space = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available_space <= 1 then
            properties.ls_flow = 0
            return
        end

        -- moving items from physical inventory to cluster
        item.count = math.min(flow_limit, available_space)
        ---@diagnostic disable-next-line: param-type-mismatch
        local removed_count = inventory.remove(item)
        properties.ls_flow = removed_count
        ClusterProcessor.add_to_buffer(cluster, buffer_key, removed_count)
    end
end

---Updates given cluster fluid io
---@param properties EntityProperties
function MainframeIO.process_cluster_fluid_io(properties)
    -- does not operate on vsurfaces
    if properties.on_vsurface then return end

    -- does not operate without selected fluid
    local fluid = properties.selected_fluid
    if not fluid then return end

    -- does not operate without connecting to a cluster
    local cluster = properties.first_cluster
    if not cluster then return end

    local entity = properties.entity
    ---@type string assuming buffer key is generated
    local buffer_key = properties.buffer_key
    ---@type number assuming flow limit was cached
    local flow_limit = properties.flow_limit
    if properties.is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available <= 0 then
            properties.ls_flow = 0
            return
        end

        -- moving fluid from vcluster to physical inventory
        fluid.amount = math.min(flow_limit, available)
        ---@diagnostic disable-next-line: param-type-mismatch
        local inserted_amount = entity.insert_fluid(fluid)
        properties.ls_flow = inserted_amount
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, inserted_amount)
    else
        -- getting available space
        local available = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available <= 0 then
            properties.ls_flow = 0
            return
        end

        -- moving fluid from physical inventory to vcluster
        fluid.amount = math.min(flow_limit, available)
        ---@diagnostic disable-next-line: param-type-mismatch
        local removed_amount = entity.extract_fluid(fluid)
        properties.ls_flow = removed_amount
        ClusterProcessor.add_to_buffer(cluster, buffer_key, removed_amount)
    end
end

---Updates given cluster energy io
---@param properties EntityProperties
function MainframeIO.process_cluster_energy_io(properties)
    -- does not operate on vsurfaces
    if properties.on_vsurface then return end

    -- does not operate without connecting to a cluster
    local cluster = properties.first_cluster
    if not cluster then return end

    local entity = properties.entity
    ---@type string assuming buffer key is generated
    local buffer_key = properties.buffer_key
    ---@type number assuming flow limit was cached
    local flow_limit = properties.flow_limit
    if properties.is_output then
        -- getting available products
        local available_amount = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available_amount <= 0 then
            properties.ls_flow = 0
            return
        end

        -- moving energy from vcluster to entity
        local current_energy = entity.energy
        local available_space = entity.electric_buffer_size - current_energy
        local transfered = math.min(flow_limit, available_amount, available_space)
        entity.energy = current_energy + transfered
        properties.ls_flow = transfered
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, transfered)
    else
        -- getting available space in cluster input
        local available_space = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available_space <= 0 then
            properties.ls_flow = 0
            return
        end

        -- moving energy from entity to vcluster
        local current_energy = entity.energy
        local transfered = math.min(available_space, flow_limit, current_energy)
        entity.energy = current_energy - transfered
        properties.ls_flow = transfered
        ClusterProcessor.add_to_buffer(cluster, buffer_key, transfered)
    end
end

return MainframeIO