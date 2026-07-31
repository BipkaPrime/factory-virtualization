local ClusterProcessor = require("src.simulation.cluster-processor")


local OverflowController = {}

---Updates cluster overflow controller
---@param properties EntityProperties
function OverflowController.process_entity(properties)
    properties.ls_flow = 0
    -- does not operate on a vsurface
    if properties.on_vsurface then return end

    -- does not operate without connection to a cluster
    local cluster = properties.first_cluster
    if not cluster then return end

    -- does not operate without buffer key
    local buffer_key = properties.buffer_key
    if not buffer_key then return end

    -- does not operate without threshold
    local threshold = properties.overflow_threshold
    if not threshold then return end

    local flow_override = (properties.capability_override or 1)
    -- assuming flow limit was cached
    local flow_limit = properties.flow_limit * flow_override

    -- have to check that buffer key corresponds to a valid buffer entry in cluster
    local output_capacity = ClusterProcessor.get_output_capacity(cluster, buffer_key)
    -- buffer entry is empty or does not exist
    if output_capacity == 0 then return end

    local voided_amount = ClusterProcessor.void_overflow(
        cluster,
        buffer_key,
        flow_limit,
        threshold
    )
    properties.ls_flow = voided_amount
end

return OverflowController