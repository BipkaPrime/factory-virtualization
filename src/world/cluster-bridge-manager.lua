---Cluster bridges transfer item/fluid/energy from output of one cluster to
---input of another cluster. For each cluster bridge following fields can be selected:
---source template, destination template, mode of operation (item/fluid/energy),
---item to transfer for items, fluid to transfer for fluids.

local ClusterProcessor = require("src.simulation.cluster-processor")

local ClusterBridge = {}

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
    properties.source_cluster = ClusterProcessor.add_to_cluster(
        properties.entity,
        properties.destination_template
    )
end

---On-tick updater for inter cluster bridge
---@param properties ClusterBridgeProperties
function ClusterBridge.process_bridge(properties)

end

return ClusterBridge