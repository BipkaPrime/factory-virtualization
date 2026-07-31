local ClusterProcessor = require("src.simulation.cluster-processor")


local PREFIX = "FV-"
local StorageUnit = {}

---Maps entity names to their capacity limits
local capacity_limits = {
    [PREFIX .. "cluster-storage-unit-mk1"] = {
        item = 1e6,
        fluid = 1e6,
        energy = 1e12,
    },
    [PREFIX .. "cluster-storage-unit-mk2"] = {
        item = 1e9,
        fluid = 1e9,
        energy = 1e15,
    },
    [PREFIX .. "cluster-storage-unit-mk3"] = {
        item = 1e12,
        fluid = 1e12,
        energy = 1e18,
    },
}

---Adds storage capacity of cluster storage unit to cluster
---@param properties EntityProperties
local function enable_storage_capacity(properties)
    local capacity_override = (properties.capability_override or 1)
    -- assuming that mode is selected
    local capacity = capacity_limits[properties.entity_name][properties.mode]
    local resulting_capacity = capacity_override * capacity
    local cluster = properties.first_cluster
    local buffer_key = properties.buffer_key

    -- attempting to add storage capacity to cluster
    properties.operational = ClusterProcessor.add_storage_capacity(
        cluster,
        properties.unit_number,
        resulting_capacity,
        buffer_key,
        properties.is_output
    )
end

---Removes storage capacity of cluster storage unit from cluster
---@param properties EntityProperties
local function disable_storage_capacity(properties)
    local cluster = properties.first_cluster
    local unit_number = properties.unit_number
    ClusterProcessor.remove_from_cluster(cluster, unit_number)
    properties.operational = false
end

---Should be called just before setting any field in entity registry 
---@param properties EntityProperties
function StorageUnit.on_pre_param_change(properties)

    -- TODO
    
    properties.operational = false
end



---Updates cluster storage unit. Adds/removes entity storage capacity
---to cluster based on entity.energy. Uses "operational" flag as an indication
---that entity is currently providing storage capacity to cluster.
---@param properties EntityProperties
function StorageUnit.process_entity(properties)
    -- does not operate on a vsurface
    if properties.on_vsurface then return end

    -- does not operate without connection to a cluster
    local cluster = properties.first_cluster
    if not cluster then return end

    -- does not operate without buffer key
    local buffer_key = properties.buffer_key
    if not buffer_key then return end

    local entity = properties.entity
    ---@type number assuming storage unit has energy drain
    local energy_drain = entity.electric_drain
    local current_energy = entity.energy

    -- enabling/disabling storage unit based on energy level
    if current_energy < energy_drain then
        disable_storage_capacity(properties)
    elseif not properties.operational then
        enable_storage_capacity(properties)
    end
end

return StorageUnit