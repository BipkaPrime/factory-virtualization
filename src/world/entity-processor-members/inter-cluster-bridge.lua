--[[
Inter-cluster bridge transfers item/fluid/energy directly from output of one
cluster to the input of another. Works as long as the building is powered.
If energy stored in the entity is not sufficient, it stops working until
enough energy is provided.

-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. First template. Used to determine the source cluster from which
        items are taken.
    2. Second template. Used to determine the destination cluster to which
        items are transfered.
    3. Operation mode (item/fluid/energy). Used to determine the
        buffer entries that should be assigned to the entity.
    4. Selected item (only for "item" mode). Used to determine the
        buffer entries that should be assigned to the entity.
    5. Selected fluid (only for "fluid" mode). Used to determine the
        buffer entries that should be assigned to the entity.
II. Entity is not located on a vsurface.

Optional entity controls this building can have:
1. Capability override. Used to artificially lower flow limit of this entity.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. First cluster. Used to remove entity from source cluster when necessery.
2. Second cluster. Used to remove entity from destination cluster when necessery.
3. First buffer entry. Used to make calls to cluster processor.
4. Second buffer entry. Used to make call to cluster processor.
5. Flow limit. Used to make call to cluster processor.

Properties that can be assigned during on-tick processing:
1. Ls flow. Can be used to track entity work.
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.entity-processor-members.utilities")


local PREFIX = "FV-"
local ClusterBridge = {}

---List of all copyable properties of this entity
ClusterBridge.copyable = {
    "first_template",
    "second_template",
    "operation_mode",
    "selected_item",
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

---Checks that all requirements for operation of inter-clister bridge are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function ClusterBridge.attempt_entity_initialization(properties)
    -- 1. First template is selected
    local first_template = properties.first_template
    if not first_template then return false end
    -- 2. Second template is selected
    local second_template = properties.second_template
    if not second_template then return false end
    -- 3. Operation mode is selected
    local operation_mode = properties.operation_mode
    if not operation_mode then return false end
    -- 4. Item is selected in "item" mode
    local selected_item = properties.selected_item
    if operation_mode == "item" and not selected_item then return false end
    -- 5. Fluid is selected in "fluid" mode
    local selected_fluid = properties.selected_fluid
    if operation_mode == "fluid" and not selected_fluid then return false end
    -- 6. Entity is not located on a vsurface
    local entity = properties.entity
    if VSurfaceManager.get_vsurface_data(entity.surface_index) then return false end

    ---All requirements are met. Preparing properties for on-tick processing
    -- attempting to connect entity to source cluster
    local source_cluster = ClusterProcessor.add_to_cluster(entity, first_template)
    if not source_cluster then return false end
    properties.first_cluster = source_cluster
    -- attempting to connect entity to destination cluster
    local destination_cluster = ClusterProcessor.add_to_cluster(entity, second_template)
    if not destination_cluster then return false end
    properties.second_cluster = destination_cluster
    -- attempting to assign source buffer entry to entity
    local buffer_key = Utilities.generate_multimode_buffer_key(properties)
    local source_entry = ClusterProcessor.get_buffer_entry(
        source_cluster,
        buffer_key,
        "output"
    )
    if not source_entry then return false end
    properties.first_buffer_entry = source_entry
    -- attempting to assign destination buffer entry to entity
    local destination_entry = ClusterProcessor.get_buffer_entry(
        destination_cluster,
        buffer_key,
        "input"
    )
    if not destination_entry then return false end
    properties.second_buffer_entry = destination_entry
    -- caching flow limit considering base limit and capability override
    local override = (properties.capability_override or 1)
    local base_limit = flow_limits[properties.entity_name][operation_mode]
    properties.flow_limit = base_limit * override
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function ClusterBridge.on_processing_stopped(properties)
    properties.ls_flow = nil
    properties.flow_limit = nil
    properties.second_buffer_entry = nil
    properties.first_buffer_entry = nil
    ClusterProcessor.remove_from_cluster(
        properties.second_cluster,
        properties.unit_number
    )
    properties.second_cluster = nil
    ClusterProcessor.remove_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.first_cluster = nil
end

---Used for on-tick processing of inter-cluster bridges.
---@param properties EntityProperties
function ClusterBridge.process_entity(properties)
    local entity = properties.entity
    ---@type number assuming overflow controller has energy drain
    local energy_drain = entity.electric_drain
    local current_energy = entity.energy

    if current_energy > energy_drain then
        local source_limit = ClusterProcessor.get_current_amount(
            properties.first_buffer_entry
        )
        local destination_limit = ClusterProcessor.get_available_space(
            properties.second_buffer_entry
        )
        local to_transfer = math.floor(math.min(
            source_limit,
            destination_limit,
            properties.flow_limit
        ))
        if to_transfer > 0 then
            ClusterProcessor.remove_from_buffer_entry(
                properties.first_buffer_entry,
                to_transfer
            )
            ClusterProcessor.add_to_buffer_entry(
                properties.second_buffer_entry,
                to_transfer
            )
            properties.ls_flow = to_transfer
        end
    else
        properties.ls_flow = 0
    end
end

return ClusterBridge