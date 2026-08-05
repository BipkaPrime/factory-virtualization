--[[
Cluster overflow controller is used for voiding overflow in one
cluster buffer entry. It consumes electric energy and works only
when building has enough.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. First template. Used to determine the cluster this entity
        should connect to.
    2. Operation mode (item/fluid/energy). Used to determine the buffer entry
        that this entity should connect to.
    3. Overflow threshold. Used to determine what is considered an overflow.
    4. Selected item (only for "item" mode). Used to determine the buffer 
        entry that this entity should connect to.
    5. Selected fluid (only for "fluid" mode). Used to determine the
        buffer entry that this entity should connect to.
II. Entity is not located on a vsurface.

Optional entity controls this building can have:
1. Capability override. Used to artificially lower flow rate of this entity.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. First cluster. Used to remove entity from cluster when necessery.
2. Buffer entry. Used to make calls to cluster processor.
3. Flow limit. Used to make calls to cluster processor.

Properties that can be assigned during on-tick processing:
1. Ls flow. Can be used to track entity work.
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.entity-processor-members.utilities")


local PREFIX = "FV-"
local OverflowController = {}

---List of all copyable properties of this entity
OverflowController.copyable = {
    "first_template",
    "operation_mode",
    "overflow_threshold",
    "selected_item_name",
    "selected_item_quality",
    "selected_fluid",
    "capability_override",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "cluster-overflow-controller-mk1"] = {
        item = 1e6,
        fluid = 1e6,
        energy = 1e12,
    },
    [PREFIX .. "cluster-overflow-controller-mk2"] = {
        item = 1e9,
        fluid = 1e9,
        energy = 1e15,
    },
    [PREFIX .. "cluster-overflow-controller-mk3"] = {
        item = 1e12,
        fluid = 1e12,
        energy = 1e18,
    },
}

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "cluster-overflow-controller-mk1"] = 1,
    [PREFIX .. "cluster-overflow-controller-mk2"] = 10,
    [PREFIX .. "cluster-overflow-controller-mk3"] = 100,
}

---Checks that all requirements for operation of cluster overflow controller are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function OverflowController.attempt_entity_initialization(properties)
    -- 1. First template is selected
    local first_template = properties.first_template
    if not first_template then return false end
    -- 2. Operation mode is selected
    local operation_mode = properties.operation_mode
    if not operation_mode then return false end
    -- 3. Overflow threshold is provided
    local overflow_threshold = properties.overflow_threshold
    if not overflow_threshold then return false end
    -- 4. Item is selected in "item" mode
    local item_name = properties.selected_item_name
    local item_quality = properties.selected_item_quality
    if operation_mode == "item" and (not item_name or not item_quality) then return false end
    -- 5. Fluid is selected in "fluid" mode
    local selected_fluid = properties.selected_fluid
    if operation_mode == "fluid" and not selected_fluid then return false end
    -- 6. Entity is not located on a vsurface
    local entity = properties.entity
    if VSurfaceManager.get_vsurface_data(entity.surface_index) then return false end

    ---All requirements are met. Preparing properties for on-tick processing
    -- attempting to connect entity to cluster
    local entity_name = properties.entity_name
    local cluster = ClusterProcessor.add_to_cluster(
        entity,
        first_template,
        weights[entity_name]
    )
    if not cluster then return false end
    properties.first_cluster = cluster
    -- attempting to assign buffer entry to entity
    local buffer_key = Utilities.generate_multimode_buffer_key(properties)
    local buffer_entry = ClusterProcessor.get_buffer_entry(cluster, buffer_key, "output")
    if not buffer_entry then return false end
    properties.first_buffer_entry = buffer_entry
    -- caching flow limit considering base limit and capability override
    local override = (properties.capability_override or 1)
    local base_limit = flow_limits[entity_name][operation_mode]
    properties.flow_limit = base_limit * override
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function OverflowController.on_processing_stopped(properties)
    properties.ls_flow = nil
    properties.flow_limit = nil
    properties.first_buffer_entry = nil
    -- removing entity from associated cluster
    ClusterProcessor.remove_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.first_cluster = nil
end

---Used for on-tick processing of cluster overflow controllers.
---@param properties EntityProperties
function OverflowController.process_entity(properties)
    local entity = properties.entity
    ---@type number assuming overflow controller has energy drain
    local energy_drain = entity.electric_drain
    local current_energy = entity.energy

    if current_energy > energy_drain then
        properties.ls_flow = ClusterProcessor.void_overflow(
            properties.first_buffer_entry,
            properties.flow_limit,
            properties.overflow_threshold
        )
    else
        properties.ls_flow = 0
    end
end

return OverflowController