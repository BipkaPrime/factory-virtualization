--[[
This mod introduces several entities that must have data associated with them in storage,
they also need to be tracked and updated once in a while. This file is used for that.
Entity registry is located at storage.entity_registry and consists of 2 parts:
storage.entity_registry = {
    array = {},
    lookup = {},
}
Array is 1-indexed and contains data of all entities in the registry.
Lookup maps unit_number of an entity to index in the array containing corresponding
entity data. Entity data from this registry is also called entity properties.
Only alive entities (not ghosts) can have properties in entity registry.
However, entity processor provides functionality to manipulate entity tags 
for ghosts, where entity properties are stored before entity is built.
When entity is constructed/revived, ghost tags migrate to entity regstry.

-------------------------------------------------------------------------------
ENTITY PROPERTIES
-------------------------------------------------------------------------------
entity LuaEntity: reference to entity object 
unit_number number: unique entity identifier
selected_template string|nil (mainframe-io, mainframe): name of selected template (user input)
active_template string|nil (mainframe-io, mainframe): name of template in operation (assigned by processor)
cluster table|nil (mainframe-io, mainframe): reference to virtualization cluster that includes this entity
is_output bool|nil (mainframe-io, template-io): true if entity is output
selected_item table|nil (item-io): {name = string, quality = string} (user input)
buffer_key string|nil (item-io): "name//quality" (assigned by processor for fast access)
selected_fluid string|nil (fluid-io): name of selected fluid if any (user input)
operational bool|nil (mainframe): true if mainframe has constructed a template and can operate
building_requests table|nil: contains buildings that are being requested for template construction
    2-level hmap: table[name][quality] = value
contained_buildings table|nil (mainframe): all buildings that are currently "contained" in the mainframe
    2-level hmap: table[name][quality] = value
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VMManager = require("src.world.vmainframe-manager")
local MainframeIO = require("src.world.mainframe-io-manager")
local TemplateIO = require("src.world.template-io-manager")

local PREFIX = "FV-"
local ENTITY_TAG_KEY = PREFIX
local EntityProcessor = {}

---Mapping of entity names recognized by this registry to their on-tick handlers
local entity_router = {
    [PREFIX .. "template-item-io"] = TemplateIO.process_template_item_io,
    [PREFIX .. "template-fluid-io"] = TemplateIO.process_template_fluid_io,
    [PREFIX .. "template-energy-io"] = TemplateIO.process_template_energy_io,
    [PREFIX .. "mainframe-item-io"] = MainframeIO.process_mainframe_item_io,
    [PREFIX .. "mainframe-fluid-io"] = MainframeIO.process_mainframe_fluid_io,
    [PREFIX .. "mainframe-energy-io"] = MainframeIO.process_mainframe_energy_io,
    [PREFIX .. "virtualization-mainframe"] = VMManager.process_vm,
}
-------------------------------------------------------------------------------
-- DATA MANIPULATION SIDE-EFFECTS (Internal hooks and caches)
-------------------------------------------------------------------------------

---Creates a buffer key for vcluster/venv fast access for item-IOs
---@param properties table entity data from registry
local function generate_buffer_key(properties)
    local item = properties.selected_item
    if item then
        properties.buffer_key = item.name .. "//" .. item.quality
    else
        properties.buffer_key = nil
    end
end

-------------------------------------------------------------------------------
-- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP
-------------------------------------------------------------------------------

---List of functions to perform when setting a value in properties
---Also serves as a table with all copyable fields (keys)
local internal_hooks = {
    selected_template = {},
    selected_item = {
        generate_buffer_key
    },
    selected_fluid = {},
    is_output = {},
}

---Adds given entity to registry. Is called when any build event is triggered.
---@param entity LuaEntity
---@param tags table|nil build event tags
function EntityProcessor.register_entity(entity, tags)
    if not entity.valid then return end

    -- avoiding duplicates
    local reg = storage.entity_registry
    if reg.lookup[entity.unit_number] then return end

    -- mandatory entity properties
    local properties = {
        entity = entity,
        unit_number = entity.unit_number,
    }

    -- adding event tags to properties
    if tags and tags[ENTITY_TAG_KEY] then
        local relevant_tags = tags[ENTITY_TAG_KEY]
        for field, hooks in pairs(internal_hooks) do
            properties[field] = relevant_tags[field]
            for _, hook in pairs(hooks) do
                hook(properties)
            end
        end
    end

    -- adding table to registry
    table.insert(reg.array, properties)
    reg.lookup[entity.unit_number] = #reg.array
end

---Removes entity from registry. Used for automatic garbage collection.
---@param unit_number integer entity identifier
local function unregister_entity(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]

    -- removing entity from vcluster
    local properties = reg.array[index]
    ClusterProcessor.remove_from_cluster(properties.cluster, properties.unit_number)

    -- rewriting element we want to delete with the last one
    local last_element = reg.array[#reg.array]
    reg.array[index] = last_element
    reg.lookup[last_element.unit_number] = index

    -- removing last element from both tables 
    table.remove(reg.array)
    reg.lookup[unit_number] = nil
end

---@param unit_number integer unique entity identifier
---@return table|nil properties entity data from registry
local function get_entity_data(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]
    if not index then return end
    return reg.array[index]
end

-------------------------------------------------------------------------------
-- ENTITY DATA SETTERS: PUBLIC API (GUI CALLS)
-------------------------------------------------------------------------------

---Abstract setter. Sets specified property for a given entity or entity-ghost
---@param entity LuaEntity entity for which data should be retrieved
---@param field string field in properties that will be set
---@param value nil|boolean|table|string value to write in properties[field]
local function set_entity_property(entity, field, value)
    if not entity.valid then return end
    if entity.name == "entity-ghost" then
        -- entity is a ghost data stored in tags
        local tags = entity.tags or {}
        tags[ENTITY_TAG_KEY] = tags[ENTITY_TAG_KEY] or {}
        tags[ENTITY_TAG_KEY][field] = value
        entity.tags = tags
    else
        -- entity is not a ghost, information in registry
        local properties = get_entity_data(entity.unit_number)
        if not properties then return end
        properties[field] = value
        local hooks = internal_hooks[field]
        for _, hook in pairs(hooks) do
            hook(properties)
        end
    end
end

---Sets selected template for given entity or entity-ghost
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear 
function EntityProcessor.set_selected_template(entity, template_name)
    set_entity_property(entity, "selected_template", template_name)
end

---Sets selected item for given entity or entity-ghost
---@param entity LuaEntity
---@param item table<string, string>|nil {name, quality}
function EntityProcessor.set_selected_item(entity, item)
    set_entity_property(entity, "selected_item", item)
end

---Sets selected fluid for given entity or entity-ghost
---@param entity LuaEntity
---@param fluid_name string|nil name of the fluid, or nil to clear
function EntityProcessor.set_selected_fluid(entity, fluid_name)
    set_entity_property(entity, "selected_fluid", fluid_name)
end

---Sets output flag for given entity or entity-ghost
---@param entity LuaEntity
---@param is_output boolean|nil
function EntityProcessor.set_output_flag(entity, is_output)
    set_entity_property(entity, "is_output", is_output)
end

-------------------------------------------------------------------------------
-- ENTITY DATA GETTERS: PUBLIC API (GUI CALLS)
-------------------------------------------------------------------------------

---Abstract getter. Gets specified property for a given entity.
---@param entity LuaEntity entity for which data should be retrieved
---@param field string field in properties that is retrieved
---@return nil|boolean|table|string property for table returns reference, not a copy
local function get_entity_property(entity, field)
    if not entity.valid then return end
    if entity.name == "entity-ghost" then
        -- entity is a ghost data stored in tags
        local tags = entity.tags
        if not tags or not tags[ENTITY_TAG_KEY] then return end
        return tags[ENTITY_TAG_KEY][field]
    else
        -- entity is not a ghost, information in registry
        local properties = get_entity_data(entity.unit_number)
        if not properties then return end
        return properties[field]
    end
end

---Gets selected template for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil template_name
function EntityProcessor.get_selected_template(entity)
    local template_name = get_entity_property(entity, "selected_template")
    ---@cast template_name string|nil
    return template_name
end

---Gets selected item for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return table<string, string>|nil selected_item {name, quality}
function EntityProcessor.get_selected_item(entity)
    local selected_item = get_entity_property(entity, "selected_item")
    ---@cast selected_item table<string, string>|nil
    return selected_item
end

---Gets selected fluid for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil fluid_name
function EntityProcessor.get_selected_fluid(entity)
    local fluid_name = get_entity_property(entity, "selected_fluid")
    ---@cast fluid_name string|nil
    return fluid_name
end

---Gets output flag for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return boolean|nil is_output
function EntityProcessor.get_output_flag(entity)
    local is_output = get_entity_property(entity, "is_output")
    ---@cast is_output boolean|nil
    return is_output
end

-------------------------------------------------------------------------------
-- COPY PASTE
-------------------------------------------------------------------------------

---Adds tags to entities when player creates blueprint
---@param event EventData.on_player_setup_blueprint
function EntityProcessor.setup_blueprint_tags(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local blueprint = event.stack
    if not blueprint then return end
    -- maps blueprint entity index to "real world" entity
    local mapping = event.mapping.get()

    for b_entity_index, entity in ipairs(mapping) do
        if not entity or not entity.valid then goto continue end
        -- skipping entities that do not need tags
        if not entity_router[entity.name] then goto continue end

        -- if registry does not have entity properties we have to skip it
        local properties = get_entity_data(entity.unit_number)
        if not properties then goto continue end

        -- creating a shallow copy with all copyable properties
        local properties_copy = {}
        for field, _ in pairs(internal_hooks) do
            properties_copy[field] = properties[field]
        end
        blueprint.set_blueprint_entity_tag(b_entity_index, ENTITY_TAG_KEY, properties_copy)

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

-- filter that is used to subscribe to build events
EntityProcessor.build_filter = {}
for building_name, _ in pairs(entity_router) do
    table.insert(EntityProcessor.build_filter, {filter = "name", name = building_name})
end

---On-tick entity processor
---@param event EventData.on_tick
function EntityProcessor.process_entities(event)
    local reg = storage.entity_registry
    -- processing every 60-th element each tick
    local offset = event.tick % 60
    for i = #reg.array - offset, 1, -60 do
        local properties = reg.array[i]
        local entity = properties.entity
        if entity.valid then
            local handler = entity_router[entity.name]
            handler(properties)
        else
            -- auto garbage collection
            unregister_entity(properties.unit_number)
        end
    end
end

return EntityProcessor