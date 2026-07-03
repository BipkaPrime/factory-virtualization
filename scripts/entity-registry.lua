-- This mod introduces several entities that need to be tracked.
-- To tackle this problem, we create an entity registry in storage table.
-- We want it to do two things. First, it should contain 1-indexed array
-- with all data of entities that are "in" the registry for performance reasons.
-- Each tick we will process every 60-th element of that array with changing offset.
-- Second, we want to be able to access data for a given entity in O(1) time.
-- To achieve this, registry will consist of 2 parts:
--[[
storage.entity_registry = {
    -- main 1-indexed array
    array = {}, 
    -- hashmap for fast access with keys: entity.unit_number,
    -- and values: index of entity data in the main array
    lookup = {},
}
--]]
--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = get_entity_data(unit_number). table keys:
-- selected_template string: selected template for a given entity if any
-- vsurface_io bool: true if given uplink/downlink is a vsurface IO
-- selected_item (table) {name, quality}: item filter selected in item udlink
-- selected_fluid (table): {name} fluid name selected in fluid udlink


local udlink_manager = require("scripts.udlink-manager")
local names = require("scripts.gui.names")
local mainframe_manager = require("scripts.vmainframe-manager")

local Helper = {}

-- Adds given entity to registry
-- @param entity LuaEntity
local function register_entity(entity)
    if not entity or not entity.valid or not entity.unit_number then return end
    local reg = storage.entity_registry
    -- avoiding duplicates
    if reg.lookup[entity.unit_number] then return end
    table.insert(reg.array, {entity = entity, unit_number = entity.unit_number})
    reg.lookup[entity.unit_number] = #reg.array
end

-- Removes given entity from registry. Used for automatic garbage collection.
-- @param unit_number
local function unregister_entity(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]

    -- swapping element we want to delete with the last one
    local last_element = reg.array[#reg.array]
    reg.array[index] = last_element
    reg.lookup[last_element.unit_number] = index

    -- removing last element from both tables 
    table.remove(reg.array)
    reg.lookup[unit_number] = nil
end

-- Returns table describing entity from entity registry
-- @param unit_number int: unique entity identifier
function Helper.get_entity_data(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]
    if not index then return end
    return reg.array[index]
end

-- Maps entity names to their on-tick handlers
local entity_router = {
    [names.prefix .. "item-uplink"] = udlink_manager.update_item_uplink,
    [names.prefix .. "item-downlink"] = udlink_manager.update_item_downlink,
    [names.prefix .. "fluid-uplink"] = udlink_manager.update_fluid_uplink,
    [names.prefix .. "fluid-downlink"] = udlink_manager.update_fluid_downlink,
    [names.prefix .. "energy-uplink"] = udlink_manager.update_energy_uplink,
    [names.prefix .. "energy-downlink"] = udlink_manager.update_energy_downlink,
    [names.prefix .. "virtualization-mainframe"] = mainframe_manager.update_vmainframe,
}

-- Subscribing to all build events 
local build_filter = {}
for building_name, _ in pairs(entity_router) do
    table.insert(build_filter, {filter = "name", name = building_name})
end
local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_revive
}
local function on_entity_built(event)
    local entity = event.entity
    register_entity(entity)
end
for _, event in ipairs(build_events) do
    script.on_event(event, on_entity_built, build_filter)
end

-- Used for on-tick entity processing
function Helper.entity_processor(event)
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

return Helper