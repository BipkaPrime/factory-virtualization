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
Keys in properties can differ between entities, however there are always following keys:
properties = {
    entity = LuaEntity,
    unit_number = integer
}

--]]

local util = require("util")
local ClusterProcessor = require("src.simulation.cluster-processor")
local VMManager = require("src.world.vmainframe-manager")
local MainframeIO = require("src.world.mainframe-io-manager")
local TemplateIO = require("src.world.template-io-manager")

local PREFIX = "FV-"
local EntityProcessor = {}

-------------------------------------------------------------------------------
-- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP
-------------------------------------------------------------------------------

---Adds given entity to registry. Entity is assumed to be valid
---@param entity LuaEntity assumed to be valid
---@param tags table entity data that should be added to properties.
function EntityProcessor.register_entity(entity, tags)
    -- avoiding duplicates
    local reg = storage.entity_registry
    if reg.lookup[entity.unit_number] then return end

    -- mandatory entity properties
    local properties = {
        entity = entity,
        unit_number = entity.unit_number,
    }

    -- handling additional tags
    if tags then
        for key, value in pairs(tags) do
            if type(value) == "table" then
                properties[key] = util.table.deepcopy(value)
            else
                properties[key] = value
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
function EntityProcessor.get_entity_data(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]
    if not index then return end
    return reg.array[index]
end

-------------------------------------------------------------------------------
-- DATA MUTATION
-------------------------------------------------------------------------------

---Updates selected template for a given entity by its unit_number.
---Called exclusively by GUI event handlers.
---@param unit_number integer unique entity identifier
---@param template_name string|nil name of the template, or nil to clear
function EntityProcessor.set_selected_template(unit_number, template_name)
    local properties = EntityProcessor.get_entity_data(unit_number)
    if not properties then return end
    properties.selected_template = template_name
end

---Updates selected item and pre-calculates its buffer key.
---@param unit_number integer unique entity identifier
---@param item_name string|nil name of the item (e.g. "iron-plate")
---@param quality string|nil quality of the item (e.g. "rare")
function EntityProcessor.set_selected_item(unit_number, item_name, quality)
    local properties = EntityProcessor.get_entity_data(unit_number)
    if not properties then return end

    if not item_name or not quality then
        properties.selected_item = nil
        properties.buffer_key = nil
        return
    end

    properties.selected_item = {name = item_name, quality = quality}
    properties.buffer_key = item_name .. "//" .. quality
end

---Updates selected fluid for given entity.
---@param unit_number integer unique entity identifier
---@param fluid_name string|nil name of the fluid (e.g. "water")
function EntityProcessor.set_selected_fluid(unit_number, fluid_name)
    local properties = EntityProcessor.get_entity_data(unit_number)
    if not properties then return end
    properties.selected_fluid = fluid_name
    properties.buffer_key = fluid_name
end

---Updates is_output flag for given entity.
---@param unit_number integer unique entity identifier
---@param is_output boolean is_output flag will be set to this value  
function EntityProcessor.set_io_direction(unit_number, is_output)
    local properties = EntityProcessor.get_entity_data(unit_number)
    if not properties then return end
    properties.is_output = is_output
end

-------------------------------------------------------------------------------
-- MAIN PROCESSOR
-------------------------------------------------------------------------------

local entity_router = {
    [PREFIX .. "template-item-io"] = TemplateIO.process_template_item_io,
    [PREFIX .. "template-fluid-io"] = TemplateIO.process_template_fluid_io,
    [PREFIX .. "template-energy-io"] = TemplateIO.process_template_energy_io,
    [PREFIX .. "mainframe-item-io"] = MainframeIO.process_mainframe_item_io,
    [PREFIX .. "mainframe-fluid-io"] = MainframeIO.process_mainframe_fluid_io,
    [PREFIX .. "mainframe-energy-io"] = MainframeIO.process_mainframe_energy_io,
    [PREFIX .. "virtualization-mainframe"] = VMManager.process_vm,
}

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