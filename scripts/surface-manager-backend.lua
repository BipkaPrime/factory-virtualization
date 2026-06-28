-- Functions for creation/deletion/etc of v-surfaces 

local chunk_registry = require("scripts.lab-chunks-registry")

local Helper = {}

-- checking availability of surface name
function Helper.surface_name_available(name)
    if not name then return false end
    -- cleaning name
    local trimmed_name = name:match("^%s*(.-)%s*$") or ""
    local cleaned_name = string.lower(trimmed_name)

    -- checking if provided name is available
    local name_available = false
    if cleaned_name ~= "" and game.get_surface(cleaned_name) == nil and game.planets[cleaned_name] == nil then
        name_available = true
    end
    return name_available
end

-- collects all vsurface names
function Helper.get_all_vsurfaces()
    local result = {}
    for surface_index, _ in pairs(storage.v_surfaces) do
        local surface = game.get_surface(surface_index)
        if surface then
            table.insert(result, surface.name)
        end
    end
    return result
end

-- Creates a new square lab surface
-- @param properties table: contains all data required for surface creation
function Helper.create_v_surface(properties, player)
    local name = properties.name
    local size = properties.size
    local type = properties.type
    if not name or not size or not type or not player then return end

    local surface = game.create_surface(name, {
        width = size,
        height = size,
        starting_area = 0
    })
    if not surface then return end

    -- Modifying surface attributes
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.show_clouds = false

    local chunk_radius = math.ceil(size / 64)
    surface.request_to_generate_chunks({0, 0}, chunk_radius)
    surface.force_generate_chunk_requests()
    game.forces["lab-technical"].chart_all(surface)

    -- adding created surface to storage
    storage.v_surfaces[surface.index] = {type = type}

    -- Put chunks into the "designing" section of chunk registry
    chunk_registry.register_surface(surface.index, "designing")

    -- move player's camera to created surface
    player.set_controller{
        type = defines.controllers.remote,
        surface = surface,
        position = {0, 0}
    }
    return surface
end

return Helper