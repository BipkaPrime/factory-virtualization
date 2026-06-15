-- This file is for logic regarding lab surfaces: 
-- creation, deletion, state changes, auto-building processes

-- TODO
-- optimization improvement:
-- don't process the whole lab surface on 1 tick, distribute the load 
-- and process surfaces by tiles instead
-- Currently we are scanning entire surface several times. This has to be changed.


local Manager = {}

-- Initializes storage
function Manager.storage_init()
    -- table containing surface indexes for labs that can be modified by the player
    storage.designing_labs = storage.designing_labs or {}

    -- table containing surface indexes for labs that are compiling
    storage.compiling_labs = storage.compiling_labs or {}
end

----------------------------------------------------------------------------------
-- Creation, Deletion, State Change
----------------------------------------------------------------------------------

-- Creates a new square lab surface
function Manager.create_new_lab(name, size)
    local lab_name = name or ("Virtual Lab #" .. game.tick)
    local map_size = size or 64

    local surface = game.create_surface(lab_name, {
        width = map_size,
        height = map_size,
        starting_area = 0
    })

    -- modifying surface attributes 
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.show_clouds = false

    -- generating and charting surface area
    surface.request_to_generate_chunks({0, 0}, map_size / 2)
    surface.force_generate_chunk_requests()
    game.forces["player"].chart_all(surface)

    table.insert(storage.designing_labs, surface.index)
    return surface
end

-- Switches the player's camera to the lab
function Manager.enter_lab_view(player, surface_index)
    local surface = game.get_surface(surface_index)
    if not (surface and surface.valid) then return end
    
    player.set_controller{
        type = defines.controllers.remote,
        surface = surface,
        position = {0, 0}
    }
end

----------------------------------------------------------------------------------
-- Time-based services
----------------------------------------------------------------------------------

-- Charts all chunks on a given surface
function chart_surface(surface)
    game.forces["player"].chart_all(surface)
end

-- Handles ghost entities built on a given lab surface
function process_ghosts(surface)
    -- searching for ghosts on a given surface
    local candidates = surface.find_entities_filtered({type="entity-ghost", limit=128})
    local count = #candidates

    if count == 0 then return end

    for _, ghost in ipairs(candidates) do
        if ghost.valid then ghost.revive() end
    end
end

-- Handles entities marked for deconstruction on a given lab surface
function process_deconstruction(surface)
    -- searching for entities marked for deconstruction
    local candidates = surface.find_entities_filtered({to_be_deconstructed=true, limit=128})
    local count = #candidates

    if count == 0 then return end

    for _, entity in ipairs(candidates) do
        if entity.valid then entity.destroy() end
    end
end

-- Handles entities marked for upgrade on a given lab surface
function process_upgrades(surface)
    -- searching for entities marked for upgrade
    local candidates = surface.find_entities_filtered({to_be_upgraded=true, limit=128})
    local count = #candidates

    if count == 0 then return end

    for _, entity in ipairs(candidates) do
        if entity.valid then entity.apply_upgrade() end
    end
end

-- Is run each second. Will process 1 lab per second.
function Manager.process_designing_labs(event)
    if #storage.designing_labs == 0 then return end

    -- calculating lab idx to be processed and related surface
    local lab_idx = math.floor(event.tick / 60) % #storage.designing_labs + 1
    local surface_idx = storage.designing_labs[lab_idx]
    local surface = game.get_surface(surface_idx)
    if not (surface and surface.valid) then return end

    process_deconstruction(surface)
    process_ghosts(surface)
    process_upgrades(surface)
end

-- Is run every second. Will process 1 lab at a time
function Manager.charting(event)
    local designing = storage.designing_labs or {}
    local compiling = storage.compiling_labs or {}
    
    local total_designing = #designing
    local total_compiling = #compiling
    local total_labs = total_designing + total_compiling

    if total_labs == 0 then return end
    local lab_idx = (math.floor(event.tick / 60) % total_labs) + 1

    local surface_idx
    if lab_idx <= total_designing then
        -- Выбираем из списка редактируемых лабораторий
        surface_idx = designing[lab_idx]
    else
        -- Выбираем из списка компилируемых лабораторий
        surface_idx = compiling[lab_idx - total_designing]
    end

    -- Получаем саму поверхность в Factorio по её индексу
    local surface = game.get_surface(surface_idx)
    
    if surface and surface.valid then
        chart_surface(surface)
    end
end



return Manager