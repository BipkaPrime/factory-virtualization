-- Functions for lookup/creation/deletion/etc of v-surfaces 

local chunk_registry = require("scripts.vsurface-chunk-registry")

local Helper = {}

-- Checks if a vsurface with given properties can be created, also trims surface name
-- @returns bool: true if surface can be created
-- @return string/nil: reason why surface cannot be created if any
function Helper.can_create_vsurface(properties)
    -- checking that name is not empty
    if not properties.name or properties.name == "" then
        return false, "Surface name is missing"
    end
    -- trimming the name and checking if it's not empty
    properties.name = properties.name:match("^%s*(.-)%s*$")
    if properties.name == "" then
        return false, "Surface name is missing"
    end
    -- checking if surface with given name already exists
    if game.get_surface(properties.name) ~= nil then
        return false, "Surface with provided name already exists"
    end
    -- checking if planet with provided name exists
    if game.planets[properties.name] ~= nil then
        return false, "Surface name not available"
    end
    -- checking if surface size is provided
    if not properties.size then
        return false, "Surface size not specified"
    end
    -- checking if surface type is provided
    if not properties.type then
        return false, "Surface type not specified"
    end
    return true
end

-- Creates a new square virtualization surface
-- @param properties table: contains all data required for surface creation
-- @returns bool: true if surface was created
-- @returns string/nil: reason why surface was not created if any
function Helper.create_vsurface(properties, player)
    -- checking that surface can be created
    local status, reason = Helper.can_create_vsurface(properties)
    if not status then return status, reason end

    -- creating surface with specified properties
    local surface = game.create_surface(properties.name, {
        width = properties.size,
        height = properties.size,
        starting_area = 0
    })
    if not surface then
        return false, "Could not create surface"
    end

    -- Modifying surface attributes
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.show_clouds = false

    local chunk_radius = math.ceil(properties.size / 64)
    surface.request_to_generate_chunks({0, 0}, chunk_radius)
    surface.force_generate_chunk_requests()
    game.forces["lab-technical"].chart_all(surface)

    -- adding created surface table with vsurfaces
    storage.v_surfaces[surface.index] = {
        type = properties.type,
        width = properties.size,
        height = properties.size,
    }
    -- adding surface to chunk registry
    chunk_registry.register_surface(surface.index)
    -- move player's camera to created surface
    if player and player.valid then
        player.set_controller{
            type = defines.controllers.remote,
            surface = surface,
            position = {0, 0}
        }
    end
    return true
end

-- Fetches data about vsurface from storage
function Helper.get_surface_data(surface_name)
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then return end
    local vsurface_data = storage.v_surfaces[surface.index]
    return vsurface_data
end

-- collects names of all existing vsurfaces
-- @returns table[string]: collected names
function Helper.get_all_vsurfaces()
    local result = {}
    for surface_index, _ in pairs(storage.v_surfaces) do
        local surface = game.get_surface(surface_index)
        if surface and surface.valid then
            table.insert(result, surface.name)
        end
    end
    return result
end

-- Deletes vsurface provided it's name
function Helper.delete_vsurface(surface_name)
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then return end
    -- checking if provided surface is a vsurface
    local vsurface_data = storage.v_surfaces[surface.index]
    if not vsurface_data then return end
    local status = game.delete_surface(surface.index)
    if status then storage.v_surfaces[surface.index] = nil end
end

-- Erasing surface data from storage.vsurfaces when surface is deleted
script.on_event(defines.events.on_surface_deleted, function(event)
    storage.v_surfaces[event.surface_index] = nil
end)


return Helper