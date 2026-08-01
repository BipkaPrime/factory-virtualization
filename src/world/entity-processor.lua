--[[
This mod introduces several entities that must have data associated with them in storage,
they also need to be tracked and updated once in a while. This file is used for that.
Entity registry is located at storage.entity_registry and consists of 2 parts:
storage.entity_registry = {
    array = {},
    lookup = {},
}
Array is 1-indexed and contains data of all entities in the registry.
It is required for efficient on-tick processing.
Lookup maps unit number of an entity to its properties. It is required to
find properties in O(1).

Entities are added to the registry when build event are fired. Entities are
deleted from then registry automatically when they become invalid. To delete item in
O(1), properties must contain it's key in lookup. In our case entity unit number.

Only alive entities (not ghosts) can have properties in entity registry.
However, entity processor provides functionality to manipulate entity tags 
for ghosts, where entity properties are stored before entity is built.
When entity is constructed/revived, ghost tags migrate to entity registry.

Entity properties can be divided into 3 groups.
First group is mandatory: every entity must have these.
Second group is user-inputs: they have setter and getter functions and
can be directly influenced by the player.
Third group is internal: these can only be assigned by entity processor.
--]]

---Serves as key in tables where items, fluids and energy are stored together
---@alias BufferKeyString string "name//quality" for items, "name" for fluids, "electric_energy" for energy

---Table describing one item stack
---@class ItemBuffer
---@field count number number of items contained
---@field quality string quality of this item
---@field name string name of this item

---Table describing selected item
---@class ItemSelection
---@field name string prototype name of selected item
---@field quality string prototype name of selected quality
---@field count number|nil technical field (to use table as an arg in inventory.insert)

---Table describing selected fluid
---@class FluidSelection
---@field name string name of selected fluid
---@field amount number|nil technical field (to use table as an arg in entity.insert_fluid)

---Table describing entity properties in registry
---@class EntityProperties mandatory technical fields (assigned on registration)
---@field unit_number number unique entity identifier: used as lookup key
---@field entity LuaEntity entity that owns these properties
---@field entity_name string name of entity that owns these properties
---@field is_processing boolean true if entity is configured and initialized for on-tick processing

---@class EntityProperties entity configuration fields (user-inputs)
---@field io_mode "input"|"output"|nil selected io mode
---@field selected_item ItemSelection|nil table describing selected item
---@field selected_fluid FluidSelection|nil user-input. Table describing selected fluid
---@field first_template string|nil user-input. Name of first selected template
---@field second_template string|nil user-input. Name of second selected template
---@field operation_mode "item"|"fluid"|"energy"|nil user-input. Selected mode of operation
---@field capability_override number|nil user-input. Number from 0 to 1. Allows user to limit building capability.
---@field overflow_threshold number|nil user-input. Number from 0 to 1. Defines what is considered an overflow by overflow controller.

---@class EntityProperties internal fields (assigned on initialization or during on-tick processing)
---@field first_cluster ClusterData|nil reference to cluster associated with first selected template
---@field second_cluster ClusterData|nil reference to cluster associated with second selected template
---@field inventory LuaInventory|nil inventory object of this entity
---@field capacity number|nil storage capacity of cluster storage unit
---@field first_buffer_entry ClusterBufferEntry|nil first buffer entry that entity is connected to
---@field second_buffer_entry ClusterBufferEntry|nil second buffer entry that entity is connected to
---@field operational boolean|nil used as a flag for cluster members that contribute something to cluster (crafting power, etc.)
---@field flow_limit number|nil maximum flow limit of this entity
---@field ls_flow number|nil last second flow for this entity
---@field is_output boolean|nil used to indicate whether entity is an input or output
---@field buffer_key BufferKeyString|nil string used for access to cluster/venv tables

---@field building_requests table<BufferKeyString, ItemBuffer>|nil internal. requests of this mainframe
---@field building_contents table<BufferKeyString, ItemBuffer>|nil internal. contents of this mainframe

local VSurfaceManager = require("src.world.vsurface-manager")
local VMainframe = require("src.world.entity-processor-members.virtualization-mainframe")
local ClusterIO = require("src.world.entity-processor-members.cluster-io")
local TemplateIO = require("src.world.entity-processor-members.template-io")
local ClusterBridge = require("src.world.entity-processor-members.inter-cluster-bridge")
local OverflowController = require("src.world.entity-processor-members.cluster-overflow-controller")
local StorageUnit = require("src.world.entity-processor-members.cluster-storage-unit")

local PREFIX = "FV-"
local EntityProcessor = {}

---Mapping of entity names recognized by this registry to their on-tick handlers
local entity_router = {
    [PREFIX .. "template-item-io-mk1"] = TemplateIO.process_template_item_io,
    [PREFIX .. "template-item-io-mk2"] = TemplateIO.process_template_item_io,
    [PREFIX .. "template-item-io-mk3"] = TemplateIO.process_template_item_io,
    [PREFIX .. "template-fluid-io-mk1"] = TemplateIO.process_template_fluid_io,
    [PREFIX .. "template-fluid-io-mk2"] = TemplateIO.process_template_fluid_io,
    [PREFIX .. "template-fluid-io-mk3"] = TemplateIO.process_template_fluid_io,
    [PREFIX .. "template-energy-io-mk1"] = TemplateIO.process_template_energy_io,
    [PREFIX .. "template-energy-io-mk2"] = TemplateIO.process_template_energy_io,
    [PREFIX .. "template-energy-io-mk3"] = TemplateIO.process_template_energy_io,
    [PREFIX .. "cluster-item-io-mk1"] = ClusterIO.process_cluster_item_io,
    [PREFIX .. "cluster-item-io-mk2"] = ClusterIO.process_cluster_item_io,
    [PREFIX .. "cluster-item-io-mk3"] = ClusterIO.process_cluster_item_io,
    [PREFIX .. "cluster-fluid-io-mk1"] = ClusterIO.process_cluster_fluid_io,
    [PREFIX .. "cluster-fluid-io-mk2"] = ClusterIO.process_cluster_fluid_io,
    [PREFIX .. "cluster-fluid-io-mk3"] = ClusterIO.process_cluster_fluid_io,
    [PREFIX .. "cluster-energy-io-mk1"] = ClusterIO.process_cluster_energy_io,
    [PREFIX .. "cluster-energy-io-mk2"] = ClusterIO.process_cluster_energy_io,
    [PREFIX .. "cluster-energy-io-mk3"] = ClusterIO.process_cluster_energy_io,
    [PREFIX .. "virtualization-mainframe-mk1"] = VMainframe.process_vm,
    [PREFIX .. "virtualization-mainframe-mk2"] = VMainframe.process_vm,
    [PREFIX .. "virtualization-mainframe-mk3"] = VMainframe.process_vm,
    [PREFIX .. "inter-cluster-bridge-mk1"] = ClusterBridge.process_bridge,
    [PREFIX .. "inter-cluster-bridge-mk2"] = ClusterBridge.process_bridge,
    [PREFIX .. "inter-cluster-bridge-mk3"] = ClusterBridge.process_bridge,
    [PREFIX .. "cluster-overflow-controller-mk1"] = OverflowController.process_entity,
    [PREFIX .. "cluster-overflow-controller-mk2"] = OverflowController.process_entity,
    [PREFIX .. "cluster-overflow-controller-mk3"] = OverflowController.process_entity,
    [PREFIX .. "cluster-storage-unit-mk1"] = StorageUnit.process_entity,
    [PREFIX .. "cluster-storage-unit-mk2"] = StorageUnit.process_entity,
    [PREFIX .. "cluster-storage-unit-mk3"] = StorageUnit.process_entity,
}

---Filter used to subscribe to build events
EntityProcessor.build_filter = {}
for name, _ in pairs(entity_router) do
    table.insert(EntityProcessor.build_filter, {filter = "name", name = name})
end

---Copyable fields of template item io
local template_item_io_copyable = {
    "selected_item",
    "is_output",
}

---Copyable fields of template fluid io
local template_fluid_io_copyable = {
    "selected_fluid",
    "is_output",
}

---Copyable fields of template energy io
local template_energy_io_copyable = {
    "is_output",
}

---Copyable fields of cluster item io
local cluster_item_io_copyable = {
    "first_template",
    "selected_item",
    "is_output",
}

---Copyable fields of cluster fluid io
local cluster_fluid_io_copyable = {
    "first_template",
    "selected_fluid",
    "is_output",
}

---Copyable fields of cluster energy io
local cluster_energy_io_copyable = {
    "first_template",
    "is_output",
}

---Copyable fields of virtualization mainframe
local virtualization_mainframe_copyable = {
    "first_template",
}

---Copyable fields of inter-cluster bridge
local inter_cluster_bridge_copyable = {
    "mode",
    "selected_item",
    "selected_fluid",
    "first_template",
    "second_template",
    "capability_override"
}

---Copyable fields of cluster overflow controller
local cluster_overflow_controller_copyable = {
    "mode",
    "selected_item",
    "selected_fluid",
    "first_template",
    "capability_override",
    "overflow_threshold",
}

---Copyable fields of cluster storage unit
local cluster_storage_unit_copyable = {
    "mode",
    "selected_item",
    "selected_fluid",
    "first_template",
    "capability_override",
}

---Maps entity names to their copyable properties
local entity_copyable_fields = {
    [PREFIX .. "template-item-io-mk1"] = template_item_io_copyable,
    [PREFIX .. "template-item-io-mk2"] = template_item_io_copyable,
    [PREFIX .. "template-item-io-mk3"] = template_item_io_copyable,
    [PREFIX .. "template-fluid-io-mk1"] = template_fluid_io_copyable,
    [PREFIX .. "template-fluid-io-mk2"] = template_fluid_io_copyable,
    [PREFIX .. "template-fluid-io-mk3"] = template_fluid_io_copyable,
    [PREFIX .. "template-energy-io-mk1"] = template_energy_io_copyable,
    [PREFIX .. "template-energy-io-mk2"] = template_energy_io_copyable,
    [PREFIX .. "template-energy-io-mk3"] = template_energy_io_copyable,
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk1"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk2"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk3"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_energy_io_copyable,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_energy_io_copyable,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_energy_io_copyable,
    [PREFIX .. "virtualization-mainframe-mk1"] = virtualization_mainframe_copyable,
    [PREFIX .. "virtualization-mainframe-mk2"] = virtualization_mainframe_copyable,
    [PREFIX .. "virtualization-mainframe-mk3"] = virtualization_mainframe_copyable,
    [PREFIX .. "inter-cluster-bridge-mk1"] = inter_cluster_bridge_copyable,
    [PREFIX .. "inter-cluster-bridge-mk2"] = inter_cluster_bridge_copyable,
    [PREFIX .. "inter-cluster-bridge-mk3"] = inter_cluster_bridge_copyable,
    [PREFIX .. "cluster-overflow-controller-mk1"] = cluster_overflow_controller_copyable,
    [PREFIX .. "cluster-overflow-controller-mk2"] = cluster_overflow_controller_copyable,
    [PREFIX .. "cluster-overflow-controller-mk3"] = cluster_overflow_controller_copyable,
    [PREFIX .. "cluster-storage-unit-mk1"] = cluster_storage_unit_copyable,
    [PREFIX .. "cluster-storage-unit-mk2"] = cluster_storage_unit_copyable,
    [PREFIX .. "cluster-storage-unit-mk3"] = cluster_storage_unit_copyable,
}

-------------------------------------------------------------------------------
-- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP
-------------------------------------------------------------------------------

---Adds given entity to registry. Called when any build event is triggered.
---@param entity LuaEntity assumed to be valid
---@param tags table|nil build event tags
function EntityProcessor.register_entity(entity, tags)
    local registry = storage.entity_registry
    ---@type number assuming entity has unit number
    local unit_number = entity.unit_number
    -- entity with this unit number is already registered
    if registry.lookup[unit_number] then return end

    -- mandatory entity properties
    local entity_name = entity.name
    local properties = {
        unit_number = unit_number,
        entity = entity,
        entity_name = entity_name,
    }

    -- adding event tags to properties
    if tags then
        local relevant_tags = tags[PREFIX]
        if relevant_tags then
            local copyable = entity_copyable_fields[entity_name]
            for _, field in ipairs(copyable) do
                properties[field] = relevant_tags[field]
                -- field setting hooks for given entity
                local hooks = field_setting_hooks[entity_name]
                if hooks then
                    local field_hooks = hooks[field]
                    if field_hooks then
                        -- calling all field hooks
                        for _, hook in ipairs(field_hooks) do
                            hook(properties)
                        end
                    end
                end
            end
        end
    end

    -- performing necessery on-registration actions
    local hooks = registration_hooks[entity_name]
    if hooks then
        for _, hook in ipairs(hooks) do
            hook(properties)
        end
    end
    properties.on_vsurface = VSurfaceManager.get_vsurface_data(entity.surface_index)

    -- adding table to registry
    local array = registry.array
    array[#array + 1] = properties
    registry.lookup[unit_number] = properties
end

---Removes entity from registry. Used for automatic garbage collection.
---@param properties EntityProperties properties to be removed
---@param index number index at which properties are located
local function unregister_entity(properties, index)
    -- performing unregistration hooks
    remove_from_first_cluster(properties)
    remove_from_second_cluster(properties)

    -- rewriting element we want to delete with the last one
    local registry = storage.entity_registry
    local array = registry.array
    local last_element = array[#array]
    array[index] = last_element
    registry.lookup[properties.unit_number] = nil

    -- removing last element from array
    array[#array] = nil
end

---Gets properties of given entity by unit number
---@param unit_number number unique entity identifier
---@return EntityProperties|nil properties entity data from registry
local function get_entity_properties(unit_number)
    return storage.entity_registry.lookup[unit_number]
end

---Gets properties of given entity by unit number
---@param unit_number number unique entity identifier
---@return EntityProperties|nil properties entity data from registry
function EntityProcessor.get_entity_properties(unit_number)
    return storage.entity_registry.lookup[unit_number]
end

-------------------------------------------------------------------------------
-- ENTITY DATA SETTERS: PUBLIC API (GUI CALLS)
-------------------------------------------------------------------------------

---Abstract setter. Sets specified property for a given entity or entity-ghost
---@param entity LuaEntity entity for which data should be retrieved
---@param field string field in properties that will be set
---@param value nil|boolean|table|string|number value to write in properties[field]
---@param ignore_hooks boolean|nil true to ignore field setting hooks
local function set_entity_property(entity, field, value, ignore_hooks)
    if not entity.valid then return end
    if entity.name == "entity-ghost" then
        -- entity is a ghost: data stored in tags
        local tags = entity.tags or {}
        tags[PREFIX] = tags[PREFIX] or {}
        tags[PREFIX][field] = value
        entity.tags = tags
    else
        -- entity is not a ghost: data in registry
        local properties = get_entity_properties(entity.unit_number)
        if not properties then return end
        properties[field] = value
        if ignore_hooks then return end
        local entity_hooks = field_setting_hooks[entity.name]
        if not entity_hooks then return end
        local hooks = entity_hooks[field]
        if not hooks then return end
        for _, hook in ipairs(hooks) do
            hook(properties)
        end
    end
end

---Sets output flag for given entity or entity-ghost
---@param entity LuaEntity
---@param is_output true|nil
function EntityProcessor.set_output_flag(entity, is_output)
    set_entity_property(entity, "is_output", is_output)
end

---Sets selected item for given entity or entity-ghost
---@param entity LuaEntity
---@param name string|nil name of selected item
---@param quality string|nil quality of selected item
function EntityProcessor.set_selected_item(entity, name, quality)
    local item_data = (name and quality and {name = name, quality = quality}) or nil
    set_entity_property(entity, "selected_item", item_data)
end

---Sets selected fluid for given entity or entity-ghost
---@param entity LuaEntity
---@param fluid_name string|nil name of selected fluid
function EntityProcessor.set_selected_fluid(entity, fluid_name)
    local fluid_data = fluid_name and {name = fluid_name} or nil
    set_entity_property(entity, "selected_fluid", fluid_data)
end

---Sets first template for given entity or entity-ghost
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear
function EntityProcessor.set_first_template(entity, template_name)
    set_entity_property(entity, "first_template", template_name)
end

---Sets second template name for given entity or entity-ghost
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear 
function EntityProcessor.set_second_template(entity, template_name)
    set_entity_property(entity, "second_template", template_name)
end

---Sets mode of operation for given entity
---@param entity LuaEntity
---@param mode "item"|"fluid"|"energy" mode of operation
function EntityProcessor.set_mode(entity, mode)
    -- when changing mode we also want to cleanup unused information
    -- for instance, when item mode is chosen, selected fluid is cleared
    if mode ~= "item" then
        set_entity_property(entity, "selected_item", nil, true)
    end
    if mode ~= "fluid" then
        set_entity_property(entity, "selected_fluid", nil, true)
    end
    set_entity_property(entity, "mode", mode)
end

---Sets capability override for a given entity
---@param entity LuaEntity
---@param value number|nil in the range [0, 1]
function EntityProcessor.set_capability_override(entity, value)
    set_entity_property(entity, "capability_override", value)
end

---Sets overflow threshold for a given entity
---@param entity LuaEntity
---@param value number|nil in the range [0, 1]
function EntityProcessor.set_overflow_threshold(entity, value)
    set_entity_property(entity, "overflow_threshold", value)
end

-------------------------------------------------------------------------------
-- ENTITY DATA GETTERS: PUBLIC API (GUI CALLS)
-------------------------------------------------------------------------------

---Abstract getter. Gets specified property for a given entity.
---@param entity LuaEntity entity for which data should be retrieved
---@param field string field in properties that is retrieved
---@return any property for table returns reference, not a copy
local function get_entity_property(entity, field)
    if not entity.valid then return end
    if entity.name == "entity-ghost" then
        -- entity is a ghost: data stored in tags
        local tags = entity.tags
        if not tags or not tags[PREFIX] then return end
        return tags[PREFIX][field]
    else
        -- entity is not a ghost: data in registry
        local properties = get_entity_properties(entity.unit_number)
        if not properties then return end
        return properties[field]
    end
end

---Gets output flag for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return boolean|nil is_output
function EntityProcessor.get_output_flag(entity)
    return get_entity_property(entity, "is_output")
end

---Gets selected item for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil name, string|nil quality  
function EntityProcessor.get_selected_item(entity)
    local selected_item = get_entity_property(entity, "selected_item")
    if not selected_item then return end
    return selected_item.name, selected_item.quality
end

---Gets selected fluid for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil fluid_name
function EntityProcessor.get_selected_fluid(entity)
    local fluid = get_entity_property(entity, "selected_fluid")
    return fluid and fluid.name
end

---Gets first template for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil template_name
function EntityProcessor.get_first_template(entity)
    return get_entity_property(entity, "first_template")
end

---Gets second template for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil template_name
function EntityProcessor.get_second_template(entity)
    return get_entity_property(entity, "second_template")
end

---Gets mode of operation for a given entity
---@param entity LuaEntity
---@return "item"|"fluid"|"energy"|nil
function EntityProcessor.get_mode(entity)
    return get_entity_property(entity, "mode")
end

---Gets capability override for a given entity
---@param entity LuaEntity
---@return number|nil number in the range [0, 1]
function EntityProcessor.get_capability_override(entity)
    return get_entity_property(entity, "capability_override")
end

---Gets overflow threshold for a given entity
---@param entity LuaEntity
---@return number|nil number in the range [0, 1]
function EntityProcessor.get_overflow_threshold(entity)
    return get_entity_property(entity, "overflow_threshold")
end

-------------------------------------------------------------------------------
-- COPY PASTE
-------------------------------------------------------------------------------

---Adds tags to entities when player creates blueprint
---@param event EventData.on_player_setup_blueprint
function EntityProcessor.setup_blueprint_tags(event)
    local blueprint = event.stack
    if not blueprint then return end
    -- maps blueprint entity index to "real world" entity
    local mapping = event.mapping.get()

    for b_entity_index, entity in ipairs(mapping) do
        -- skipping invalid entities
        if not entity.valid then goto continue end
        local entity_name = entity.name
        -- skipping entities that are not recognized by this registry
        if not entity_router[entity_name] then goto continue end
        -- if registry does not have entity properties we have to skip it
        local properties = get_entity_properties(entity.unit_number)
        -- skipping entities if their properties are not found
        if not properties then goto continue end
        -- creating a shallow copy with all copyable properties
        local properties_copy = {}
        local copyable_fields = entity_copyable_fields[entity_name]
        for _, field in ipairs(copyable_fields) do
            properties_copy[field] = properties[field]
        end
        blueprint.set_blueprint_entity_tag(b_entity_index, PREFIX, properties_copy)

        ::continue::
    end
end

-- TODO: improve user experience???
-- on_blueprint_settings_pasted
-- on_entity_cloned
-- on_entity_settings_pasted
-- on_player_configured_blueprint
-- on_redo_applied (maybe?)
-- on_undo_applied (maybe?)

-------------------------------------------------------------------------------
-- MAIN PROCESSOR
-------------------------------------------------------------------------------

---On-tick entity processor. Processing is done in 60 chunks (one chunk per tick).
---@param event EventData.on_tick
function EntityProcessor.process_entities(event)
    local registry = storage.entity_registry
    local array = registry.array
    local total_size = #array

    local chunk_offset = event.tick % 60
    local chunk_size = math.ceil(total_size / 60)
    local start_index = (chunk_size * chunk_offset) + 1
    if start_index > total_size then return end
    local stop_index = math.min(chunk_size * (chunk_offset + 1), total_size)

    for i = stop_index, start_index, -1 do
        local properties = array[i]
        local entity = properties.entity
        if entity.valid then
            entity_router[properties.entity_name](properties)
        else
            -- removing invalid entity from the registry
            unregister_entity(properties, i)
        end
    end
end

return EntityProcessor