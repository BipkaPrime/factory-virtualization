--[[
Mainframe IOs are used for transfering items to/from vclusters.

Mainframe IOs have following properties in entity registry.
entity LuaEntity: reference to entity
unit_number uint64: unit number of this entity (not really relevant while entity is valid)
selected_template string|nil: selected template for a given entity if any (user input)
is_output bool|nil: true if IO is an output. By default IO is considered an input.
active_template string|nil: name of template currently in operation
selected_item table|nil (only item IO): {name = string, quality = string}
selected_fluid string|nil (only fluid IO): name of selected fluid if any
buffer_key string|nil: key in cluster buffer
cluster table: reference to virtualization cluster that owns this IO if any.
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local EntityParams = require("world.entity-params")

local MainframeIO = {}


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
    local params = EntityParams.get_entity_params(entity.name)
    local flow_limit = params.flow_limit

    local item = properties.selected_item
    if properties.is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available <= 0 then return end

        -- moving items from cluster to entity inventory
        local inserted_count = inventory.insert({
            name = item.name,
            quality = item.quality,
            count = math.min(flow_limit, available)
        })
        ClusterProcessor.process_buffer_output(cluster, buffer_key, inserted_count)
    else
        local available = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available <= 0 then return end

        -- moving items from physical inventory to cluster
        local removed_count = inventory.remove({
            name = item.name,
            quality = item.quality,
            count = math.min(flow_limit, available)
        })
        ClusterProcessor.process_buffer_input(cluster, buffer_key, removed_count)
    end
end

---Updates given mainframe fluid io
---@param properties table entity data from entity registry
function MainframeIO.process_mainframe_fluid_io(properties)
    -- giving this entity a chance to change active template
    process_template_change(properties)

    -- does not operate without selected fluid
    local buffer_key = properties.buffer_key
    if not buffer_key then return end

    -- does not operate without connecting to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    local entity = properties.entity
    local flow_limit = EntityParams.get_entity_params(entity.name).flow_limit
    local fluid = properties.selected_fluid
    if properties.is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available <= 0 then return end

        -- moving fluid from vcluster to physical inventory
        local inserted_amount = entity.insert_fluid({
            name = fluid,
            amount = math.min(flow_limit, available)
        })
        ClusterProcessor.process_buffer_output(cluster, buffer_key, inserted_amount)
    else
        -- getting available space
        local available = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available <= 0 then return end

        -- moving fluid from physical inventory to vcluster
        local removed_amount = entity.extract_fluid({
            name = fluid,
            amount = math.min(flow_limit, available)
        })
        ClusterProcessor.process_buffer_input(cluster, buffer_key, removed_amount)
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
    local flow_limit = EntityParams.get_entity_params(entity.name).flow_limit
    if properties.is_output then
        -- getting available products
        local available_amount = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available_amount <= 0 then return end

        -- moving energy from vcluster to entity
        local available_space = entity.electric_buffer_size - entity.energy
        local transfered = math.min(flow_limit, available_amount, available_space)
        entity.energy = entity.energy + transfered
        ClusterProcessor.process_buffer_output(cluster, buffer_key, transfered)
    else
        -- getting available space in cluster input
        local available_space = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available_space <= 0 then return end

        -- moving energy from entity to vcluster
        local transfered = math.min(available_space, flow_limit, entity.energy)
        entity.energy = entity.energy - transfered
        ClusterProcessor.process_buffer_input(cluster, buffer_key, transfered)
    end
end

return MainframeIO