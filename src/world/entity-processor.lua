--[[
This mod introduces several entities which require storing additional data
associated with them somewhere. Furthermore, these entities need to be tracked
and updated once in a while. Data associated with entity will be reffered
to as entity "properties". For some entities to operate they must be properly
configured. A part of properties is "entity configuration": fields like
"selected_item", "io_mode", "first_cluster", etc. These are user inputs.

Entities are registered when "build" events are fired. Properties of entities
are stored in one of several sections of "entity registry" depending on the
state and configuration of entity. Properties of an entity are removed from
the registry after it becomes invalid (after a delay).

Entity configuration data for a ghost is stored in its tags. It's automatically
transfered to entity properties on registration. Any change to entity
configuration should only be done using this file. It automatically decides
where to store configuration data depending on entity state. 

Data structure is located at storage.entity_registry. See EntityRegistry class
for more information. Note that unit_number of an entity is vital for operation
of this module, thus only entities which have it can be registered.

Entity properties can be divided into 3 logical groups.
1. System: mandatory fields assigned on registration
2. Configuration: user-inputs (these have setter and getter functions)
3. Cache: assigned on initialization or during processing
--]]

---Serves as key in tables where items, fluids and energy are stored together
---@alias BufferKeyString string "name//quality" for items, "name" for fluids,
---"electric_energy" for energy

---Union of all sections in the entity registry
---@alias EntityRegistrySection "active"|"stalled"|"pending"|"incorrect"

---Union of all names of entity configuration fields
---@alias EntityConfigField
---|"io_mode"
---|"operation_mode"
---|"selected_item_name"
---|"selected_item_quality"
---|"selected_fluid"
---|"first_cluster"
---|"second_cluster"
---|"capability_override"
---|"overflow_threshold"

---Union of all semantic roles of entity configuration fields
---@alias EntityConfigRole
---|"primary_cluster" cluster for entities that connect to a single one
---|"item_selection"
---|"fluid_selection"
---|"io_cluster_logistics" io_mode for 
---|"io_cluster_storage" io_mode for cluster storage
---|"io_template_access" io_mode for template access interfaces


---Table describing one item stack
---@class ItemBuffer
---@field count number number of items contained
---@field quality string quality of this item
---@field name string name of this item

---Table describing entity properties in registry
---@class EntityProperties
---SYSTEM (mandatory fields assigned on registration):
---@field unit_number integer unique entity identifier
---@field entity LuaEntity entity that owns these properties
---@field entity_name string name of entity that owns these properties
---@field section EntityRegistrySection location of properties in registry
---@field array_index number location of properties in registry
---CONFIGURATION (user-inputs, have setter and getter functions):
---@field io_mode "input"|"output"|nil
---@field operation_mode "item"|"fluid"|"energy"|nil 
---@field selected_item_name string|nil must be set if selected quality is set
---@field selected_item_quality string|nil must be set if selected item is set
---@field selected_fluid string|nil name of selected fluid
---@field first_cluster string|nil uuid of cluster associated with entity
---@field second_cluster string|nil uuid of another cluster associated with entity
---@field capability_override number|nil number in the range [0, 1]
---@field overflow_threshold number|nil number in the range [0, 1]
---CACHE (assigned on initialization or during processing)
---@field status LocalisedString|nil entity status
---@field buffer_key BufferKeyString|nil used to access cluster or venv buffer entry
---@field is_output boolean|nil used to determine entity operation mode
---@field flow_limit number|nil maximum flow limit of this entity
---@field inventory LuaInventory|nil inventory object of this entity
---@field io_request ItemStackDefinition|Fluid|nil cached table used to make calls
---to factorio API like "inventory.insert()"/"entity.extract_fluid()"/etc.
---@field ls_flow number|nil last second flow for this entity
---@field operational boolean|nil true if entity is marked operational in its clusters

--[[
---@class EntityProperties internal fields (assigned on initialization or during on-tick processing)

---@field capacity number|nil storage capacity of cluster storage unit
---@field  used as a flag for cluster members that contribute something to cluster (crafting power, etc.)

---@field is_output boolean|nil used to indicate whether entity is an input or output
---@field buffer_key BufferKeyString|nil string used for access to cluster/venv tables
---@field building_requests table<BufferKeyString, ItemBuffer>|nil building requests of this mainframe
---@field building_contents table<BufferKeyString, ItemBuffer>|nil building contents of this mainframe
---@field logistic_point LuaLogisticPoint|nil logistic point of this entity

---@field computation_limit number|nil maximum amount of computation this template computation array can provide
---@field computation_cost number|nil energy cost for one unit of computation provided by this entity
---@field startup_energy number|nil amount of energy required to "turn on" this entity
--]]


---Used to store properties of all relevant entities
---@class EntityRegistry
---@field active EntityProperties[] initialized entities in operation
---@field stalled EntityProperties[] same as active but updated less frequently
---@field pending EntityProperties[] initialization pending
---@field incorrect EntityProperties[] incorrect configuration
---@field lookup table<integer, EntityProperties> key is unit number

---Defines a standard interface (handler module) for a specific building type.
---@class EntityProcessorModule
---@field configuration table<EntityConfigField, EntityConfigRole>
---@field initialize fun(properties: EntityProperties): EntityRegistrySection
---attempts entity initialization, returns name of section to which entity
---properties should be moved
---@field uninitialize fun(properties: EntityProperties) removes fields assigned
---on initialization/updates and reverts side effects.
---@field update fun(properties: EntityProperties): EntityRegistrySection used
---for regular on-tick processing of initialized entity. Returns name of section
---to which entity properties should be moved


local ClusterEnergyIO = require("src.world.e-processor-modules.cluster-energy-io")
local ClusterFluidIO = require("src.world.e-processor-modules.cluster-fluid-io")
local ClusterItemIO = require("src.world.e-processor-modules.cluster-item-io")
local OverflowController = require("src.world.e-processor-modules.cluster-overflow-controller")
local StorageUnit = require("src.world.e-processor-modules.cluster-storage-unit")
local ClusterBridge = require("src.world.e-processor-modules.inter-cluster-bridge")
local ComputationArray = require("src.world.e-processor-modules.template-computation-array")
local TemplateEnergyIO = require("src.world.e-processor-modules.template-energy-io")
local TemplateFluidIO = require("src.world.e-processor-modules.template-fluid-io")
local TemplateItemIO = require("src.world.e-processor-modules.template-item-io")
local VMainframe = require("src.world.e-processor-modules.virtualization-mainframe")


local PREFIX = "FV-"
local EntityProcessor = {}

-------------------------------------------------------------------------------
-- ENTITY PROCESSOR INITIALIZATION
-------------------------------------------------------------------------------

---Maps entity names to their handler modules
---@type table<string, EntityProcessorModule>
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
    [PREFIX .. "template-computation-array-mk1"] = ComputationArray,
    [PREFIX .. "template-computation-array-mk2"] = ComputationArray,
    [PREFIX .. "template-computation-array-mk3"] = ComputationArray,
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
        -- uninitializing entity when any field is set
        uninitialize_entity(properties)
        properties[field] = value
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
    set_entity_property(entity, "selected_item_name", name)
    set_entity_property(entity, "selected_item_quality", quality)
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
        set_entity_property(entity, "selected_item_name", nil)
        set_entity_property(entity, "selected_item_quality", nil)
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
    local name = get_entity_property(entity, "selected_item_name")
    local quality = get_entity_property(entity, "selected_item_quality")
    return name, quality
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