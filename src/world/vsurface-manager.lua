--[[
This mod allows players to create "virtualization surfaces". They are basically
sandboxes where player can build anything for free. They are used in creation
of templates. To create a template player has to build a factory on a vsurface
and then start compilation of that surface. When compilation finishes successfully,
template is created.

Computation is required to sustain existance of a virtualiation surface. If there 
is a computation deficit, vsurfaces are deleted one by one until there is no deficit.

Upon creation, vsurface data is stored at storage.vsurfaces and consists of 2 parts:
storage.vsurfaces = {
    array VSurfaceData[] order of elements is used for vsurface deletion in computation deficit
    lookup table<integer, VSurfaceData> key is surface index
}

Vsurface manager handles create/delete vsurface requests. It is also used to access
vsurface information. It's also used to for some other vsurface requests, for example
calculating building cost of a given vsurface.
--]]

---@class VSurfaceData
---@field surface_index integer unique surface identifier
---@field compiling boolean true if surface is currently compiling (needed for gui filtering)
---@field computation_cost number amount of computation required to sustain this surface
---@field width number width of the surface
---@field height number height if the surface


local ChunkProcessor = require("src.world.vsurface-chunk-processor")
local ComputationManager = require("src.simulation.computation-manager")

local VSurfaceManager = {}

-------------------------------------------------------------------------------
-- VSURFACE CREATION
-------------------------------------------------------------------------------

---Gets all vsurface generation options to choose from
---@return string[]
function VSurfaceManager.get_generate_as_options()
    local options = {}
    for name, _ in pairs(game.planets) do
        table.insert(options, name)
    end
    return options
end

---Checks if a vsurface with specified parameters can be created
---@param name string|nil name of the surface
---@param width integer|nil width of the surface
---@param height integer|nil height of the surface
---@param generate_as string|nil name of planet surface should be generated as
---@return boolean status true if surface can be created
---@return string|nil reason why surface cannot be created if any
function VSurfaceManager.can_create_vsurface(name, width, height, generate_as)
    -- checking that name is not empty
    if not name or not name:match("%S") then
        return false, "Surface name is missing"
    end
    -- checking if surface or planet with given name already exists
    if game.get_surface(name) ~= nil or game.planets[name] ~= nil then
        return false, "Surface name not available"
    end
    -- validating surface width
    if not width or type(width) ~= "number" or width < 1 or width > 1024 then
        return false, "Surface width must be an integer in the range [1, 512]"
    end
    -- validating surface height
    if not height or type(height) ~= "number" or height < 1 or height > 1024 then
        return false, "Surface height must be an integer in the range [1, 512]"
    end
    -- checking that generation option is provided
    if not generate_as then
        return false, "Generation option is not chosen"
    end
    return true
end

---Prepares map gen setting for creation of new surface
---@param planet_name string|nil name of planet
---@return MapGenSettings
local function prepare_mapgen_settings(planet_name)
    if not planet_name then return {} end
    local planet = game.planets[planet_name]
    if not planet then return {} end
    local mgs = planet.prototype.map_gen_settings

    -- adjusting autoplace controls
    local _prototypes = prototypes.autoplace_control
    for name, settings in pairs(mgs.autoplace_controls) do
        local category = _prototypes[name].category
        if category == "resource" then
            settings.richness = 500
            settings.frequency = 6
            settings.size = 6
        else
            mgs.autoplace_controls[name] = nil
        end
    end
    -- removing generation of enemies
    mgs.no_enemies_mode = true

    -- changing seed: we do not want a copy of existing planet
    mgs.seed = math.random(1, 4000000000)

    return mgs
end

---Creates a new virtualization surface
---@param player LuaPlayer|nil reference to player who requested surface creation
---@param name string|nil name of new surface
---@param width number|nil width of new surface
---@param height number|nil height of new surface
---@param generate_as string|nil name of planet which mapgen should be used
---@return boolean true if surface was created
---@return string|nil reason why surface was not created if any
function VSurfaceManager.create_vsurface(player, name, width, height, generate_as)
    -- checking that surface can be created
    local status, reason = VSurfaceManager.can_create_vsurface(
        name,
        width,
        height,
        generate_as
    )
    if not status then return status, reason end

    ---@cast name string
    ---@cast width number
    ---@cast height number

    -- preparing mapgen settings
    local mgs = prepare_mapgen_settings(generate_as)
    mgs.width, mgs.height = width, height

    -- creating surface with specified properties
    local trimmed_name = name:match("^%s*(.-)%s*$")
    local surface = game.create_surface(trimmed_name, mgs)
    -- making sure surface was created and it's valid
    if not surface or not surface.valid then
        return false, "Could not create surface"
    end

    local chunk_radius = math.ceil(math.max(width, height) / 64)
    surface.request_to_generate_chunks({0, 0}, chunk_radius)

    -- modifying surface attributes
    -- surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.ignore_surface_conditions = true

    -- adding vsurface data to storage
    storage.vsurfaces[surface.index] = {
        surface_index = surface.index,
        width = width,
        height = height,
    }

    -- adding surface to chunk registry
    ChunkProcessor.register_surface(surface)

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

-------------------------------------------------------------------------------
-- VSURFACE DELETION
-------------------------------------------------------------------------------

---Gets gets vsurface data by surface name
---@param surface_name string|nil
---@return VSurfaceData|nil
local function get_vsurface_data_by_name(surface_name)
    if not surface_name then return end
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then return end
    return storage.vsurfaces.lookup[surface.index]
end

---Deletes vsurface provided its name
---@param surface_name string|nil name of the surface
function VSurfaceManager.delete_vsurface(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return end

    -- attempting to delete the surface
    local surface_index = data.surface_index
    local status = game.delete_surface(surface_index)
    if not status then return end

    -- removing vsurface data from both tables
    local vsurfaces = storage.vsurfaces
    ---@type VSurfaceData[]
    local array = vsurfaces.array
    ---@type table<integer, VSurfaceData>
    local lookup = vsurfaces.lookup
    lookup[surface_index] = nil
    for i = 1, #array do
        local item = array[i]
        if item.surface_index == surface_index then
            table.remove(array, i)
            break
        end
    end

    -- removing computation demand of deleted surface
    ComputationManager.decrease_demand(data.computation_cost)
end

---Finds and deletes the most recently created vsurface
---Assumes there is at least one existing vsurface
local function delete_last_vsurface()
    local vsurfaces = storage.vsurfaces
    ---@type VSurfaceData[]
    local array = vsurfaces.array
    ---@type table<integer, VSurfaceData>
    local lookup = vsurfaces.lookup

    -- deleting the last element from array and lookup
    local data = array[#array]
    table.remove(array)
    lookup[data.surface_index] = nil

    -- removing computation demand of deleted surface
    ComputationManager.decrease_demand(data.computation_cost)
end

-------------------------------------------------------------------------------
-- VSURFACE INFO GETTERS/SETTERS
-------------------------------------------------------------------------------

---Checks if surface with provided name is a vsurface
---@param surface_name string|nil name of the surface
---@return boolean status true if vsurface data is found
function VSurfaceManager.is_vsurface(surface_name)
    return not not get_vsurface_data_by_name(surface_name)
end

---Checks if given surface is a vsurface and currently compiling
---@param surface_name string|nil name of the surface
---@return boolean status true if surface is found and compiling
function VSurfaceManager.is_compiling(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return false end
    return (data.compiling == true)
end

---Checks if given surface is a vsurface and currently idle
---@param surface_name string|nil name of the surface
---@return boolean status true if surface is found and idle
function VSurfaceManager.is_idle(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return false end
    return (data.compiling == false)
end

---Sets compilation flag for given vsurface
---@param surface_index integer unique surface identifier
---@param is_compiling boolean value of compilation flag to set
function VSurfaceManager.set_compilation_flag(surface_index, is_compiling)
    local data = storage.vsurfaces.lookup[surface_index]
    if not data then return end
    data.compiling = is_compiling
end

---Gets names of all vsurfaces in order they were created filtered by compiling flag
---@param is_compiling boolean target value of compiling flag
---@return string[]
local function get_vsurfaces_by_compiling_flag(is_compiling)
    ---@type VSurfaceData[]
    local array = storage.vsurfaces.array
    local surfaces = game.surfaces
    ---@type string[]
    local result = {}
    for _, data in ipairs(array) do
        if data.compiling == is_compiling then
            local surface = surfaces[data.surface_index]
            if surface and surface.valid then
                table.insert(result, surface.name)
            end
        end
    end
    return result
end

---Gets names of all idle vsurfaces in order of their creation 
---@return string[]
function VSurfaceManager.get_idle_vsurfaces()
    return get_vsurfaces_by_compiling_flag(false)
end

---Gets names of all compiling vsurfaces in order of their creation 
---@return string[]
function VSurfaceManager.get_compiling_vsurfaces()
    return get_vsurfaces_by_compiling_flag(true)
end

-------------------------------------------------------------------------------
-- VENV-PROCESSOR/TEMPLATE-COMPILER REQUESTS
-------------------------------------------------------------------------------

---@param surface_id ExtendedSurfaceID|nil
---@return boolean is_valid true if surface is valid
function VSurfaceManager.check_surface_validity(surface_id)
    local surface = VSurfaceManager.get_surface(surface_id)
    return (surface and surface.valid) and true or false
end

---Calculates template energy drain for provided vsurface dimensions
---@param width number|nil surface width
---@param height number|nil surface height
---@return number energy_drain passive template energy drain
function VSurfaceManager.calculate_energy_drain(width, height)
    local area = (width or 0) * (height or 0)
    return 1e8 + 2500*(area)^(1.09)
end

---Calculates passive energy drain of a template for a given surface
---@param surface_index number unique surface identifier
---@return number energy_drain passive template energy drain
function VSurfaceManager.get_vsurface_energy_drain(surface_index)
    local vsurface_data = storage.vsurfaces[surface_index]
    if not vsurface_data then return 0 end
    local width, height = vsurface_data.width, vsurface_data.height
    return VSurfaceManager.calculate_energy_drain(width, height)
end

---Helps in calculating surface building cost. Adds item to total cost.
---@param total_cost table<BufferKeyString, number> building cost
---@param name string name of an item
---@param quality string quality of an item
---@param count number count of an item
local function add_to_cost(total_cost, name, quality, count)
    local key = name .. "//" .. quality
    total_cost[key] = (total_cost[key] or 0) + count
end

---Collects building cost of a vsurface.
---@param surface_index number unique surface identifier
---@return table<BufferKeyString, number> building_cost
function VSurfaceManager.get_vsurface_building_cost(surface_index)
    local surface = game.get_surface(surface_index)
    if not surface or not surface.valid then return {} end

    -- collecting building cost
    local total_cost = {}
    -- getting array[LuaEntity] containing all entities on given surface
    local entities = surface.find_entities_filtered({force = "player"})
    for _, entity in ipairs(entities) do
        -- counting only valid entities excluding ghosts
        if entity and entity.valid then
            -- getting array[ItemToPlace] or nil if entity can't be built
            local build_cost = entity.prototype.items_to_place_this
            if build_cost then
                -- getting LuaQualityPrototype of entity
                local quality = entity.quality
                local item = build_cost[1]
                add_to_cost(total_cost, item.name, quality.name, item.count)
                -- getting LuaInventory or nil if it does not exist
                local module_inv = entity.get_module_inventory()
                -- checking if entity has a module inventory and it's not empty
                if module_inv and not module_inv.is_empty() then
                    -- get_contents() returns an array of {name, count, quality_name}
                    for _, item in ipairs(module_inv.get_contents()) do
                        add_to_cost(total_cost, item.name, item.quality, item.count)
                    end
                end
            end
        end
    end
    -- adding tiles created by player to cost
    local tiles = surface.find_tiles_filtered({has_hidden_tile = true})
    local quality = "normal"
    for _, tile in ipairs(tiles) do
        if tile and tile.valid then
            local build_cost = tile.prototype.items_to_place_this
            if build_cost then
                local item = build_cost[1]
                add_to_cost(total_cost, item.name, quality, item.count)
            end
        end
    end

    return total_cost
end

return VSurfaceManager