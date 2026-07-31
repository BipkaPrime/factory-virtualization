--[[
Cluster bridges transfer item/fluid/energy from output of one cluster to
input of another cluster. For each cluster bridge following fields can be selected:
source template, destination template, mode of operation (item/fluid/energy),
item to transfer for items, fluid to transfer for fluids.
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")

local ClusterBridge = {}

---On-tick updater for inter cluster bridge
---@param properties EntityProperties
function ClusterBridge.process_bridge(properties)
    properties.ls_flow = 0
    -- does not operate on a vsurface
    if properties.on_vsurface then return end

    -- does not operate without source cluster
    local source_cluster = properties.first_cluster
    if not source_cluster then return end

    -- does not operate without destination cluster
    local destination_cluster = properties.second_cluster
    if not destination_cluster then return end

    -- does not operate without buffer key
    local buffer_key = properties.buffer_key
    if not buffer_key then return end

    ---@type number assuming flow limit was cached
    local flow_limit = properties.flow_limit
    local output_limit = ClusterProcessor.get_output_capacity(source_cluster, buffer_key)
    local input_limit = ClusterProcessor.get_input_space(destination_cluster, buffer_key)
    local transfered = math.min(flow_limit, output_limit, input_limit)
    properties.ls_flow = transfered
    if transfered <= 0 then return end

    ClusterProcessor.remove_from_buffer(source_cluster, buffer_key, transfered)
    ClusterProcessor.add_to_buffer(destination_cluster, buffer_key, transfered)
end

return ClusterBridge