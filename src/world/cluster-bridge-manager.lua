---Cluster bridges transfer item/fluid/energy from output of one cluster to
---input of another cluster. For each cluster bridge following fields can be selected:
---source template, destination template, mode of operation (item/fluid/energy),
---item to transfer for items, fluid to transfer for fluids.

local ClusterProcessor = require("src.simulation.cluster-processor")

local PREFIX = "FV-"
local ClusterBridge = {}


local flow_limits = {
    [PREFIX .. "inter-cluster-bridge-mk1"] = {
        item = 1e6,
        fluid = 1e6,
        energy = 1e12,
    },
    [PREFIX .. "inter-cluster-bridge-mk2"] = {
        item = 1e9,
        fluid = 1e9,
        energy = 1e15,
    },
    [PREFIX .. "inter-cluster-bridge-mk3"] = {
        item = 1e12,
        fluid = 1e12,
        energy = 1e18,
    },
}

---Function that is called when source cluster is changed
---@param properties InterClusterBridgeProperties
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
---@param properties InterClusterBridgeProperties
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
---@param properties InterClusterBridgeProperties
function ClusterBridge.process_bridge(properties)
    -- does not operate on a vsurface
    if properties.on_vsurface then return end

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
    properties.ls_flow = transfered
    if transfered <= 0 then return end

    ClusterProcessor.remove_from_buffer(source_cluster, buffer_key, transfered)
    ClusterProcessor.add_to_buffer(destination_cluster, buffer_key, transfered)
end

return ClusterBridge