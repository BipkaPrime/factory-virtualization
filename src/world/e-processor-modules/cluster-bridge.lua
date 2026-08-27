--[[
Inter-cluster bridge transfers item/fluid/energy directly from output of one
cluster to the input of another. Works as long as the building is powered.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Mandatory entity configuration is provided:
    1. first_cluster. Used to determine source cluster to connect to.
    2. second_cluster. Used to determine destination cluster to connect to.
    3. operation_mode (item/fluid/energy). Used to determine buffer key.
    4. selected_item (only for "item" mode). Used to determine buffer key.
    5. selected_fluid (only for "fluid" mode). Used to determine buffer key.
II. Entity is not located on a vsurface.
III. Selected clusters exist and this entity can be added to them.

Optional entity controls this building can have:
1. capability_override. Used to artificially lower flow limit of this entity.

Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. buffer_key. Used to access a specific cluster buffer entry
3. flow_limit. Determines maximum flow rate for this entity
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick processing:
1. ls_flow. Used to display entity work in the gui
2. operational. true if entity is marked operational in its clusters

Entity is considered operational when:
1. Specified buffer entry is found in both associated cluster.
2. Entity has enough electric energy stored.

If any associated cluster is not found during an update, entity is moved
to "incorrect".
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local ClusterBridge = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
ClusterBridge.configuration = {
    "first_cluster",
    "second_cluster",
    "operation_mode",
    "selected_item_name",
    "selected_item_quality",
    "selected_fluid",
    "capability_override",
}

---Maps entity names to their flow limits
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

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "inter-cluster-bridge-mk1"] = 5e-6,
    [PREFIX .. "inter-cluster-bridge-mk2"] = 5e-5,
    [PREFIX .. "inter-cluster-bridge-mk3"] = 5e-4,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function ClusterBridge.initialize(properties)
    -- Checking that source cluster is selected
    local source_uuid = properties.first_cluster
    if not source_uuid then
        properties.status = Utilities.entity_status.no_s_cluster
        return Utilities.registry_sections.incorrect
    end
    -- Checking that destination cluster is selected
    local destination_uuid = properties.second_cluster
    if not destination_uuid then
        properties.status = Utilities.entity_status.no_d_cluster
        return Utilities.registry_sections.incorrect
    end
    -- Checking that operation mode is selected
    local operation_mode = properties.operation_mode
    if not operation_mode then
        properties.status = Utilities.entity_status.no_operation_mode
        return Utilities.registry_sections.incorrect
    end
    -- Checking that item name and quality are provided in "item" mode 
    local item_name = properties.selected_item_name
    local item_quality = properties.selected_item_quality
    if operation_mode == "item" and (not item_name or not item_quality) then
        properties.status = Utilities.entity_status.no_selected_item
        return Utilities.registry_sections.incorrect
    end
    -- Checking that fluid name is provided in "fluid" mode
    local selected_fluid = properties.selected_fluid
    if operation_mode == "fluid" and not selected_fluid then
        properties.status = Utilities.entity_status.no_selected_fluid
        return Utilities.registry_sections.incorrect
    end
    -- Checking that entity is not located on a virtualization surface
    local entity = properties.entity
    if VSurfaceManager.is_vsurface(entity.surface_index) then
        properties.status = Utilities.entity_status.vsurface_no_work
        return Utilities.registry_sections.incorrect
    end
    -- Checking that source cluster exists
    if not ClusterProcessor.does_cluster_exist(source_uuid) then
        properties.status = Utilities.entity_status.s_cluster_not_found
        return Utilities.registry_sections.incorrect
    end
    -- Checking that destination cluster exists
    if not ClusterProcessor.does_cluster_exist(destination_uuid) then
        properties.status = Utilities.entity_status.d_cluster_not_found
        return Utilities.registry_sections.incorrect
    end
    -- Attempting to add entity to source cluster
    local entity_name = properties.entity_name
    local weight = weights[entity_name]
    local status = ClusterProcessor.add_member_to_cluster(
        entity,
        source_uuid,
        weight
    )
    if not status then
        properties.status = Utilities.entity_status.s_cluster_cant_connect
        return Utilities.registry_sections.incorrect
    end
    -- Attempting to add entity to destination cluster
    status = ClusterProcessor.add_member_to_cluster(
        entity,
        destination_uuid,
        weight
    )
    if not status then
        -- removing entity from source cluster
        ClusterProcessor.remove_member_from_cluster(
            source_uuid,
            properties.unit_number
        )
        properties.status = Utilities.entity_status.d_cluster_cant_connect
        return Utilities.registry_sections.incorrect
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    properties.buffer_key = Utilities.generate_multimode_buffer_key(properties)
    local base_flow = flow_limits[entity_name][operation_mode]
    local quality_mult = 1 + 0.5 * entity.quality.level
    local override = (properties.capability_override or 1)
    properties.flow_limit = base_flow * quality_mult * override
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function ClusterBridge.uninitialize(properties)
    local unit_number = properties.unit_number
    ClusterProcessor.remove_member_from_cluster(
        properties.first_cluster,
        unit_number
    )
    ClusterProcessor.remove_member_from_cluster(
        properties.second_cluster,
        unit_number
    )
    properties.buffer_key = nil
    properties.flow_limit = nil
    properties.ls_flow = nil
    properties.operational = nil
end

---Switches entity to operational state
---@param properties EntityProperties
local function switch_to_operational(properties)
    if properties.operational then return end
    properties.operational = true
    local unit_number = properties.unit_number
    ClusterProcessor.mark_member_operational(
        properties.first_cluster,
        unit_number
    )
    ClusterProcessor.mark_member_operational(
        properties.second_cluster,
        unit_number
    )
    properties.status = Utilities.entity_status.operational
end

---Switches entity to not operational state
---@param properties EntityProperties
local function switch_to_not_operational(properties)
    if not properties.operational then return end
    properties.operational = false
    local unit_number = properties.unit_number
    ClusterProcessor.mark_member_not_operational(
        properties.first_cluster,
        unit_number
    )
    ClusterProcessor.mark_member_not_operational(
        properties.second_cluster,
        unit_number
    )
end

local input = "input"
local output = "output"
---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function ClusterBridge.update(properties)
    properties.ls_flow = 0

    -- Checking that buffer entry exists in source cluster
    ---@type string checked on initialization
    local source_uuid = properties.first_cluster
    local source_entry = ClusterProcessor.get_buffer_entry(
        source_uuid,
        properties.buffer_key,
        output
    )
    if not source_entry then
        -- buffer not found: checking for cluster existence
        if not ClusterProcessor.does_cluster_exist(source_uuid) then
            properties.status = Utilities.entity_status.s_cluster_deleted
            return Utilities.registry_sections.incorrect
        end
        -- cluster exists: marking entity as not operational
        switch_to_not_operational(properties)
        properties.status = Utilities.entity_status.s_entry_not_found
        return Utilities.registry_sections.stalled
    end

    -- Checking that buffer entry exists in destination cluster
    ---@type string checked on initialization
    local destination_uuid = properties.second_cluster
    local destination_entry = ClusterProcessor.get_buffer_entry(
        destination_uuid,
        properties.buffer_key,
        input
    )
    if not destination_entry then
        -- buffer not found: checking for cluster existence
        if not ClusterProcessor.does_cluster_exist(destination_uuid) then
            properties.status = Utilities.entity_status.d_cluster_deleted
            return Utilities.registry_sections.incorrect
        end
        -- cluster exists: marking entity as not operational
        switch_to_not_operational(properties)
        properties.status = Utilities.entity_status.d_entry_not_found
        return Utilities.registry_sections.stalled
    end

    -- Buffer entries are found: normal operation
    local entity = properties.entity
    local power_usage = entity.power_usage
    local current_energy = entity.energy
    if current_energy > power_usage then
        -- there is enough energy: entity is operational
        switch_to_operational(properties)
        -- transfering items
        local to_transfer = math.min(
            ClusterProcessor.get_current_amount(source_entry),
            ClusterProcessor.get_available_space(destination_entry),
            properties.flow_limit
        )
        if to_transfer > 0 then
            ClusterProcessor.remove_from_buffer_entry(
                source_entry,
                to_transfer
            )
            ClusterProcessor.add_to_buffer_entry(
                destination_entry,
                to_transfer
            )
            properties.ls_flow = to_transfer
        end
    else
        -- there is not enough energy: entity is not operational
        switch_to_not_operational(properties)
        properties.status = Utilities.entity_status.not_enough_power
    end
    return Utilities.registry_sections.active
end

return ClusterBridge