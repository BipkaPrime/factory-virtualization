-- This file contains logic used to track all mod entities
-- that need to be processed is some unordinar way


local Helpers = {}

-- Static list of all entity names tracked by this mod
local TRACKED_ENTITIES = {
    ["item-uplink"] = true
}

-- Ensures that a sub-registry exists for a specific entity name and returns it
local function verify_registry_exists(entity_name)
    if not storage.entity_registries then
        storage.entity_registries = {}
    end
    if not storage.entity_registries[entity_name] then
        storage.entity_registries[entity_name] = {
            array = {},  -- Gap-free array for fast iteration
            lookup = {}  -- Internal map of [unit_number] = array_index
        }
    end
    return storage.entity_registries[entity_name]
end

-- Сhecks if an entity name is tracked by this mod
function is_tracked(entity_name)
    return TRACKED_ENTITIES[entity_name] == true
end

-- Adds an entity to a specific registry based on its name
function add_to_registry(entity, entity_name)
    if not (entity and entity.valid and entity.unit_number and entity_name) then return end
    
    local reg = verify_registry_exists(entity_name)
    
    -- Prevent duplicate entries
    if reg.lookup[entity.unit_number] then return end
    
    -- Append the entity to the end of the correct array
    table.insert(reg.array, entity)
    
    -- Record its current index location for O(1) removals later
    reg.lookup[entity.unit_number] = #reg.array
end

-- Removes an entity from a specific registry using the "Swap and Pop" technique
function remove_from_registry(entity, entity_name)
    if not (entity and entity.unit_number and entity_name) then return end
    
    if not storage.entity_registries or not storage.entity_registries[entity_name] then return end
    local reg = storage.entity_registries[entity_name]
    
    local index = reg.lookup[entity.unit_number]
    
    if index then
        local array_length = #reg.array
        
        -- If the target is not the last item, swap it with the last item
        if index < array_length then
            local last_entity = reg.array[array_length]
            reg.array[index] = last_entity
            
            -- Update the index tracker for the moved element
            reg.lookup[last_entity.unit_number] = index
        end
        
        -- Safely drop the redundant last slot from the array
        table.remove(reg.array)
        
        -- Clear the entry from the tracking lookup table
        reg.lookup[entity.unit_number] = nil
    end
end

-- Handles on built entity events
function Helpers.process_built_entity(event)
    if not (event.entity and event.entity.valid) then return end
    if is_tracked(event.entity.name) then
        add_to_registry(event.entity, event.entity.name)
    end
end

-- Scans all game surfaces to find and catalog all tracked entity types
function Helpers.scan_and_populate_all()
    for entity_name, _ in pairs(TRACKED_ENTITIES) do
        for _, surface in pairs(game.surfaces) do
            local entities = surface.find_entities_filtered{name = entity_name}
            for _, entity in ipairs(entities) do
                add_to_registry(entity, entity_name)
            end
        end
    end
end

-- Return the local table so it can be assigned via require()
return Helpers