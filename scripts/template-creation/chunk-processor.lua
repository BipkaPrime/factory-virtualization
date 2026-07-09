-- For virtualization surfaces we want to have several services working on them
-- For example, auto reviving ghosts, auto deconstructing marked, auto upgrade, charting.
-- To achieve this and not cause performance issues, we need to spread the load.
-- Also there are 2 states vsurface can be in: "compiling" and "not compiling".
-- To account for all that we want a flat array with chunk information
-- (surface_index (int), bbox (), compiling (bool)).

local Helper = {}

------------------------------------------------------------------------------------
-- Registry Operations: register, unregister, set compiling flag
------------------------------------------------------------------------------------

-- Adds all chunks of a given surface to chunk registry
function Helper.register_surface(surface_index)
    -- getting the surface and checking its validity
    local surface = game.get_surface(surface_index)
    if not surface or not surface.valid then return end
    -- getting all chunks of a surface and adding them to registry
    for chunk in surface.get_chunks() do
        local chunk_data = {
            surface_index = surface_index,
            area = chunk.area,
            compiling = false
        }
        table.insert(storage.vsurface_chunks, chunk_data)
    end
end

-- Removes all chunks of a given surface from chunk registry.
-- Will be executed automatically in the main processor surface is invalid.
-- Uses the fact that all chunks of the same surface are adjacent to each other.
-- @param surface_index: unique surface identifier
-- @param chunk_index: index of the known invalid chunk from the main loop
local function unregister_surface(surface_index, chunk_index)
    local chunks = storage.vsurface_chunks
    local total_chunks = #chunks
    -- finding first chunk of this surface in registry
    local first_idx = chunk_index
    while first_idx > 1 and chunks[first_idx - 1].surface_index == surface_index do
        first_idx = first_idx - 1
    end
    -- fidning last chunk of this surface in registry
    local last_idx = chunk_index
    while last_idx < total_chunks and chunks[last_idx + 1].surface_index == surface_index do
        last_idx = last_idx + 1
    end
    -- using 2 pointers to overwrite chunks we want deleted
    local write_pointer = first_idx
    local read_pointer = last_idx + 1
    while read_pointer <= total_chunks do
        chunks[write_pointer] = chunks[read_pointer]
        write_pointer = write_pointer + 1
        read_pointer = read_pointer + 1
    end
    -- deleting the tail
    for i = write_pointer, total_chunks do
        chunks[i] = nil
    end
end

-- Sets compiling flag of a given surface to state.
-- Uses the fact that all chunks of the same surface are adjacent to each other.
function Helper.set_compiling_flag(surface_index, state)
    local chunks = storage.vsurface_chunks
    local inside_block = false
    for i = 1, #chunks do
        if chunks[i].surface_index == surface_index then
            inside_block = true
            chunks[i].compiling = state
        elseif inside_block then
            break
        end
    end
end

------------------------------------------------------------------------------------
-- Virtual Surface Services
------------------------------------------------------------------------------------

-- Force reveal chunk area on the map
local function chart_chunk(surface, chunk_area)
    game.forces["player"].chart(surface, chunk_area)
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
            local _, revived_entity = ghost.revive{raise_revive = true}
            -- if revived entity is a lab type we need to disable it by script
            if revived_entity and revived_entity.valid and revived_entity.type == "lab" then
                revived_entity.disabled_by_script = true
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
            local upgraded_entity = entity.apply_upgrade()
            -- if upgraded entity is a lab type we need to disable it by script
            if upgraded_entity and upgraded_entity.valid and upgraded_entity.type == "lab" then
                upgraded_entity.disabled_by_script = true
            end
        end
    end
end

-- TODO: fix this. Currently it works strange with item deletion requests
-- Find and satisfy item request proxies (modules)
local function process_item_requests(surface, chunk_area)
    local proxies = surface.find_entities_filtered{
        area = chunk_area,
        name = "item-request-proxy"
    }
    -- going through all found proxies 
    for _, proxy in ipairs(proxies) do
        -- checking validity
        if proxy and proxy.valid then
            local target_entity = proxy.proxy_target
            -- checking target entity validity
            if target_entity and target_entity.valid then
                -- getting target inventory and proxy requests
                local target_inventory = target_entity.get_module_inventory()
                local requests = proxy.item_requests
                -- processing requests
                if target_inventory then
                    for _, item in ipairs(requests) do
                        target_inventory.insert({name = item.name, quality = item.quality, count = item.count})
                    end
                    -- deleting proxy 
                    proxy.destroy{raise_destroy=true}
                end
            end
        end
    end
end

-- Used on-tick to process chunks in the registry
function Helper.chunk_processor(event)
    -- processing every 60-th chunk
    local chunks = storage.vsurface_chunks
    local offset = (event.tick % 60) + 1
    for i = offset, #chunks, 60 do
        local curr_chunk = chunks[i]
        local surface = game.get_surface(curr_chunk.surface_index)
        if not surface or not surface.valid then
            -- auto cleanup in case surface was deleted
            unregister_surface(curr_chunk.surface_index, i)
            return
        end
        if not curr_chunk.compiling then
            process_deconstruction(surface, curr_chunk.area)
            process_ghosts(surface, curr_chunk.area)
            process_upgrades(surface, curr_chunk.area)
            process_item_requests(surface, curr_chunk.area)
        end
        chart_chunk(surface, curr_chunk.area)
    end
end

return Helper