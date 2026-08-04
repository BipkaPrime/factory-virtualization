--[[
This mod introduces several entities that must have data associated with them in storage,
they also need to be tracked and updated once in a while. This file is used for that.
Data associated with entity will be reffered to as entity "properties". They can be
stored in 2 places depending on state of the entity. Ghost-entities have their properties
stored in their ghost tags. Alive entities have their properties in the "entity registry".

Entity registry is located at storage.entity_registry and consists of 3 parts:
storage.entity_registry = {
    initialized: EntityProperties[],
    uninitialized: EntityProperties[],
    lookup: table<number, EntityProperties>,
}
Entities are first registered to "uninitialized" array, from which they can be moved to
"initialized" array if their properties satisfy certain conditions. "Initialized" array is 
for regular entity operation. Both "initializaed" and "uninitialized" arrays are processed
incrementally on-tick. Each time properties from "uninitialized" array are processed,
initialization is attempted. "Lookup" maps unit number of an entity to its properties.
It is required to find properties of a given entity in O(1) time.

Entities are registered when build events are fired. Entities are
deleted from then registry automatically when they become invalid. To delete item in
O(1) time, properties must contain it's key in lookup. In our case unit number of the entity.

Entity properties can be divided into 3 groups.
First group is mandatory: every entity must have these.
Second group is user-inputs: they have setter and getter functions and
can be directly influenced by the player.
Third group is internal: these can only be assigned on initialization or during regular processing.
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

---Table describing entity properties in registry
---@class EntityProperties mandatory technical fields (assigned on registration)
---@field unit_number number unique entity identifier: used as lookup key
---@field entity LuaEntity entity that owns these properties
---@field entity_name string name of entity that owns these properties
---@field initialized boolean true if entity is initialized
---@field index number location of table in the data structure

---@class EntityProperties entity configuration fields (user-inputs)
---@field io_mode "input"|"output"|nil selected io mode
---@field selected_item ItemSelection|nil table describing selected item
---@field selected_fluid string|nil user-input. Name of selected fluid
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
---@field building_requests table<BufferKeyString, ItemBuffer>|nil building requests of this mainframe
---@field building_contents table<BufferKeyString, ItemBuffer>|nil building contents of this mainframe
---@field logistic_point LuaLogisticPoint|nil logistic point of this entity

---Defines a standard interface (handler module) for a specific building type.
---@class EntityProcessorMember
---@field copyable string[] names of copyable entity properties
---@field attempt_entity_initialization fun(properties: EntityProperties): boolean used to attempt entity initialization
---@field on_processing_stopped fun(properties: EntityProperties) used when entity is being uninitialized
---@field process_entity fun(properties: EntityProperties) used for regular on-tick processing of initialized entity


local ClusterEnergyIO = require("src.world.entity-processor-members.cluster-energy-io")
local ClusterFluidIO = require("src.world.entity-processor-members.cluster-fluid-io")
local ClusterItemIO = require("src.world.entity-processor-members.cluster-item-io")
local OverflowController = require("src.world.entity-processor-members.cluster-overflow-controller")
local StorageUnit = require("src.world.entity-processor-members.cluster-storage-unit")
local ClusterBridge = require("src.world.entity-processor-members.inter-cluster-bridge")
local TemplateEnergyIO = require("src.world.entity-processor-members.template-energy-io")
local TemplateFluidIO = require("src.world.entity-processor-members.template-fluid-io")
local TemplateItemIO = require("src.world.entity-processor-members.template-item-io")
local VMainframe = require("src.world.entity-processor-members.virtualization-mainframe")


local PREFIX = "FV-"
local EntityProcessor = {}

-------------------------------------------------------------------------------
-- ENTITY PROCESSOR INITIALIZATION
-------------------------------------------------------------------------------

---Maps entity names to their handler modules
---@type table<string, EntityProcessorMember>
local module_router = {
    [PREFIX .. "cluster-energy-io-mk1"] = ClusterEnergyIO,
    [PREFIX .. "cluster-energy-io-mk2"] = ClusterEnergyIO,
    [PREFIX .. "cluster-energy-io-mk3"] = ClusterEnergyIO,
    [PREFIX .. "cluster-fluid-io-mk1"] = ClusterFluidIO,
    [PREFIX .. "cluster-fluid-io-mk2"] = ClusterFluidIO,
    [PREFIX .. "cluster-fluid-io-mk3"] = ClusterFluidIO,
    [PREFIX .. "cluster-item-io-mk1"] = ClusterItemIO,
    [PREFIX .. "cluster-item-io-mk2"] = ClusterItemIO,
    [PREFIX .. "cluster-item-io-mk3"] = ClusterItemIO,
    [PREFIX .. "cluster-overflow-controller-mk1"] = OverflowController,
    [PREFIX .. "cluster-overflow-controller-mk2"] = OverflowController,
    [PREFIX .. "cluster-overflow-controller-mk3"] = OverflowController,
    [PREFIX .. "cluster-storage-unit-mk1"] = StorageUnit,
    [PREFIX .. "cluster-storage-unit-mk2"] = StorageUnit,
    [PREFIX .. "cluster-storage-unit-mk3"] = StorageUnit,
    [PREFIX .. "inter-cluster-bridge-mk1"] = ClusterBridge,
    [PREFIX .. "inter-cluster-bridge-mk2"] = ClusterBridge,
    [PREFIX .. "inter-cluster-bridge-mk3"] = ClusterBridge,
    [PREFIX .. "template-energy-io-mk1"] = TemplateEnergyIO,
    [PREFIX .. "template-energy-io-mk2"] = TemplateEnergyIO,
    [PREFIX .. "template-energy-io-mk3"] = TemplateEnergyIO,
    [PREFIX .. "template-fluid-io-mk1"] = TemplateFluidIO,
    [PREFIX .. "template-fluid-io-mk2"] = TemplateFluidIO,
    [PREFIX .. "template-fluid-io-mk3"] = TemplateFluidIO,
    [PREFIX .. "template-item-io-mk1"] = TemplateItemIO,
    [PREFIX .. "template-item-io-mk2"] = TemplateItemIO,
    [PREFIX .. "template-item-io-mk3"] = TemplateItemIO,
    [PREFIX .. "virtualization-mainframe-mk1"] = VMainframe,
    [PREFIX .. "virtualization-mainframe-mk2"] = VMainframe,
    [PREFIX .. "virtualization-mainframe-mk3"] = VMainframe,
}

---Filter used to subscribe to build events
EntityProcessor.build_filter = {}
for name, _ in pairs(module_router) do
    table.insert(EntityProcessor.build_filter, {filter = "name", name = name})
end

---Maps entity names to their copyable properties
---@type table<string, string[]>
local copyable = {}
for entity_name, module in pairs(module_router) do
    copyable[entity_name] = module.copyable
end

---Maps entity names to functions used for their initialization
---@type table<string, fun(properties: EntityProperties): boolean>
local initialization_router = {}
for entity_name, module in pairs(module_router) do
    initialization_router[entity_name] = module.attempt_entity_initialization
end

---Maps entity names to functions used for their uninitialization
---@type table<string, fun(properties: EntityProperties)>
local uninitialization_router = {}
for entity_name, module in pairs(module_router) do
    uninitialization_router[entity_name] = module.on_processing_stopped
end

---Maps entity names to functions used for regular updates after initialization
---@type table<string, fun(properties: EntityProperties)>
local processing_router = {}
for entity_name, module in pairs(module_router) do
    processing_router[entity_name] = module.process_entity
end

-------------------------------------------------------------------------------
-- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP
-------------------------------------------------------------------------------

---Adds given entity to registry. Called when any build event is triggered.
---@param entity LuaEntity assumed to be valid
---@param tags table|nil build event tags
function EntityProcessor.register_entity(entity, tags)
    local registry = storage.entity_registry
    local lookup = registry.lookup
    ---@type number assuming entity has unit number
    local unit_number = entity.unit_number
    -- entity with this unit number is already registered
    if lookup[unit_number] then return end

    -- mandatory entity properties
    local uninitialized = registry.uninitialized
    local index = #uninitialized + 1
    local entity_name = entity.name
    local properties = {
        unit_number = unit_number,
        entity = entity,
        entity_name = entity_name,
        initialized = false,
        index = index,
    }

    -- adding tags to properties
    if tags then
        local relevant_tags = tags[PREFIX]
        if relevant_tags then
            local copyable_fields = copyable[entity_name]
            for _, field in ipairs(copyable_fields) do
                properties[field] = relevant_tags[field]
            end
        end
    end

    -- adding properties to uninitialized section
    uninitialized[index] = properties
    lookup[unit_number] = properties
end

---Moves properties from source array to destination array
---@param properties EntityProperties
---@param source EntityProperties[]
---@param destination EntityProperties[]
local function move_properties(properties, source, destination)
    -- rewriting properties in source array with the last element
    local last_element = source[#source]
    local index = properties.index
    source[index] = last_element
    last_element.index = index
    source[#source] = nil

    -- writing properties to destination array
    local new_index = #destination + 1
    destination[new_index] = properties
    -- updating properties location data
    properties.index = new_index
    properties.initialized = not properties.initialized
end

---Attempts to initialize an entity.
---It's assumed that properties are located in "uninitialized" section
---@param properties EntityProperties properties to be initialized
local function attempt_entity_initialization(properties)
    local status = initialization_router[properties.entity_name](properties)
    -- if initialization failed: return
    if not status then return end

    -- moving properties to initialized section
    local registry = storage.entity_registry
    move_properties(
        properties,
        registry.uninitialized,
        registry.initialized
    )
end

---Uninitializes the entity if it's initialized, otherwise does nothing.
---@param properties EntityProperties properties to be uninitialized
local function uninitialize_entity(properties)
    if not properties.initialized then return end
    uninitialization_router[properties.entity_name](properties)

    -- moving properties to uninitialized section
    local registry = storage.entity_registry
    move_properties(
        properties,
        registry.initialized,
        registry.uninitialized
    )
end

---Removes entity from registry. Used for automatic garbage collection.
---@param properties EntityProperties properties to be removed
local function unregister_entity(properties)
    -- uninitializing entity before deleting its properties
    if properties.initialized then
        uninitialization_router[properties.entity_name](properties)
    end

    local registry = storage.entity_registry
    local is_init = properties.initialized
    local array = (is_init and registry.initialized) or registry.uninitialized

    -- rewriting properties we want to delete with the last element
    local index = properties.index
    local last_element = array[#array]
    array[index] = last_element
    last_element.index = index

    -- removing last element from array and lookup
    array[#array] = nil
    registry.lookup[properties.unit_number] = nil
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
---@param entity LuaEntity entity for which data should be set
---@param field string field in properties that will be set
---@param value nil|boolean|table|string|number value to write in properties[field]
local function set_entity_property(entity, field, value)
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
        -- uninitializing entity when any field is set
        uninitialize_entity(properties)
    end
end

---Sets io mode for given entity or entity-ghost
---@param entity LuaEntity
---@param io_mode "input"|"output"
function EntityProcessor.set_io_mode(entity, io_mode)
    set_entity_property(entity, "io_mode", io_mode)
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
    set_entity_property(entity, "selected_fluid", fluid_name)
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
---@param operation_mode "item"|"fluid"|"energy" mode of operation
function EntityProcessor.set_operation_mode(entity, operation_mode)
    -- when changing mode we also want to cleanup unused information
    -- for instance, when item mode is chosen, selected fluid is cleared
    if operation_mode ~= "item" then
        set_entity_property(entity, "selected_item", nil)
    end
    if operation_mode ~= "fluid" then
        set_entity_property(entity, "selected_fluid", nil)
    end
    set_entity_property(entity, "operation_mode", operation_mode)
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
---@return any property for tables returns reference, not a copy
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

---Gets io_mode for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return "input"|"output"|nil io_mode
function EntityProcessor.get_io_mode(entity)
    return get_entity_property(entity, "io_mode")
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
    local fluid_name = get_entity_property(entity, "selected_fluid")
    return fluid_name
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
function EntityProcessor.get_operation_mode(entity)
    return get_entity_property(entity, "operation_mode")
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
        if not copyable[entity_name] then goto continue end
        -- if registry does not have entity properties we have to skip it
        local properties = get_entity_properties(entity.unit_number)
        -- skipping entities if their properties are not found
        if not properties then goto continue end
        -- creating a shallow copy with all copyable properties
        local properties_copy = {}
        local copyable_fields = copyable[entity_name]
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

---Given an array and current tick, calculates the chunk that needs to be
---processed in this tick. This function aims to split the array into 60
---chunks of similar size, so the whole array is processed each second.
---@param array any[] 
---@param tick integer 
---@return integer start_idx, integer stop_idx
local function get_current_chunk(array, tick)
    local total_size = #array
    local offset = tick % 60
    local chunk_size = math.ceil(total_size / 60)
    local start_index = (chunk_size * offset) + 1
    if start_index > total_size then return 0, -1 end
    local stop_index = math.min(chunk_size * (offset + 1), total_size)
    return start_index, stop_index
end

---On-tick entity processor. Processing is done in 60 chunks (one chunk per tick).
---@param event EventData.on_tick
function EntityProcessor.process_entities(event)
    local registry = storage.entity_registry
    local tick = event.tick

    -- processing uninitialized section of registry
    local uninit = registry.uninitialized
    local start_idx, stop_idx = get_current_chunk(uninit, tick)
    for i = stop_idx, start_idx, -1 do
        local properties = uninit[i]
        local entity = properties.entity
        if entity.valid then
            attempt_entity_initialization(properties)
        else
            unregister_entity(properties)
        end
    end

    -- processing initialized section of registry
    local init = registry.initialized
    local start_idx, stop_idx = get_current_chunk(init, tick)
    for i = stop_idx, start_idx, -1 do
        local properties = init[i]
        local entity = properties.entity
        if entity.valid then
            processing_router[properties.entity_name](properties)
        else
            unregister_entity(properties)
        end
    end
end

return EntityProcessor