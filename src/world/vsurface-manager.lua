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

---@class VSurfaceConfig contains necessery information for vsurface creation
---@field name string|nil name of new vsurface
---@field width number|nil width of new vsurface
---@field height number|nil height of new vsurface
---@field generate_as string|nil name of planet which magpen should be used

---@class VSurfaceData
---@field surface_index integer unique surface identifier
---@field surface_name string name of given surface
---@field compiling boolean true if surface is currently compiling (needed for gui filtering)
---@field idle_demand number amount of computation required for this surface when idle
---@field compiling_demand number amount of computation required for this surface when compiling
---@field energy_drain number template energy drain
---@field width number width of the surface
---@field height number height if the surface


local ChunkProcessor = require("src.world.vsurface-chunk-processor")
local ComputationManager = require("src.simulation.computation-manager")

local VSurfaceManager = {}

-------------------------------------------------------------------------------
------------------------------ VSURFACE CREATION ------------------------------
-------------------------------------------------------------------------------

---Calculates idle computation demand for a vsurface given its config
---@param vsurface_config VSurfaceConfig
function VSurfaceManager.get_idle_computation_demand(vsurface_config)
    return VSurfaceManager.get_compiling_computation_demand(vsurface_config) / 10
end

---Calculates compilation computation demand for a vsurface given its config
---@param vsurface_config VSurfaceConfig
function VSurfaceManager.get_compiling_computation_demand(vsurface_config)
    local width = vsurface_config.width or 0
    local height = vsurface_config.height or 0
    local area = width * height
    local demand = 0

    -- computation demand scales with area
    if area <= 4096 then
        -- smaller then [64x64]
        demand = area * 6
    elseif area <= 65536 then
        -- from [64x64] to [256x256]
        demand = 24576 + (area - 4096) * 1500
    else
        -- from [256x256] to [1024x1024]
        demand = 92184576 + (area - 65536) * 100000
    end

    -- computation demand is greater for surfaces, which have generate_as option
    if vsurface_config.generate_as then
        demand = demand * 2
    end

    return demand
end

---Calculates template energy drain for vsurface given its config
---@param vsurface_config VSurfaceConfig
---@return number energy_drain passive template energy drain
function VSurfaceManager.get_vsurface_energy_drain(vsurface_config)
    local width = vsurface_config.width or 0
    local height = vsurface_config.height or 0
    local area = width * height
    local drain = 1e8 + 2500*(area)^(1.09)
    -- energy drain is greater for surfaces, which have generate_as option
    if vsurface_config.generate_as then
        drain = drain * 2
    end

    return drain
end

---Collects names of all planets that are present in game for
---player too choose one of them as vsurface generation option
---@return string[]
function VSurfaceManager.get_generate_as_options()
    local options = {}
    for name, _ in pairs(game.planets) do
        table.insert(options, name)
    end
    return options
end

---Checks if a vsurface with specified parameters can be created
---@param vsurface_config VSurfaceConfig
---@return boolean status true if surface can be created
---@return LocalisedString|nil reason why surface cannot be created if any
function VSurfaceManager.can_create_vsurface(vsurface_config)
    local name = vsurface_config.name
    -- checking that name is not empty
    if not name or not string.find(name, "%S", 1, false) then
        return false, "Surface name is missing"
    end
    -- checking that no surface or planet is associated with provided name
    if game.get_surface(name) ~= nil or game.planets[name] ~= nil then
        return false, "Surface name is not available"
    end
    -- validating surface width
    local width = vsurface_config.width
    if not width or type(width) ~= "number" or width < 1 or width > 1024 then
        return false, "Surface width must be an integer in the range [1, 1024]"
    end
    -- validating surface height
    local height = vsurface_config.height
    if not height or type(height) ~= "number" or height < 1 or height > 1024 then
        return false, "Surface height must be an integer in the range [1, 1024]"
    end

    -- TODO: check surface tier
    -- TODO: check computation limits
    -- TODO: control center entity is ok?
    return true
end

---Prepares map gen setting for creation of new surface.
---Returns tweaked mapgen settings of a given planet if planet name was
---provided and planet found, nil otherwise.
---@param planet_name string|nil name of planet
---@return MapGenSettings|nil
local function prepare_planet_mapgen_settings(planet_name)
    if not planet_name then return end
    local planet = game.planets[planet_name]
    if not planet then return end
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
    mgs.seed = math.random(1, 4e9)

    return mgs
end

---Attempts to create a new virtualization surface
---@param vsurface_config VSurfaceConfig required data for vsurface creation
---@return boolean status true if surface was successfully created
function VSurfaceManager.create_vsurface(vsurface_config)
    -- checking that surface can be created
    local status = VSurfaceManager.can_create_vsurface(vsurface_config)
    if not status then return status end

    ---@type number checked earlier
    local width = vsurface_config.width
    ---@type number checked earlier
    local height = vsurface_config.height

    -- preparing mapgen settings
    local planet_generation = true
    local mgs = prepare_planet_mapgen_settings(vsurface_config.generate_as)
    if not mgs then
        planet_generation = false
        mgs = {width = width, height = height}
    else
        mgs.width, mgs.height = width, height
    end

    -- creating surface with specified properties
    local surface = game.create_surface(vsurface_config.name, mgs)
    -- making sure sufrace was created
    if not surface then
        -- TODO: log config?
        game.print("[VSurface manager] Error: could not create vsurface with specified config")
        return false
    end

    -- modifying surface attributes
    surface.always_day = true
    surface.ignore_surface_conditions = true
    if not planet_generation then
        surface.generate_with_lab_tiles = true
    end

    -- generation vsurface chunks
    local chunk_radius = math.ceil(math.max(width, height) / 64)
    surface.request_to_generate_chunks({0, 0}, chunk_radius)

    -- adding vsurface data to storage
    local surface_index = surface.index
    ---@type VSurfaceData
    local vsurface_data = {
        surface_index = surface_index,
        surface_name = vsurface_config.name,
        compiling = false,
        idle_demand = VSurfaceManager.get_idle_computation_demand(vsurface_config),
        compiling_demand = VSurfaceManager.get_compiling_computation_demand(vsurface_config),
        energy_drain = VSurfaceManager.get_vsurface_energy_drain(vsurface_config),
        width = width,
        height = height,
    }
    local vsurfaces = storage.vsurfaces
    table.insert(vsurfaces.array, vsurface_data)
    vsurfaces.lookup[surface_index] = vsurface_data

    -- adding surface to chunk registry for chunk processing
    ChunkProcessor.register_surface(surface)
    -- adding idle computation demand of created vsurface
    ComputationManager.increase_demand(vsurface_data.idle_demand)
    return true
end

-------------------------------------------------------------------------------
------------------------------ VSURFACE DELETION ------------------------------
-------------------------------------------------------------------------------

---Attempts to delete a vsurface provided its name
---@param surface_name string|nil name of the surface
---@return boolean status true if surface was successfully deleted
function VSurfaceManager.delete_vsurface_by_name(surface_name)
    if not surface_name then
        game.print("[Vsurface Manager] [color=red]Error:[/color] deletion failed, missing surface name")
        return false
    end
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then
        game.print("[Vsurface Manager] [color=red]Error:[/color] deletion failed, surface doesn't exist")
        return false
    end
    local surface_index = surface.index
    ---@type VSurfaceData
    local data = storage.vsurfaces.lookup[surface_index]
    if not data then
        game.print("[Vsurface Manager] [color=red]Error:[/color] deletion failed, vsurface data not found")
        return false
    end
    if data.compiling then
        game.print("[Vsurface Manager] [color=red]Error:[/color] deletion failed, can't delete compiling vsurface")
        return false
    end
    -- attempting to delete the surface
    if not game.delete_surface(surface_index) then
        game.print("[Vsurface Manager] [color=red]Error:[/color] deletion failed, surface protected by game engine")
        return false
    end

    -- removing vsurface data from both tables
    ---@type VSurfaceData[]
    local array = storage.vsurfaces.array
    ---@type table<integer, VSurfaceData>
    local lookup = storage.vsurfaces.lookup
    lookup[surface_index] = nil
    for i = 1, #array do
        local item = array[i]
        if item.surface_index == surface_index then
            table.remove(array, i)
            break
        end
    end

    -- removing computation demand of deleted surface
    ComputationManager.decrease_demand(data.idle_demand)
    return true
end

---Finds and deletes the most recently created vsurface
---TODO: add compiling check, add actual surface deletion
local function delete_last_vsurface()
    local vsurfaces = storage.vsurfaces
    ---@type VSurfaceData[]
    local array = vsurfaces.array
    if #array == 0 then return end
    ---@type table<integer, VSurfaceData>
    local lookup = vsurfaces.lookup

    -- deleting the last element from array and lookup
    local data = array[#array]
    table.remove(array)
    lookup[data.surface_index] = nil

    -- removing computation demand of deleted surface
    ComputationManager.decrease_demand(data.idle_demand)
end

-------------------------------------------------------------------------------
-- VSURFACE INFO GETTERS/SETTERS
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