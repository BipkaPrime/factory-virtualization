-- This mod introduces several entities that need to be tracked.
-- To tackle this problem, we create an entity registry in storage table.
-- Each entity name is associated with it's own section in the registry.
-- Each section contains 2 tables called "array" and "lookup".
-- The "array" is for storing tables that contain LuaEntity objects and custom mod settings associated with them. It's gap-free.
-- The "lookup" is for storing entity.unit_number identifiers.
-- It's a hash map that stores [unit_number] = array_idx
-- It's required for the ability to find and delete an entity in O(1) time

local Helpers = {}

-- table with all entity names that are included in the registry
local tracked_entities = {
    ["item-uplink"] = true,
    ["item-downlink"] = true,
    ["fluid-uplink"] = true,
    ["fluid-downlink"] = true,
    ["energy-uplink"] = true,
    ["energy-downlink"] = true,
}

-- Used as event filter for build/destroy events
Helpers.event_filter = {}
for building_name, _ in pairs(tracked_entities) do
    table.insert(Helpers.event_filter, {filter = "name", name = building_name})
end


-- Used on_init or on_configuration_change to set up storage table
function Helpers.storage_init()
    storage.entity_registry = storage.entity_registry or {}
    for entity_name, _ in pairs(tracked_entities) do
        storage.entity_registry[entity_name] = storage.entity_registry[entity_name] or {array = {}, lookup = {}}
    end
end

-- Adds an entity to the registry
local function add_to_registry(entity, entity_name)
    if not (entity and entity.valid and entity.unit_number and entity_name) then return end
    
    local reg = storage.entity_registry[entity_name]
    
    -- Prevent duplicate entries
    if reg.lookup[entity.unit_number] then return end
    
    -- Append the entity to the end of the correct array
    table.insert(reg.array, {["entity"] = entity})
    
    -- Record its current index location for O(1) removals later
    reg.lookup[entity.unit_number] = #reg.array
end

-- Removes an entity from the registry
local function remove_from_registry(entity, entity_name)
    if not (entity and entity.unit_number and entity_name) then return end

    local reg = storage.entity_registry[entity_name]
    local index = reg.lookup[entity.unit_number]
    if not index then return end

    local array_length = #reg.array
    -- If the target is not the last item, swap it with the last item
    if index < array_length then
        local last_element = reg.array[array_length]
        reg.array[index] = last_element
        
        -- Update the index tracker for the moved element
        reg.lookup[last_element.entity.unit_number] = index
    end
    
    -- Safely drop the redundant last slot from the array
    table.remove(reg.array)
    
    -- Clear the entry from the tracking lookup table
    reg.lookup[entity.unit_number] = nil
end

-- Handles on_built_entity and similar events add entity to registry
function Helpers.register_entity(event)
    if not (event.entity and event.entity.valid) then return end
    add_to_registry(event.entity, event.entity.name)
end

-- Handles on_entity_died and similar events
function Helpers.unregister_entity(event)
    if not (event.entity and event.entity.valid) then return end
    remove_from_registry(event.entity, event.entity.name)
end

-- Resets the registry then scans all game surfaces to add all tracked entities
-- Will be very slow on large bases. May be used on_configuration_change but mostly for debugging
local function reset_registry()
    storage.entity_registry = {}
    for entity_name, _ in pairs(tracked_entities) do
        storage.entity_registry[entity_name] = {array = {}, lookup = {}}
        for _, surface in pairs(game.surfaces) do
            local entities = surface.find_entities_filtered{name = entity_name}
            for _, entity in ipairs(entities) do
                add_to_registry(entity, entity_name)
            end
        end
    end
end

commands.add_command("reset_registry", "Resets the entity registry then scans all surfaces repopulate it", reset_registry)

return Helpers