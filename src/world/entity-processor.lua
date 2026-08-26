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
---|"selected_template"

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
---@field selected_template string|nil uuid of template selected by TAE
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
---@field capacity number|nil storage capacity of cluster storage unit
---@field computation_cost number|nil energy cost for one unit of computation
---@field startup_energy number|nil amount of energy required to "turn on" this entity
---@field surface_index integer|nil index of the surface entity is located on
---@field building_requests table<BufferKeyString, ItemBuffer>|nil building
---requests of this mainframe
---@field building_contents table<BufferKeyString, ItemBuffer>|nil building
---contents of this mainframe
---@field logistic_point LuaLogisticPoint|nil logistic point of this entity

---Used to store properties of all relevant entities
---@class EntityRegistry
---@field active EntityProperties[] initialized entities in operation
---@field stalled EntityProperties[] same as active but updated less frequently
---@field pending EntityProperties[] initialization pending
---@field incorrect EntityProperties[] incorrect configuration
---@field lookup table<integer, EntityProperties> key is unit number

---Defines a standard interface (handler module) for a specific building type.
---@class EntityProcessorModule
---@field configuration EntityConfigField[]
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
local ClusterProcessor = require("src.simulation.cluster-processor")
local TCCManager = require("src.simulation.tcc-manager")


local PREFIX = "FV-"
local EntityProcessor = {}

-------------------------------------------------------------------------------
----------------------- ENTITY PROCESSOR INITIALIZATION -----------------------
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

---Maps entity names to their configuration properties
---@type table<string, string[]>
local configuration = {}
for entity_name, module in pairs(module_router) do
    configuration[entity_name] = module.configuration
end

---Maps entity names to functions used for their initialization
---@type table<string, fun(properties: EntityProperties): boolean>
local initialization = {}
for entity_name, module in pairs(module_router) do
    initialization[entity_name] = module.initialize
end

---Maps entity names to functions used for their uninitialization
---@type table<string, fun(properties: EntityProperties)>
local uninitialization = {}
for entity_name, module in pairs(module_router) do
    uninitialization[entity_name] = module.uninitialize
end

---Maps entity names to functions used for regular updates after initialization
---@type table<string, fun(properties: EntityProperties)>
local update = {}
for entity_name, module in pairs(module_router) do
    update[entity_name] = module.update
end

-------------------------------------------------------------------------------
--------------- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP ----------------
-------------------------------------------------------------------------------

---Contains names of all sections in entity registry
---@type table<EntityRegistrySection, EntityRegistrySection>
local registry_sections = {
    active = "active",
    stalled = "stalled",
    pending = "pending",
    incorrect = "incorrect"
}

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
    local section = registry.pending
    local array_index = #section + 1
    local entity_name = entity.name
    ---@type EntityProperties
    local properties = {
        unit_number = unit_number,
        entity = entity,
        entity_name = entity_name,
        section = registry_sections.pending,
        array_index = array_index,
    }

    -- adding tags to properties
    if tags then
        local relevant_tags = tags[PREFIX]
        if relevant_tags then
            local copyable_fields = configuration[entity_name]
            for _, field in ipairs(copyable_fields) do
                properties[field] = relevant_tags[field]
            end
        end
    end

    -- adding properties to pending section
    section[array_index] = properties
    lookup[unit_number] = properties
end

---Registry sections that contain initialized properties
local init_sections = {
    active = true,
    stalled = true,
}
---Registry sections that contain uninitialized properties
local uninit_sections = {
    pending = true,
    incorrect = true
}
---Moves properties to specified registry section
---@param properties EntityProperties properties that will be moved
---@param destination_name EntityRegistrySection name of destination section
local function move_properties(properties, destination_name)
    local source_name = properties.section
    if source_name == destination_name then return end

    local registry = storage.entity_registry
    ---@type EntityProperties[]
    local source = registry[source_name]
    ---@type EntityProperties[]
    local destination = registry[destination_name]

    -- rewriting properties in source array with the last element
    local last_element = source[#source]
    local index = properties.array_index
    source[index] = last_element
    last_element.array_index = index
    source[#source] = nil

    -- writing properties to destination array
    local new_index = #destination + 1
    destination[new_index] = properties
    -- updating properties location data
    properties.array_index = new_index
    properties.section = destination_name

    -- uninitializing properties if necessery
    if init_sections[source_name] and uninit_sections[destination_name] then
        uninitialization[properties.entity_name](properties)
    end
end

---Removes entity from registry. Used for automatic garbage collection.
---@param properties EntityProperties properties to be removed
local function unregister_entity(properties)
    -- uninitializing entity before deleting its properties
    uninitialization[properties.entity_name](properties)

    local registry = storage.entity_registry
    ---@type EntityProperties[]
    local array = registry[properties.section]

    -- rewriting properties we want to delete with the last element
    local last_element = array[#array]
    local index = properties.array_index
    array[index] = last_element
    last_element.array_index = index

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
----------------- ENTITY DATA SETTERS: PUBLIC API (GUI CALLS) -----------------
-------------------------------------------------------------------------------

---Names of all configuration fields
local config_fields = {
    io_mode = "io_mode",
    operation_mode = "operation_mode",
    selected_item_name = "selected_item_name",
    selected_item_quality = "selected_item_quality",
    selected_fluid = "selected_fluid",
    first_cluster = "first_cluster",
    second_cluster = "second_cluster",
    capability_override = "capability_override",
    overflow_threshold = "overflow_threshold",
    selected_template = "selected_template",
}

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
        -- uninitializing entity when configuration is changed
        move_properties(properties, registry_sections.pending)
        properties[field] = value
    end
end

---Sets io mode for given entity or entity-ghost
---@param entity LuaEntity
---@param io_mode "input"|"output"|nil
function EntityProcessor.set_io_mode(entity, io_mode)
    set_entity_property(entity, config_fields.io_mode, io_mode)
end

---Names of all operation modes
local operation_modes = {
    item = "item",
    fluid = "fluid",
    energy = "energy"
}
---Sets mode of operation for given entity
---@param entity LuaEntity
---@param operation_mode "item"|"fluid"|"energy"|nil mode of operation
function EntityProcessor.set_operation_mode(entity, operation_mode)
    -- when changing mode we also want to cleanup unused information
    -- for instance, when item mode is chosen, selected fluid is cleared
    if operation_mode ~= operation_modes.item then
        set_entity_property(entity, config_fields.selected_item_name, nil)
        set_entity_property(entity, config_fields.selected_item_quality, nil)
    end
    if operation_mode ~= operation_modes.fluid then
        set_entity_property(entity, config_fields.selected_fluid, nil)
    end
    set_entity_property(entity, config_fields.operation_mode, operation_mode)
end

---Sets selected item for given entity or entity-ghost
---@param entity LuaEntity
---@param name string|nil name of selected item
---@param quality string|nil quality of selected item
function EntityProcessor.set_selected_item(entity, name, quality)
    set_entity_property(entity, config_fields.selected_item_name, name)
    set_entity_property(entity, config_fields.selected_item_quality, quality)
end

---Sets selected fluid for given entity or entity-ghost
---@param entity LuaEntity
---@param fluid_name string|nil name of selected fluid
function EntityProcessor.set_selected_fluid(entity, fluid_name)
    set_entity_property(entity, config_fields.selected_fluid, fluid_name)
end

---Sets first cluster for given entity or entity-ghost
---@param entity LuaEntity
---@param cluster_name string|nil value to set or nil to clear
function EntityProcessor.set_first_cluster(entity, cluster_name)
    local cluster_uuid = ClusterProcessor.get_cluster_uuid(cluster_name)
    set_entity_property(entity, config_fields.first_cluster, cluster_uuid)
end

---Sets second cluster for given entity or entity-ghost
---@param entity LuaEntity
---@param cluster_name string|nil value to set or nil to clear
function EntityProcessor.set_second_cluster(entity, cluster_name)
    local cluster_uuid = ClusterProcessor.get_cluster_uuid(cluster_name)
    set_entity_property(entity, config_fields.second_cluster, cluster_uuid)
end

---Sets capability override for a given entity
---@param entity LuaEntity
---@param value number|nil in the range [0, 1]
function EntityProcessor.set_capability_override(entity, value)
    set_entity_property(entity, config_fields.capability_override, value)
end

---Sets overflow threshold for a given entity
---@param entity LuaEntity
---@param value number|nil in the range [0, 1]
function EntityProcessor.set_overflow_threshold(entity, value)
    set_entity_property(entity, config_fields.overflow_threshold, value)
end

---Sets selected template for given entity or entity-ghost
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear
function EntityProcessor.set_selected_template(entity, template_name)
    local template_uuid
    -- TODO: finish
    
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