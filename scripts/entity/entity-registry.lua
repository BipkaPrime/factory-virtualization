-- This mod introduces several entities that need to be tracked
-- and updated once in a while. For this, we create an entity registry.
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

local vcluster = require("scripts.entity.vcluster")
local names = require("scripts.gui.names")
local util = require("util")

local Helper = {}

-- Adds given entity to registry. Entity is assumed to be valid
function Helper.register_entity(entity, entity_tags)
    if not entity or not entity.valid or not entity.unit_number then return end
    local reg = storage.entity_registry
    -- avoiding duplicates
    if reg.lookup[entity.unit_number] then return end
    local properties = {entity = entity, unit_number = entity.unit_number}
    -- handling ghost tags if there were any
    local tag_key = names.prefix
    if entity_tags and entity_tags[tag_key] then
        for tag, value in pairs(entity_tags[tag_key]) do
            if type(value) == "table" then
                properties[tag] = util.table.deepcopy(value)
            else
                properties[tag] = value
            end
        end
    end
    -- adding table to registry
    table.insert(reg.array, properties)
    reg.lookup[entity.unit_number] = #reg.array
end

-- Removes given entity from registry. Used for automatic garbage collection.
-- @param unit_number
function Helper.unregister_entity(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]

    -- removing entity from vcluster
    local properties = reg.array[index]
    vcluster.remove_from_cluster(properties)

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

return Helper