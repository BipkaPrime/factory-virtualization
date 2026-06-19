-- This file is for logic regarding lab surfaces: 
-- creation, deletion, state changes, auto-building processes

local Manager = {}

------------------------------------------------------------------------------------
-- Registry Operations: init, add, remove, switch section
------------------------------------------------------------------------------------

-- Initializes storage
function Manager.storage_init()
    storage.lab_chunks_registry = storage.lab_chunks_registry or {
    -- Gapless arrays containing lab chunks for on_tick processing
    designing_chunks = {array = {}, lookup = {}},
    compiling_chunks = {array = {}, lookup = {}}
    }
end

-- Registers all chunks of a given surface to specified registry
-- @param lab_type = ("designing" or "compiling")
function Manager.register_surface(surface_index, lab_type)
    -- Selecting the right registry section
    local chunk_reg = storage.lab_chunks_registry[lab_type .. "_chunks"]
    local surface = game.get_surface(surface_index)
    
    -- Ensure the surface actually exists in the game engine before scanning
    if not (surface and surface.valid) then return end

    for chunk in surface.get_chunks() do
        -- Unique chunk identifier
        local chunk_key = surface_index .. ":" .. chunk.x .. "," .. chunk.y
        
        -- Avoiding duplicates
        if not chunk_reg.lookup[chunk_key] then
            local chunk_data = {
                surface_index = surface_index,
                x = chunk.x,
                y = chunk.y
            }
            table.insert(chunk_reg.array, chunk_data)
            chunk_reg.lookup[chunk_key] = #chunk_reg.array
        end
    end
end

-- Removes all chunks belonging to a specific surface from the specified registry
-- @param lab_type =  ("designing" or "compiling")
function Manager.unregister_surface(surface_index, lab_type)
    local chunk_reg = storage.lab_chunks_registry[lab_type .. "_chunks"]
    
    -- Iterating through the right section backwards
    for i = #chunk_reg.array, 1, -1 do
        local chunk = chunk_reg.array[i]
        
        -- Check if this chunk belongs to the surface we want to unregister
        if chunk.surface_index == surface_index then
            local chunk_key = surface_index .. ":" .. chunk.x .. "," .. chunk.y
            
            local array_length = #chunk_reg.array
            -- If this is not the last element, swap it with the last one
            if i < array_length then
                local last_chunk = chunk_reg.array[array_length]
                chunk_reg.array[i] = last_chunk
                
                -- Update the index in lookup for the chunk that was just moved
                local last_chunk_key = last_chunk.surface_index .. ":" .. last_chunk.x .. "," .. last_chunk.y
                chunk_reg.lookup[last_chunk_key] = i
            end
            
            -- Remove the redundant last element and erase the lookup key
            table.remove(chunk_reg.array)
            chunk_reg.lookup[chunk_key] = nil
        end
    end
end

-- Switches the processing state of a lab surface
-- @param target_state = ("designing" or "compiling")
function Manager.switch_lab_state(surface_index, target_state)
    if not (surface_index and target_state) then return end
    
    -- Determine the previous state to know which registry section to clean up
    local source_state = "designing"
    if target_state == "designing" then
        source_state = "compiling"
    end
    
    -- Remove chunks from the old processing section
    Manager.unregister_surface(surface_index, source_state)
    
    -- Add chunks to the new processing section
    Manager.register_surface(surface_index, target_state)
end

------------------------------------------------------------------------------------
-- Lab Surface Services
------------------------------------------------------------------------------------

-- Force reveal chunk area on the map
local function chart_chunk(surface, chunk_area)
    game.forces["lab-technical"].chart(surface, chunk_area)
end

-- Handles entities marked for deconstruction
local function process_deconstruction(surface, chunk_area)
    local to_deconstruct = surface.find_entities_filtered{
        area = chunk_area,
        to_be_deconstructed = true
    }
    for i = 1, #to_deconstruct do
        local entity = to_deconstruct[i]
        if entity.valid then
            -- raise_destroy = true triggers script_raised_destroy for entity registry
            entity.destroy{raise_destroy = true}
        end
    end
end

-- Find and revive entity ghosts
local function process_ghosts(surface, chunk_area)
    local ghosts = surface.find_entities_filtered{
        area = chunk_area,
        type = "entity-ghost"
    }
    for i = 1, #ghosts do
        local ghost = ghosts[i]
        if ghost.valid then
            -- raise_built = true triggers script_raised_revive for entity registry
            local _, new_entity = ghost.revive{raise_revive = true}
            if new_entity and new_entity.valid then
                new_entity.force = game.forces["lab-technical"]
            end
        end
    end
end

-- Handles entities marked for upgrade
local function process_upgrades(surface, chunk_area)
    local to_upgrade = surface.find_entities_filtered{
        area = chunk_area,
        to_be_upgraded = true
    }
    for i = 1, #to_upgrade do
        local entity = to_upgrade[i]
        if entity.valid then
            entity.apply_upgrade()
        end
    end
end

-- Processes all services sequentially
local function update_designing_chunk(surface, chunk)
    -- Calculate precise chunk boundaries once to share among all services
    local top_left_x = chunk.x * 32
    local top_left_y = chunk.y * 32
    local chunk_area = {{top_left_x, top_left_y}, {top_left_x + 32, top_left_y + 32}}

    process_deconstruction(surface, chunk_area)
    process_ghosts(surface, chunk_area)
    process_upgrades(surface, chunk_area)
    chart_chunk(surface, chunk_area)
end

-- Processes only radar charting for compiling mode chunks (no modifications allowed)
local function update_compiling_chunk(surface, chunk)
    local top_left_x = chunk.x * 32
    local top_left_y = chunk.y * 32
    local chunk_area = {{top_left_x, top_left_y}, {top_left_x + 32, top_left_y + 32}}

    chart_chunk(surface, chunk_area)
end

-- Iterates through a specified registry using interleaved offset
local function process_registry_section(section, tick, handler)
    local total_count = #section.array
    if total_count == 0 then return end
    
    -- The 60-tick interleaved offset loop
    local offset = (tick % 60) + 1
    for i = offset, total_count, 60 do
        local chunk = section.array[i]
        local surface = game.get_surface(chunk.surface_index)
        
        if surface and surface.valid then
            handler(surface, chunk)
        else
            -- Auto-cleanup if the surface was deleted by another script or command
            local current_type = (section == storage.lab_chunks_registry.designing_chunks) and "designing" or "compiling"
            Manager.unregister_surface(chunk.surface_index, current_type)
            return -- Break execution loop since the array length has changed
        end
    end
end

-- Main on-tick processor
function Manager.process_chunks(event)
    local reg = storage.lab_chunks_registry
    -- Process designing labs
    process_registry_section(reg.designing_chunks, event.tick, function(surface, chunk)
        update_designing_chunk(surface, chunk)
    end)
    
    -- Process compiling labs
    process_registry_section(reg.compiling_chunks, event.tick, function(surface, chunk)
        update_compiling_chunk(surface, chunk)
    end)
end

return Manager