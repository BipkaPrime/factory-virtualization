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
the registry after it becomes invalid.

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
---@field alert_render LuaRenderObject|nil alert sprite rendered on this entity
---@field resource_render LuaRenderObject|nil resource rendered on this entity
---@field background_render LuaRenderObject|nil background for resource render
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
---@field pos_x number|nil x-coordinate of entity
---@field pos_y number|nil y-coordinate of entity
---@field building_requests table<BufferKeyString, ItemBuffer>|nil building
---requests of this mainframe
---@field building_contents table<BufferKeyString, ItemBuffer>|nil building
---contents of this mainframe
---@field logistic_point LuaLogisticPoint|nil logistic point of this entity
---@field state string|nil current entity state. Used for entities which
---can have more than 2 possible states.
---@field assigned_template string|nil uuid of template assigned to this mainframe
---@field logistic_filters LogisticFilter[]|nil used to control
---logistic filters of this mainframe
---@field filter_lookup table<BufferKeyString, integer>|nil maps buffer keys to indexes
---of corresponding filters in "logistic_filters" field
---@field logistic_section LuaLogisticSection|nil used to reduce load on GC

---One entry in the registration queue
---@class RegistrationEntry
---@field entity LuaEntity entity to be registered
---@field relevant_tags Tags|nil additional configuration data

---Used to store properties of all relevant entities
---@class EntityRegistry
---@field registration_queue RegistrationEntry[] registration pending
---@field active EntityProperties[] initialized entities in operation
---@field stalled EntityProperties[] same as active but updated less frequently
---@field pending EntityProperties[] initialization pending (not initialized)
---@field incorrect EntityProperties[] incorrect configuration (not initialized)
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

local module_path = "scripts.world.e-processor-modules."
local ClusterBridge = require(module_path .. "cluster-bridge")
local ClusterEnergyIO = require(module_path .. "cluster-energy-io")
local ClusterFluidIO = require(module_path .. "cluster-fluid-io")
local ClusterItemIO = require(module_path .. "cluster-item-io")
local OverflowController = require(module_path .. "cluster-overflow-controller")
local StorageUnit = require(module_path .. "cluster-storage-unit")
local TemplateAccess = require(module_path .. "template-access-interface")
local ComputationArray = require(module_path .. "template-computation-array")
local TemplateCC = require(module_path .. "template-control-center")
local TemplateEnergyIO = require(module_path .. "template-energy-io")
local TemplateFluidIO = require(module_path .. "template-fluid-io")
local TemplateItemIO = require(module_path .. "template-item-io")
local VMainframe = require(module_path .. "virtualization-mainframe")
local Misc = require("scripts.misc")


local PREFIX = "FV-"
local EntityProcessor = {}

-------------------------------------------------------------------------------
----------------------- ENTITY PROCESSOR INITIALIZATION -----------------------
-------------------------------------------------------------------------------

---Maps entity names to their handler modules
---@type table<string, EntityProcessorModule>
local module_router = {
    [PREFIX .. "inter-cluster-bridge-mk1"] = ClusterBridge,
    [PREFIX .. "inter-cluster-bridge-mk2"] = ClusterBridge,
    [PREFIX .. "inter-cluster-bridge-mk3"] = ClusterBridge,
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
    [PREFIX .. "template-access-interface-mk1"] = TemplateAccess,
    [PREFIX .. "template-access-interface-mk2"] = TemplateAccess,
    [PREFIX .. "template-access-interface-mk3"] = TemplateAccess,
    [PREFIX .. "template-computation-array-mk1"] = ComputationArray,
    [PREFIX .. "template-computation-array-mk2"] = ComputationArray,
    [PREFIX .. "template-computation-array-mk3"] = ComputationArray,
    [PREFIX .. "template-control-center-mk1"] = TemplateCC,
    [PREFIX .. "template-control-center-mk2"] = TemplateCC,
    [PREFIX .. "template-control-center-mk3"] = TemplateCC,
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
---@type table<string, fun(properties: EntityProperties): EntityRegistrySection>
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
---@type table<string, fun(properties: EntityProperties): EntityRegistrySection>
local update = {}
for entity_name, module in pairs(module_router) do
    update[entity_name] = module.update
end

-------------------------------------------------------------------------------
--------------- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP ----------------
-------------------------------------------------------------------------------

---Contains names of all sections in entity registry
---@enum
local registry_sections = {
    active = "active",
    stalled = "stalled",
    pending = "pending",
    incorrect = "incorrect"
}

---Adds entity to registration queue.
---@param entity LuaEntity
---@param tags Tags|nil build event tags
function EntityProcessor.add_to_registartion_queue(entity, tags)
    local relevant_tags = tags and tags[PREFIX]
    ---@cast relevant_tags Tags|nil
    local queue = storage.entity_registry.registration_queue
    queue[#queue + 1] = {entity = entity, relevant_tags = relevant_tags}
end

---Registers entities from registration queue
---@param count integer number of entities to register
local function register_entities(count)
    -- needed to check that configuration data is valid
    local qualities = prototypes.quality
    local items = prototypes.item
    local fluids = prototypes.fluid

    local registry = storage.entity_registry
    local lookup = registry.lookup
    -- entities are added to pending section on registration
    local pending = registry.pending
    local queue = registry.registration_queue
    for i = #queue, #queue - count + 1, -1 do
        local entry = queue[i]
        queue[i] = nil
        local entity = entry.entity
        -- cannot register an invalid entity
        if entity.valid then
            ---@type number assuming entity has unit number
            local unit_number = entity.unit_number
            -- avoiding duplicates
            if not lookup[unit_number] then
                local entity_name = entity.name
                local array_index = #pending + 1
                ---@type EntityProperties
                local properties = {
                    unit_number = unit_number,
                    entity = entity,
                    entity_name = entity_name,
                    section = registry_sections.pending,
                    array_index = array_index,
                }
                -- adding tags to properties
                local relevant_tags = entry.relevant_tags
                if relevant_tags then
                    local copyable_fields = configuration[entity_name]
                    for _, field in ipairs(copyable_fields) do
                        ---@diagnostic disable-next-line: assign-type-mismatch
                        properties[field] = relevant_tags[field]
                    end
                end
                -- verifying that selected item and quality exist
                local item_name = properties.selected_item_name
                local quality = properties.selected_item_quality
                if (
                    quality and not qualities[quality] or
                    item_name and not items[item_name]
                ) then
                    properties.selected_item_name = nil
                    properties.selected_item_quality = nil
                end
                -- verifying that selected fluid exist
                local fluid_name = properties.selected_fluid
                if fluid_name and not fluids[fluid_name] then
                    properties.selected_fluid = nil
                end
                -- adding properties to pending section
                pending[array_index] = properties
                lookup[unit_number] = properties
            end
        end
    end
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
---Maps registry sections to corresponding alert sprites
local alert_sections = {
    incorrect = PREFIX .. "entity-config-alert-red",
    stalled = PREFIX .. "entity-config-alert-yellow",
}

---Moves properties to specified registry section.
---Controls custom alerts displayed for "invalid" and "stalled".
---@param properties EntityProperties properties to move
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

    -- removing alert render associated with this entity
    local render = properties.alert_render
    if render and render.valid then
        render.destroy()
        properties.alert_render = nil
    end
    -- adding an alert render if necessery
    local alert_sprite = alert_sections[destination_name]
    if alert_sprite then
        properties.alert_render = rendering.draw_sprite{
            sprite = alert_sprite,
            render_layer = "entity-info-icon-above",
            target = properties.entity,
            surface = properties.entity.surface_index,
            blink_interval = 30,
        }
    end
end

---Removes entity from registry. Used for automatic garbage collection.
---@param properties EntityProperties properties to be removed
local function unregister_entity(properties)
    -- uninitializing entity before deleting its properties
    if init_sections[properties.section] then
        uninitialization[properties.entity_name](properties)
    end

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
---@param unit_number integer unique entity identifier
---@return EntityProperties|nil properties entity data from registry
local function get_entity_properties(unit_number)
    return storage.entity_registry.lookup[unit_number]
end

---Gets properties of given entity by unit number
---@param unit_number integer unique entity identifier
---@return EntityProperties|nil properties entity data from registry
function EntityProcessor.get_entity_properties(unit_number)
    return storage.entity_registry.lookup[unit_number]
end

-------------------------------------------------------------------------------
----------------- ENTITY DATA SETTERS: PUBLIC API (GUI CALLS) -----------------
-------------------------------------------------------------------------------

---Names of all configuration fields
---@enum
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

---Abstract setter. Sets specified property for a given entity or entity-ghost.
---If entity has properties in the registry, moves them to pending section
---effectively uninitializing them before changing anything.
---@param entity LuaEntity entity for which data should be set
---@param field string field in properties that will be set
---@param value nil|boolean|table|string|number value to write in properties
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
---@enum
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
---@param cluster_uuid string|nil value to set or nil to clear
function EntityProcessor.set_first_cluster(entity, cluster_uuid)
    set_entity_property(entity, config_fields.first_cluster, cluster_uuid)
end

---Sets second cluster for given entity or entity-ghost
---@param entity LuaEntity
---@param cluster_uuid string|nil value to set or nil to clear
function EntityProcessor.set_second_cluster(entity, cluster_uuid)
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
---@param template_uuid string|nil value to set or nil to clear
function EntityProcessor.set_selected_template(entity, template_uuid)
    set_entity_property(entity, config_fields.selected_template, template_uuid)
end

-------------------------------------------------------------------------------
----------------- ENTITY DATA GETTERS: PUBLIC API (GUI CALLS) -----------------
-------------------------------------------------------------------------------

---Abstract getter. Gets specified property for a given entity.
---@param entity LuaEntity entity for which data should be retrieved
---@param field string field in properties that is retrieved
---@return any property
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
    return get_entity_property(entity, config_fields.io_mode)
end

---Gets mode of operation for a given entity or ghost-entity
---@param entity LuaEntity
---@return "item"|"fluid"|"energy"|nil
function EntityProcessor.get_operation_mode(entity)
    return get_entity_property(entity, config_fields.operation_mode)
end

---Gets selected item for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil name, string|nil quality  
function EntityProcessor.get_selected_item(entity)
    local name = get_entity_property(
        entity,
        config_fields.selected_item_name
    )
    local quality = get_entity_property(
        entity,
        config_fields.selected_item_quality
    )
    return name, quality
end

---Gets selected fluid for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil fluid_name
function EntityProcessor.get_selected_fluid(entity)
    return get_entity_property(entity, config_fields.selected_fluid)
end

---Gets first cluster for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil cluster_uuid
function EntityProcessor.get_first_cluster(entity)
    return get_entity_property(entity, config_fields.first_cluster)
end

---Gets second cluster for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil cluster_uuid
function EntityProcessor.get_second_cluster(entity)
    return get_entity_property(entity, config_fields.second_cluster)
end

---Gets capability override for a given entity or ghost-entity
---@param entity LuaEntity
---@return number|nil number in the range [0, 1]
function EntityProcessor.get_capability_override(entity)
    return get_entity_property(entity, config_fields.capability_override)
end

---Gets overflow threshold for a given entity or ghost-entity
---@param entity LuaEntity
---@return number|nil number in the range [0, 1]
function EntityProcessor.get_overflow_threshold(entity)
    return get_entity_property(entity, config_fields.overflow_threshold)
end

---Gets selected template for a given entity or ghost-entity
---@param entity LuaEntity
---@return string|nil template_uuid
function EntityProcessor.get_selected_template(entity)
    return get_entity_property(entity, config_fields.selected_template)
end

-------------------------------------------------------------------------------
--------------------------------- COPY PASTE ----------------------------------
-------------------------------------------------------------------------------

---Adds tags to entities when player creates blueprint
---@param event EventData.on_player_setup_blueprint
function EntityProcessor.setup_blueprint_tags(event)
    local blueprint = event.stack
    if not blueprint then return end
    -- maps blueprint entity index to "real world" entity
    local mapping = event.mapping.get()
    for b_entity_index, entity in ipairs(mapping) do
        -- considering only valid entities
        if entity.valid then
            local entity_name = entity.name
            -- only entities recognized by this registry
            if configuration[entity_name] then
                local properties = get_entity_properties(entity.unit_number)
                -- only if properties are found
                if properties then
                    -- creating a shallow copy with all copyable properties
                    local properties_copy = {}
                    local copyable_fields = configuration[entity_name]
                    for _, field in ipairs(copyable_fields) do
                        properties_copy[field] = properties[field]
                    end
                    blueprint.set_blueprint_entity_tag(
                        b_entity_index,
                        PREFIX,
                        properties_copy
                    )
                end
            end
        end
    end
end


---@param event EventData.on_blueprint_settings_pasted
function EntityProcessor.on_blueprint_settings_pasted(event)
    --TODO:
end

-------------------------------------------------------------------------------
------------------------------- MAIN PROCESSOR --------------------------------
-------------------------------------------------------------------------------

local REGISTRATION_CHUNKS = 60
local PENDING_CHUNKS = 60
local ACTIVE_SLICES = 60
local STALLED_SLICES = 300
local INCORRECT_SLICES = 300

---On-tick updater for entity registry
---@param event EventData.on_tick
function EntityProcessor.on_tick(event)
    local registry = storage.entity_registry
    local tick = event.tick

    -- Registration queue: registering 1/60 of current queue
    local queue = registry.registration_queue
    local chunk_size = math.ceil(#queue / REGISTRATION_CHUNKS)
    if chunk_size > 0 then register_entities(chunk_size) end

    -- Pending section: initializing 1/60 of pending section
    local pending = registry.pending
    chunk_size = math.ceil(#pending / PENDING_CHUNKS)
    for i = #pending, #pending - chunk_size + 1, -1 do
        local properties = pending[i]
        if properties.entity.valid then
            local handler = initialization[properties.entity_name]
            local target_section = handler(properties)
            move_properties(properties, target_section)
        else
            -- entity is invalid: removing it from registry
            unregister_entity(properties)
        end
    end

    -- Active section: elements are divided into 60 slices
    local active = registry.active
    local offset = tick % ACTIVE_SLICES
    local start_idx, stop_idx = Misc.get_slice_range(
        #active,
        offset,
        ACTIVE_SLICES
    )
    if start_idx then
        for i = stop_idx, start_idx, -ACTIVE_SLICES do
            local properties = active[i]
            if properties.entity.valid then
                local handler = update[properties.entity_name]
                local target_section = handler(properties)
                move_properties(properties, target_section)
            else
                -- entity is invalid: removing it from registry
                unregister_entity(properties)
            end
        end
    end

    -- Stalled section: elements are divided into 300 slices
    local stalled = registry.stalled
    offset = tick % STALLED_SLICES
    start_idx, stop_idx = Misc.get_slice_range(
        #stalled,
        offset,
        STALLED_SLICES
    )
    if start_idx then
        for i = stop_idx, start_idx, -STALLED_SLICES do
            local properties = stalled[i]
            if properties.entity.valid then
                local handler = update[properties.entity_name]
                local target_section = handler(properties)
                move_properties(properties, target_section)
            else
                -- entity is invalid: removing it from registry
                unregister_entity(properties)
            end
        end
    end

    -- Incorrect section: elements are divided into 300 slices
    local incorrect = registry.incorrect
    offset = tick % INCORRECT_SLICES
    start_idx, stop_idx = Misc.get_slice_range(
        #incorrect,
        offset,
        INCORRECT_SLICES
    )
    if start_idx then
        for i = stop_idx, start_idx, -INCORRECT_SLICES do
            local properties = incorrect[i]
            if not properties.entity.valid then
                -- entity is invalid: removing it from registry
                unregister_entity(properties)
            end
        end
    end
end

-------------------------------------------------------------------------------
------------------------------- DATA LIFECYCLE --------------------------------
-------------------------------------------------------------------------------

---Helps with entity-processor storage update when migration occures.
---@param old_table table<BufferKeyString, ItemBuffer>
---@param item table<string, string> migration item mappind (old -> new)
---@param quality table<string, string> migration quality mappind (old -> new)
---@return table<BufferKeyString, ItemBuffer> new_table
---@return boolean status true if all keys were successfuly migrated
local function migrate_vm_table(old_table, item, quality)
    local status = true
    local new_table = {}
    for key, entry in pairs(old_table) do
        local start_idx, stop_idx = string.find(key, "//", 1, true)
        local old_name = string.sub(key, 1, start_idx - 1)
        local old_quality = string.sub(key, stop_idx + 1)
        local new_name = item[old_name] or old_name
        local new_quality = quality[old_quality] or old_quality
        if new_name == "" or new_quality == "" then
            status = false
        else
            entry.name = new_name
            local new_key = string.format("%s//%s", new_name, new_quality)
            new_table[new_key] = entry
        end
    end
    return new_table, status
end

-- Pending is the first: entities are moved there when migration fails
local migration_order = {
    "pending",
    "incorrect",
    "active",
    "stalled"
}

---Used to update entity-processor storage when a migration occures.
---Migration for one entity goes as follows. Migration is attempted
---for each field in properties. Any key that cannot be migrated is removed
---from the structure, when that happens for any key, properties are moved
---to "pending" section (deinitialized in the process).
---@param item table<string, string> migration item mappind (old -> new)
---@param fluid table<string, string> migration fluid mappind (old -> new)
---@param quality table<string, string> migration quality mappind (old -> new)
function EntityProcessor.on_configuration_changed(item, fluid, quality)
    local registry = storage.entity_registry
    for _, section_name in ipairs(migration_order) do
        local section = registry[section_name]
        -- with this iteration order we will be able to move properties
        for i = #section, 1, -1 do
            ---@type EntityProperties
            local properties = section[i]
            local to_deinitialize = false
            -- Updating entity configuration
            local item_name = properties.selected_item_name
            -- quality should always be present when item is selected
            local item_quality = properties.selected_item_quality or "normal"
            if item_name then
                local new_name = item[item_name] or item_name
                local new_quality = quality[item_quality] or item_quality
                if new_name == "" or new_quality == "" then
                    properties.selected_item_name = nil
                    properties.selected_item_quality = nil
                    to_deinitialize = true
                else
                    properties.selected_item_name = new_name
                    properties.selected_item_quality = new_quality
                end
            end
            local fluid_name = properties.selected_fluid
            if fluid_name then
                local new_name = fluid[fluid_name] or fluid_name
                if new_name == "" then
                    properties.selected_fluid = nil
                    to_deinitialize = true
                else
                    properties.selected_fluid = new_name
                end
            end
            -- Updating buffer_key from entity cache
            if properties.buffer_key then
                local new_key = Misc.migrate_buffer_key(
                    properties.buffer_key,
                    item,
                    fluid,
                    quality
                )
                if not new_key then
                    properties.buffer_key = nil
                    to_deinitialize = true
                end
            end
            -- Updating io_request from entity cache
            local io_request = properties.io_request
            if io_request then
                if io_request.quality then
                    ---@cast io_request ItemStackDefinition
                    local old_name = io_request.name
                    local old_quality = io_request.quality
                    local new_name = item[old_name] or old_name
                    local new_quality = quality[old_quality] or old_quality
                    if new_name == "" or new_quality == "" then
                        properties.io_request = nil
                        to_deinitialize = true
                    else
                        io_request.name = new_name
                        io_request.quality = new_quality
                    end
                else
                    ---@cast io_request Fluid
                    local old_name = io_request.name
                    local new_name = fluid[old_name] or old_name
                    if new_name == "" then
                        properties.io_request = nil
                        to_deinitialize = true
                    else
                        io_request.name = new_name
                    end
                end
            end
            -- updating mainframe request and content tables
            if properties.building_requests then
                local new_requests, status = migrate_vm_table(
                    properties.building_requests,
                    item,
                    quality
                )
                properties.building_requests = new_requests
                to_deinitialize = not status
            end
            if properties.building_contents then
                local new_contents, status = migrate_vm_table(
                    properties.building_contents,
                    item,
                    quality
                )
                properties.building_contents = new_contents
                to_deinitialize = not status
            end
            -- updating logistic filters and their lookup
            if properties.logistic_filters then
                for _, filter in pairs(properties.logistic_filters) do
                    local value = filter.value
                    ---@cast value SignalFilter.struct
                    local old_name = value.name
                    local old_quality = value.quality
                    ---@cast old_quality string
                    local new_name = item[old_name] or old_name
                    local new_quality = item[old_quality] or old_quality
                    if new_name == "" or new_quality == "" then
                        to_deinitialize = true
                        -- this field is erased during deinitialization
                        -- and does not interfere with it
                        break
                    else
                        value.name = new_name
                        value.quality = new_quality
                    end
                end
            end
            if properties.filter_lookup then
                local new_table = {}
                for key, value in pairs(properties.filter_lookup) do
                    local new_key = Misc.migrate_buffer_key(
                        key,
                        item,
                        fluid,
                        quality
                    )
                    if not new_key then
                        to_deinitialize = true
                        -- this field is erased during deinitialization
                        -- and does not interfere with it
                        break
                    end
                    new_table[new_key] = value
                end
                properties.filter_lookup = new_table
            end
            -- deinitializing an entity if necessery
            if to_deinitialize then
                move_properties(properties, registry_sections.pending)
            end
        end
    end
end

return EntityProcessor