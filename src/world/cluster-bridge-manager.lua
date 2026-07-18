---Cluster bridges transfer item/fluid/energy from output of one cluster to
---input of another cluster. For each cluster bridge following fields can be selected:
---source template, destination template, mode of operation (item/fluid/energy),
---item to transfer for items, fluid to transfer for fluids.

local ClusterProcessor = require("src.simulation.cluster-processor")

local PREFIX = "FV-"
local ClusterBridge = {}


local flow_limits = {
    [PREFIX .. "inter-cluster-bridge"] = {
        item = 1e5,
        fluid = 1e6,
        energy = 1e12,
    }
}

---Generates a buffer key for cluster bridge based on operation mode
---@param properties ClusterBridgeProperties
function ClusterBridge.generate_universal_buffer_key(properties)
    local mode = properties.mode
    if mode == "item" then
        local item = properties.selected_item
        properties.buffer_key = item and (item.name .. "//" .. item.quality) or nil
    elseif mode == "fluid" then
        local fluid = properties.selected_fluid
        properties.buffer_key = fluid and fluid.name or nil
    else
        properties.buffer_key = "electric_energy"
    end
end

---Function that is called when source cluster is changed
---@param properties ClusterBridgeProperties
function ClusterBridge.change_source_cluster(properties)
    ClusterProcessor.remove_from_cluster(
        properties.source_cluster,
        properties.unit_number
    )
    properties.source_cluster = ClusterProcessor.add_to_cluster(
        properties.entity,
        properties.source_template
    )
end

---Function that is called when destination cluster is changed
---@param properties ClusterBridgeProperties
function ClusterBridge.change_destination_cluster(properties)
    ClusterProcessor.remove_from_cluster(
        properties.destination_cluster,
        properties.unit_number
    )
    properties.destination_cluster = ClusterProcessor.add_to_cluster(
        properties.entity,
        properties.destination_template
    )
end

---On-tick updater for inter cluster bridge
---@param properties ClusterBridgeProperties
function ClusterBridge.process_bridge(properties)
    local source_cluster = properties.source_cluster
    local destination_cluster = properties.destination_cluster
    local buffer_key = properties.buffer_key
    if not source_cluster or not destination_cluster or not buffer_key then return end

    local mode = properties.mode
    local entity = properties.entity
    local flow_limit = flow_limits[entity.name][mode]
    local output_limit = ClusterProcessor.get_output_capacity(source_cluster, buffer_key)
    local input_limit = ClusterProcessor.get_input_space(destination_cluster, buffer_key)
    local transfered = math.min(flow_limit, output_limit, input_limit)
    if transfered <= 0 then return end


    ClusterProcessor.remove_from_buffer(source_cluster, buffer_key, transfered)
    ClusterProcessor.add_to_buffer(destination_cluster, buffer_key, transfered)
end

return ClusterBridge