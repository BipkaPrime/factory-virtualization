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
--]]


---@alias ItemKeyString string name//quality
---@alias FluidKeyString string fluid_name
---@alias EnergyKeyString "electric_energy"
---Serves as key in tables where items, fluids and energy are stored together
---@alias BufferKeyString ItemKeyString|FluidKeyString|EnergyKeyString

--- Table describing one item stack
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

---Abstract class for entity data in processor
---@class EntityPropertiesBase
---@field entity LuaEntity
---@field unit_number number unique entity identifier

---Abstract entity that supports item selection
---@class EntityWithItemSelection: EntityPropertiesBase
---@field selected_item ItemSelection|nil table describing selected item
---@field buffer_key ItemKeyString|nil "name//quality"

---Abstract entity that supports fluid selection
---@class EntityWithFluidSelection: EntityPropertiesBase
---@field selected_fluid FluidSelection|nil table describing selected fluid

---Abstract entity that can be an input ot an output
---@class EntityWithIOSelection: EntityPropertiesBase
---@field is_output boolean|nil true if entity is an output

---Abstract entity that has chest inventory
---@class EntityWithChestInventory: EntityPropertiesBase
---@field inventory LuaInventory cached on registration

---Abstract entity that can be a member of cluster
---@class SimpleClusterMember: EntityPropertiesBase
---@field selected_template string|nil name of selected template (user input)
---@field cluster table|nil reference to virtualization cluster that includes this entity

---Mainframe item IO properties
---@class MItemIOProperties: SimpleClusterMember
---@class MItemIOProperties: EntityWithItemSelection
---@class MItemIOProperties: EntityWithIOSelection
---@class MItemIOProperties: EntityWithChestInventory

---Mainframe fluid IO properties
---@class MFluidIOProperties: SimpleClusterMember
---@class MFluidIOProperties: EntityWithFluidSelection
---@class MFluidIOProperties: EntityWithIOSelection

---Mainframe energy IO properties
---@class MEnergyIOProperties: SimpleClusterMember
---@class MEnergyIOProperties: EntityWithIOSelection

---Template item IO properties
---@class TItemIOProperties: EntityWithItemSelection
---@class TItemIOProperties: EntityWithIOSelection
---@class TItemIOProperties: EntityWithChestInventory

---Template fluid IO properties
---@class TFluidIOProperties: EntityWithFluidSelection
---@class TFluidIOProperties: EntityWithIOSelection

---Template energy IO properties
---@class TEnergyIOProperties: EntityWithIOSelection

---Table with properties of virtualization mainframe
---@class MainframeProperties: SimpleClusterMember
---@field operational boolean|nil true if mainframe has constructed a template and can operate
---@field building_requests table<ItemKeyString, ItemBuffer>|nil items that are being requested for template construction
---@field contained_buildings table<ItemKeyString, ItemBuffer>|nil items that were used for template construction

---Union of all instances of entity properties
---@alias EntityProperties
---|MItemIOProperties
---|MFluidIOProperties
---|MEnergyIOProperties
---|TItemIOProperties
---|TFluidIOProperties
---|TEnergyIOProperties
---|MainframeProperties


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

---Cahes LuaInventory of given entity to properties
---@param properties EntityWithChestInventory
local function cache_inventory_object(properties)
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    ---assuming that entity prototype has chest inventory
    ---@cast inventory LuaInventory
    properties.inventory = inventory
end

---Creates a buffer key for item IO.
---@param properties EntityWithItemSelection
local function generate_buffer_key(properties)
    local item = properties.selected_item
    properties.buffer_key = item and (item.name .. "//" .. item.quality) or nil
end

---Moves entity to new virtualization cluster
---@param properties SimpleClusterMember
local function move_to_new_cluster(properties)
    -- removing entity from old cluster
    local old_cluster = properties.cluster
    local unit_number = properties.unit_number
    ClusterProcessor.remove_from_cluster(old_cluster, unit_number)

    -- adding entity to its new cluster
    local entity = properties.entity
    local template_name = properties.selected_template
    local new_cluster = ClusterProcessor.add_to_cluster(entity, template_name)
    properties.cluster = new_cluster
end

-------------------------------------------------------------------------------
-- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP
-------------------------------------------------------------------------------

---List of all copyable fields in entity properties. Used for copy-pase.
local copyable_fields = {
    "selected_template",
    "selected_item",
    "selected_fluid",
    "is_output",
}

---List of functions to perform when registring an entity
local registration_hooks = {
    [PREFIX .. "template-item-io"] = {
        cache_inventory_object,
    },
    [PREFIX .. "mainframe-item-io"] = {
        cache_inventory_object,
    },
}

---List of functions to perform when setting a value in properties
local field_setting_hooks = {
    [PREFIX .. "template-item-io"] = {
        selected_item = {generate_buffer_key},
    },
    [PREFIX .. "mainframe-item-io"] = {
        selected_template = {move_to_new_cluster},
        selected_item = {generate_buffer_key},
    },
    [PREFIX .. "mainframe-fluid-io"] = {
        selected_template = {move_to_new_cluster}
    },
    [PREFIX .. "mainframe-energy-io"] = {
        selected_template = {move_to_new_cluster}
    },
    [PREFIX .. "virtualization-mainframe"] = {
        selected_template = {
            move_to_new_cluster,
            VMManager.on_template_change
        }
    }
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

    -- performing necessery on-registration actions
    local hooks = registration_hooks[entity.name]
    if hooks then
        for _, hook in ipairs(hooks) do
            hook(properties)
        end
    end

    -- adding event tags to properties
    if tags and tags[ENTITY_TAG_KEY] then
        local relevant_tags = tags[ENTITY_TAG_KEY]
        for _, field in ipairs(copyable_fields) do
            properties[field] = relevant_tags[field]
            local entity_hooks = field_setting_hooks[entity.name]
            if entity_hooks and entity_hooks[field] then
                for _, hook in ipairs(entity_hooks[field]) do
                    hook(properties)
                end
            end
        end
    end

    -- adding table to registry
    table.insert(reg.array, properties)
    reg.lookup[entity.unit_number] = #reg.array
end

---Removes entity from registry. Used for automatic garbage collection.
---@param unit_number integer unique entity identifier
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
---@return EntityProperties|nil properties entity data from registry
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
        local entity_hooks = field_setting_hooks[entity.name]
        if not entity_hooks then return end
        local hooks = entity_hooks[field]
        if not hooks then return end
        for _, hook in ipairs(hooks) do
            ---@diagnostic disable-next-line: param-type-mismatch
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
---@param name string|nil name of selected item
---@param quality string|nil quality of selected item
function EntityProcessor.set_selected_item(entity, name, quality)
    local item_data = (name and quality and {name = name, quality = quality}) or nil
    set_entity_property(entity, "selected_item", item_data)
end

---Sets selected fluid for given entity or entity-ghost
---@param entity LuaEntity
---@param fluid_name string|nil name of the fluid, or nil to clear
function EntityProcessor.set_selected_fluid(entity, fluid_name)
    local fluid_data = fluid_name and {name = fluid_name} or nil
    set_entity_property(entity, "selected_fluid", fluid_data)
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
---@return any property for table returns reference, not a copy
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
    return get_entity_property(entity, "selected_template")
end

---Gets selected item for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return ItemSelection|nil selected_item {name, quality}
function EntityProcessor.get_selected_item(entity)
    return get_entity_property(entity, "selected_item")
end

---Gets selected fluid for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil fluid_name
function EntityProcessor.get_selected_fluid(entity)
    local fluid = get_entity_property(entity, "selected_fluid")
    return fluid and fluid.name
end

---Gets output flag for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return boolean|nil is_output
function EntityProcessor.get_output_flag(entity)
    return get_entity_property(entity, "is_output")
end

---Gets building requests of a given entity. Currently only virtualization
---mainframes can have this field.
---@param entity LuaEntity
---@return table<ItemKeyString, ItemBuffer>|nil
function EntityProcessor.get_construction_requests(entity)
    if not entity.valid then return end
    local properties = get_entity_data(entity.unit_number)
    if not properties then return end
    ---@cast properties MainframeProperties
    return VMManager.get_construction_requests(properties)
end

---Gets contained buildings of a given entity. Currently only virtualization
---mainframes can have this field.
---@param entity LuaEntity
---@return table<ItemKeyString, ItemBuffer>|nil
function EntityProcessor.get_contained_buildings(entity)
    if not entity.valid then return end
    local properties = get_entity_data(entity.unit_number)
    if not properties then return end
    ---@cast properties MainframeProperties
    return VMManager.get_contained_buildings(properties)
end

---Gets status of a given virtualization mainframe.
---@param entity LuaEntity
---@return LocalisedString status
function EntityProcessor.get_mainframe_status(entity)
    -- mainframe is invalid
    if not entity.valid then
        return {"entity-status.invalid"}
    end
    -- mainframe is a ghost
    if entity.name == "entity-ghost" then
        return {"entity-status.ghost"}
    end
    local properties = get_entity_data(entity.unit_number)
    -- mainframe is not registered: critical error
    if not properties then
        return {"entity-status.not-registered"}
    end
    ---@cast properties MainframeProperties
    return VMManager.get_mainframe_status(properties)
end

---Gets virtualization cluster entity is a part of
---@param entity LuaEntity
---@return ClusterData|nil
function EntityProcessor.get_cluster(entity)
    return get_entity_property(entity, "cluster")
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
        -- skipping entities that are not recognized by this registry
        if not entity_router[entity.name] then goto continue end

        -- if registry does not have entity properties we have to skip it
        local properties = get_entity_data(entity.unit_number)
        if not properties then goto continue end

        -- creating a shallow copy with all copyable properties
        local properties_copy = {}
        for _, field in ipairs(copyable_fields) do
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