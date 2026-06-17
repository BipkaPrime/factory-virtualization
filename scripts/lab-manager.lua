local ChunksManager = require("scripts.lab-chunks-registry")

local Helper = {}

function Helper.storage_init()
    storage.lab_surfaces = storage.lab_surfaces or {}
end


-- Creates a new square lab surface
local function create_new_lab(name, size)
    local lab_name = name or ("Virtual Lab #" .. game.tick)
    local map_size = size or 64 -- Size in tiles (e.g., 64x64)

    local surface = game.create_surface(lab_name, {
        width = map_size,
        height = map_size,
        starting_area = 0
    })

    -- Modifying surface attributes 
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.show_clouds = false

    local chunk_radius = math.ceil(map_size / 64)
    surface.request_to_generate_chunks({0, 0}, chunk_radius)
    surface.force_generate_chunk_requests()
    game.forces["player"].chart_all(surface)

    -- adding created surface to storage
    storage.lab_surfaces[surface.index] = true
    
    -- Put chunks into the background processing registry
    ChunksManager.register_surface(surface.index, "designing")

    return surface
end

-- Switches the player's camera to the lab
local function enter_lab_view(player, surface_index)
    local surface = game.get_surface(surface_index)
    if not (surface and surface.valid) then return end
    
    player.set_controller{
        type = defines.controllers.remote,
        surface = surface,
        position = {0, 0}
    }
end

-- `/v-create [size]` -> Generates a new lab surface and opens view
commands.add_command("v-create", "Creates a new lab surface. Usage: /v-create [size]", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    
    -- Parse text argument from chat to get custom size, fallback to 64 if empty
    local size = event.parameter and tonumber(event.parameter) or 64
    
    local lab_surface = create_new_lab(nil, size)
    enter_lab_view(player, lab_surface.index)
    
    player.print("[Lab Surface Manager] Lab Created with size " .. size .. "x" .. size .. ". Designing state active.")
end)

return Helper