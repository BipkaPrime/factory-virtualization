--[[
This mod allows players to create "virtualization surfaces". They are basically
sandboxes where player can build anything for free. They are used in creation
of templates. To create a template player has to build a factory on a vsurface
and then start compilation of that surface. When compilation finishes successfully,
template is created.

Computation is required to sustain existance of a virtualiation surface. If there 
is a computation deficit, vsurfaces are deleted one by one until there is no deficit.
The same goes for compilation of vsurfaces, which require significantly more computation.

Upon creation, vsurface data is stored at storage.vsurfaces and consists of 2 parts:
storage.vsurfaces = {
    array VSurfaceData[]: order of elements is used for vsurface deletion in computation deficit
    lookup table<integer|string, VSurfaceData>: key is surface name and surface index.
    compilation_queue integer[]: contains surface indexes of compiling vsurfaces
        in chronological order. Older compilations first.
    next_compilation integer: index of compilation that should be processed next tick
}

Vsurface manager handles creation and deletion of vsurfaces as well as vsurface data lookups.
It also orchestrates vsurface compilation and handles start/stop compilation requests.
--]]

---Table containing user inputs necessery for creation of vsurface
---@class VSurfaceConfig
---@field name string|nil name of new vsurface
---@field width number|nil width of new vsurface
---@field height number|nil height of new vsurface
---@field generate_as string|nil name of planet which magpen should be used

---Table containing additional vsurface information used for compilation
---@class CompilationVEnv
---@field template_name string|nil name of compiling template (unique template identifier)
---@field compilation_start integer|nil tick at which compilation was started
---@field compilation_stop integer|nil tick at which compilation should end
---@field last_update integer|nil tick at which this environment was last updated
---@field input table<BufferKeyString, number> accumulated compilation inputs
---@field output table<BufferKeyString, number> accumulated compilation outputs

---@class VSurfaceData
---@field surface_index integer unique surface identifier
---@field name string name of given surface
---@field width number width of the surface
---@field height number height if the surface
---@field compiling boolean true if surface is currently compiling (needed for gui filtering)
---@field idle_demand number amount of computation required for this surface when idle
---@field compiling_demand number amount of computation required for this surface when compiling
---@field energy_drain number template energy drain
---@field compilation_venv CompilationVEnv

local ChunkProcessor = require("src.world.vsurface-chunk-processor")
local TCCManager = require("src.simulation.tcc-manager")
local CommonGui = require("src.gui.common")

local VSurfaceManager = {}

--TODO: add listeners to events like delete surface/rename surface, etc to keep data in storage accurate

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
    local demand = 0.5 * area^1.3 + 1e-12 * area^4

    -- demand is greater for surfaces, which use "generate_as" option
    if vsurface_config.generate_as then
        demand = demand * 2 + 1e5
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
    local drain = 5e7 + 5000 * area^1.1 + 1e-12 * area^3.73

    -- energy drain is greater for surfaces, which have generate_as option
    if vsurface_config.generate_as then
        drain = drain * 2 + 4e8
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
---@return boolean status, LocalisedString|nil reason
function VSurfaceManager.can_create_vsurface(vsurface_config)
    local name = vsurface_config.name
    -- checking that name is not empty
    if not name or not string.find(name, "%S", 1, false) then
        return false, {"vsurface-manager.surface-name-missing"}
    end
    -- checking that no surface or planet is associated with provided name
    if game.get_surface(name) ~= nil or game.planets[name] ~= nil then
        return false, {"vsurface-manager.surface-name-unavailable"}
    end
    -- validating surface width
    local width = vsurface_config.width
    if not width or type(width) ~= "number" or width < 1 or width > 1024 then
        return false, {"vsurface-manager.surface-width-incorrect"}
    end
    -- validating surface height
    local height = vsurface_config.height
    if not height or type(height) ~= "number" or height < 1 or height > 1024 then
        return false, {"vsurface-manager.surface-height-incorrect"}
    end
    -- checking that TCC max template drain is sufficient
    local template_drain = VSurfaceManager.get_vsurface_energy_drain(
        vsurface_config
    )
    if template_drain > TCCManager.get_max_template_drain() then
        local max_tier = TCCManager.get_max_template_tier()
        return false, {
            "vsurface-manager.template-tier-too-high",
            CommonGui.number_to_string(max_tier, 2)
        }
    end
    -- checking that computation amount is sufficient
    local computation_demand = VSurfaceManager.get_idle_computation_demand(vsurface_config)
    local available_computation = TCCManager.get_available_computation()
    if computation_demand > available_computation then
        return false, {"vsurface-manager.not-enough-computation"}
    end
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
---@return boolean status, LocalisedString|nil reason
function VSurfaceManager.create_vsurface(vsurface_config)
    -- checking that surface can be created
    local status, reason = VSurfaceManager.can_create_vsurface(vsurface_config)
    if not status then return status, reason end

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
    ---@type string assuming name was verified earlier
    local surface_name = vsurface_config.name
    local surface = game.create_surface(surface_name, mgs)
    -- making sure sufrace was created
    if not surface then
        -- TODO: log config?
        return false, {"vsurface-manager.creation-error"}
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
        name = surface_name,
        width = width,
        height = height,
        compiling = false,
        idle_demand = VSurfaceManager.get_idle_computation_demand(vsurface_config),
        compiling_demand = VSurfaceManager.get_compiling_computation_demand(vsurface_config),
        energy_drain = VSurfaceManager.get_vsurface_energy_drain(vsurface_config),
        compilation_venv = {input = {}, output = {}}
    }
    local vsurfaces = storage.vsurfaces
    table.insert(vsurfaces.array, vsurface_data)
    local lookup = vsurfaces.lookup
    lookup[surface_index] = vsurface_data
    lookup[surface_name] = vsurface_data

    -- adding surface to chunk registry for chunk processing
    ChunkProcessor.register_surface(surface)
    -- adding idle computation demand of created vsurface
    TCCManager.increase_computation_curr_demand(vsurface_data.idle_demand)
    return true
end

-------------------------------------------------------------------------------
------------------------------ VSURFACE DELETION ------------------------------
-------------------------------------------------------------------------------

---Deletes vsurface data from storage and decreases computation demand.
---COMPILING VSURFACE SHOULD NEVER BE DELETED.
---@param data_index integer position of vsurface data in the array
local function delete_vsurface_data(data_index)
    local vsurfaces = storage.vsurfaces
    ---@type VSurfaceData[]
    local array = vsurfaces.array
    ---@type table<integer, VSurfaceData>
    local lookup = vsurfaces.lookup
    local data = array[data_index]
    lookup[data.surface_index] = nil
    lookup[data.name] = nil
    table.remove(array, data_index)

    -- removing computation demand of deleted vsurface
    TCCManager.decrease_computation_curr_demand(data.idle_demand)
end

---Attempts to delete a vsurface provided its name
---@param surface_name string|nil name of the surface
---@return boolean status, LocalisedString|nil reason
function VSurfaceManager.delete_vsurface_by_name(surface_name)
    -- checking that surface name was provided
    if not surface_name then
        return false, {"vsurface-manager.deletion-error-no-name"}
    end
    -- looking through all vsurfaces to find its data
    local vsurfaces = storage.vsurfaces
    ---@type VSurfaceData[]
    local array = vsurfaces.array
    ---This approach is chosen to allow for deletion when surface 
    ---for some reason no longer exists in the game engine 
    local data_index
    for i, data in ipairs(array) do
        if data.name == surface_name then
            data_index = i
            break
        end
    end
    -- checking that vsurface data was found
    if not data_index then
        return false, {"vsurface-manager.deletion-error-no-data"}
    end
    local data = array[data_index]
    -- checking that surface is not currently compiling
    if data.compiling then
        return false, {"vsurface-manager.deletion-error-compiling"}
    end
    -- attempting to delete the surface from the game engine
    local surface_index = data.surface_index
    if game.get_surface(surface_index) and not game.delete_surface(surface_index) then
        -- surface exists in game but for some reason can't be deleted
        return false, {"vsurface-manager.deletion-error-protected"}
    end
    delete_vsurface_data(data_index)
    return true
end

---Deletes the most recently created vsurface. Intended to be used
---in computation deficit situation.
---@return boolean status true if vsurface was deleted
local function delete_newest_vsurface()
    local vsurfaces = storage.vsurfaces
    ---@type VSurfaceData[]
    local array = vsurfaces.array

    -- can't delete anything if array is empty
    local last_index = #array
    if last_index == 0 then return false end

    -- don't want to delete a surface if it's compiling
    -- it should be stopped elsewhere before deletion
    local data = array[last_index]
    if data.compiling then return false end

    -- attempting to delete the surface
    local surface_index = data.surface_index
    if not game.delete_surface(surface_index) then return false end
    -- removing vsurface data from storage
    delete_vsurface_data(last_index)

    -- vsurface deletion chat warning
    ---@diagnostic disable-next-line
    game.print({"vsurface-manager.critical-warn-vsurface-deleted", data.name})
    return true
end

-------------------------------------------------------------------------------
---------------------------- VSURFACE INFO GETTERS ----------------------------
-------------------------------------------------------------------------------

---Gets gets vsurface data by surface name
---@param surface_name string|nil
---@return VSurfaceData|nil
local function get_vsurface_data_by_name(surface_name)
    if not surface_name then return end
    return storage.vsurfaces.lookup[surface_name]
end

------------------------------- BY SURFACE NAME -------------------------------

---Checks if given surface is a vsurface and currently compiling
---@param surface_name string|nil name of the surface
---@return boolean status true if surface is found and compiling
function VSurfaceManager.is_compiling(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return false end
    return data.compiling
end

---Checks if given surface is a vsurface and currently idle
---@param surface_name string|nil name of the surface
---@return boolean status true if surface is found and idle
function VSurfaceManager.is_idle(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return false end
    return not data.compiling
end

---Gets width and height of a given vsurface
---@param surface_name string|nil
---@return integer width, integer height
function VSurfaceManager.get_vsurface_dimensions_by_name(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return 0, 0 end
    return data.width, data.height
end

---Gets status of a given vsurface
---@param surface_name string|nil
---@return LocalisedString status
function VSurfaceManager.get_vsurface_status_by_name(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return {"vsurface-manager.status-not-found"} end
    if data.compiling then return {"vsurface-manager.status-compiling"} end
    return {"vsurface-manager.status-idle"}
end

---Gets idle and compiling computation demands of given vsurface
---@param surface_name string|nil
---@return number idle_demand, number compiling_demand
function VSurfaceManager.get_computation_demands_by_name(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return 0, 0 end
    return data.idle_demand, data.compiling_demand
end

---Gets current computation demand of given vsurface
---@param surface_name string|nil
---@return number demand
function VSurfaceManager.get_current_computation_demand(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return 0 end
    local compiling = data.compiling
    return compiling and data.compiling_demand or data.idle_demand
end

---Gets template energy drain of given vsurface
---@param surface_name string|nil
---@return number energy_drain
function VSurfaceManager.get_energy_drain_by_name(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return 0 end
    return data.energy_drain
end

------------------------------ BY SURFACE INDEX -------------------------------

---Checks if surface with provided index is a vsurface
---@param surface_index number unique surface identifier
---@return boolean status true if vsurface data is found
function VSurfaceManager.is_vsurface(surface_index)
    return not not storage.vsurfaces.lookup[surface_index]
end

---------------------------- GENERAL GUI REQUESTS -----------------------------

---Gathers names of all idle vsurfaces in order of their creation
---@param query string|nil search query
---@return string[]
function VSurfaceManager.get_idle_vsurfaces(query)
    ---@type VSurfaceData[]
    local array = storage.vsurfaces.array
    local result = {}
    local has_query = query and string.find(query, "%S", 1, false)
    for _, data in ipairs(array) do
        -- colection names of vsurfaces that are not compiling
        if not data.compiling then
            local name = data.name
            -- collection vsurface names that match with query
            ---@diagnostic disable-next-line
            if not has_query or string.find(name, query, 1, true) then
                table.insert(result, data.name)
            end
        end
    end
    return result
end

---Gathers names of all compiling vsurfaces in chronological order.
---Older compilations first.
---@param query string|nil search query
---@return string[]
function VSurfaceManager.get_compiling_vsurfaces(query)
    local vsurfaces = storage.vsurfaces
    ---@type integer[] surface_indexes
    local queue = vsurfaces.compilation_queue
    ---@type table<integer, VSurfaceData>
    local lookup = vsurfaces.lookup
    local has_query = query and string.find(query, "%S", 1, false)
    local result = {}
    -- collecting names of vsurfaces from the compilation queue
    for _, surface_index in ipairs(queue) do
        local data = lookup[surface_index]
        if data then
            local name = data.name
            -- collecting vsurface names that match with query
            ---@diagnostic disable-next-line
            if not has_query or string.find(name, query, 1, true) then
                table.insert(result, data.name)
            end
        end
    end
    return result
end

-------------------------------------------------------------------------------
--------------------------- COMPILATION START/STOP ----------------------------
-------------------------------------------------------------------------------

---Base vsurface compilation time in ticks (10 minutes)
local BASE_COMPILATION_TIME = 36000

---Checks if compilation of a given surface can be started
---@param surface_name string|nil
---@param template_name string|nil unique template identifier
---@return boolean status, LocalisedString|nil reason
function VSurfaceManager.can_start_compilation(surface_name, template_name)
    -- checking that surface name is provided
    if not surface_name or not string.find(surface_name, "%S", 1, false) then
        return false, {"vsurface-manager.surface-name-missing"}
    end
    -- checking that template name is provided
    if not template_name or not string.find(template_name, "%S", 1, false) then
        return false, {"vsurface-manager.template-name-missing"}
    end
    -- checking that vsurface data exists in storage
    local vsurface_data = get_vsurface_data_by_name(surface_name)
    if not vsurface_data then
        return false, {"vsurface-manager.vsurface-no-data"}
    end
    -- checking that vsurface is not already compiling
    if vsurface_data.compiling then
        return false, {"vsurface-manager.vsurface-compiling"}
    end
    -- checking that computation is sufficient
    local computation_delta = vsurface_data.compiling_demand - vsurface_data.idle_demand
    local available_computation = TCCManager.get_available_computation()
    if computation_delta > available_computation then
        return false, {"vsurface-manager.not-enough-computation"}
    end
    return true
end

---Attempts to start a compilation of a given vsurface
---@param surface_name string|nil name of vsurface to compile
---@param template_name string|nil unique template identifier
---@return boolean status, LocalisedString|nil reason
function VSurfaceManager.start_compilation(surface_name, template_name)
    local status, reason = VSurfaceManager.can_start_compilation(surface_name, template_name)
    if not status then return false, reason end

    local vsurface_data = get_vsurface_data_by_name(surface_name)
    ---Vsurface data exists, template name valid (checked above)
    ---@cast vsurface_data VSurfaceData
    ---@cast template_name string

    -- configuring vsurface data
    local current_tick = game.tick
    vsurface_data.compilation_venv = {
        template_name = template_name,
        compilation_start = current_tick,
        compilation_stop = current_tick + BASE_COMPILATION_TIME,
        last_update = current_tick,
        input = {},
        output = {},
    }
    vsurface_data.compiling = true
    -- adding vsurface to compilation queue
    local surface_index = vsurface_data.surface_index
    local queue = storage.vsurfaces.compilation_queue
    table.insert(queue, surface_index)

    -- increasing compuatation demand of the surface
    local computation_delta = vsurface_data.compiling_demand - vsurface_data.idle_demand
    TCCManager.increase_computation_curr_demand(computation_delta)

    -- switching vsurface state in chunk registry
    ChunkProcessor.set_compiling_flag(surface_index, true)

    return true
end

---Used when compilation for a given surface needs to end for any reason.
---@param surface_index integer unique surface identifier
local function terminate_compilation(surface_index)
    local vsurfaces = storage.vsurfaces
    -- removing the surface from compilation queue
    local queue = vsurfaces.compilation_queue
    for i = 1, #queue do
        if queue[i] == surface_index then
            table.remove(queue, i)
            break
        end
    end
    ---Assuming data exists because otherwise, computation counts will
    ---get incorrect. In general, vsurface data MUST NOT be deleted
    ---if surface is compiling.
    ---@type VSurfaceData
    local data = vsurfaces.lookup[surface_index]
    data.compiling = false
    data.compilation_venv = {input = {}, output = {}}

    -- decreasing computation demand of this surface
    local computation_delta = data.compiling_demand - data.idle_demand
    TCCManager.decrease_computation_curr_demand(computation_delta)

    -- switching vsurface state in chunk registry
    ChunkProcessor.set_compiling_flag(surface_index, false)
end

---Attempts to stop compilation of a given vsurface (player request)
---@param surface_name string|nil name of vsurface
---@return boolean status, LocalisedString|nil reason why compilation was not stopped
function VSurfaceManager.stop_compilation(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    -- checking that vsurface data is found
    if not data then
        return false, {"vsurface-manager.termination-error-no-data"}
    end
    if not data.compiling then
        return false, {"vsurface-manager.termination-error-not-compiling"}
    end
    terminate_compilation(data.surface_index)
    return true
end

---Stops last compilation in queue (computation deficit)
---@return boolean status true if compilation was terminated
local function stop_newest_compilation()
    local vsurfaces = storage.vsurfaces
    local queue = vsurfaces.compilation_queue
    local queue_length = #queue
    if queue_length == 0 then return false end
    local surface_index = queue[queue_length]
    terminate_compilation(surface_index)

    ---@type VSurfaceData
    local data = vsurfaces.lookup[surface_index]

    -- compilation terminated chat warning
    ---@diagnostic disable-next-line
    game.print({"vsurface-manager.critical-warn-compilation-stopped", data.name})
    return true
end

-------------------------------------------------------------------------------
------------------------ VSURFACE ENVIRONMENT REQUESTS ------------------------
-------------------------------------------------------------------------------

------------------------------ BACKEND REQUESTS -------------------------------

---Adds given count to provided entry of vsurface environment input.
---@param surface_index integer unique surface identifier
---@param key BufferKeyString "steel-plate//normal", "water", "electric_energy"
---@param count number count to add
function VSurfaceManager.add_to_venv_input(surface_index, key, count)
    ---@type VSurfaceData
    local data = storage.vsurfaces.lookup[surface_index]
    if not data then return end
    local input = data.compilation_venv.input
    -- creating input entry if it does not exist
    if not input[key] then
        input[key] = 0
    end
    input[key] = input[key] + count
end

---Adds given count to provided entry of vsurface environment output.
---@param surface_index integer unique surface identifier
---@param key BufferKeyString "steel-plate//normal", "water", "electric_energy"
---@param count number count to add
function VSurfaceManager.add_to_venv_output(surface_index, key, count)
    ---@type VSurfaceData
    local data = storage.vsurfaces.lookup[surface_index]
    if not data then return end
    local output = data.compilation_venv.output
    -- creating output entry if it does not exist
    if not output[key] then
        output[key] = 0
    end
    output[key] = output[key] + count
end

--------------------------------- GUI REQUESTS ---------------------------------

---Gets template name from vsurface compilation venv
---@param surface_name string|nil
---@return string
function VSurfaceManager.get_template_name(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return "None" end
    local env = data.compilation_venv
    return env.template_name or "None"
end

---Gets compilation progress of given vsurface. If vsurface data is not
---found or compilation is not in progress, returns zeroes.
---@param surface_name string|nil
---@return number elapsed_time, number total_time
function VSurfaceManager.get_compilation_progress(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return 0, 0 end
    local env = data.compilation_venv
    local start_time = env.compilation_start or 0
    local end_time = env.compilation_stop or 0
    local last_update = env.last_update or 0
    local elapsed_time = last_update - start_time
    local total_time = end_time - start_time
    return elapsed_time, total_time
end

-------------------------------------------------------------------------------
------------------------------ TEMPLATE CREATION ------------------------------
-------------------------------------------------------------------------------

---Helps in vsurface building cost calculation. Adds item to total cost.
---@param total_cost table<BufferKeyString, number> building cost
---@param name string name of an item
---@param quality string quality of an item
---@param count number count of an item
local function add_to_cost(total_cost, name, quality, count)
    local key = name .. "//" .. quality
    total_cost[key] = (total_cost[key] or 0) + count
end

---Calculates total building cost of a vsurface.
---@param surface_index number unique surface identifier
---@return table<BufferKeyString, number> building_cost
local function get_vsurface_building_cost(surface_index)
    local surface = game.get_surface(surface_index)
    if not surface or not surface.valid then return {} end

    -- collecting building cost
    local total_cost = {}
    -- getting array[LuaEntity] containing all entities on given surface
    local entities = surface.find_entities_filtered({force = "player"})
    for _, entity in ipairs(entities) do
        -- counting only valid entities
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

---Helps in template creation. Calculates flow per second.
---@param counts table<BufferKeyString, number> total counts over a period of time
---@param time number total time in seconds (must be greater then 0)
---@return table<BufferKeyString, number> flow counts divided by time
local function calculate_flow(counts, time)
    local result = {}
    for key, count in pairs(counts) do
        result[key] = count/time
    end
    return result
end

---Creates a compiled template from vsurface environment data and saves it to storage.
---@param vsurface_data VSurfaceData
local function create_template(vsurface_data)
    local surface_index = vsurface_data.surface_index
    local venv = vsurface_data.compilation_venv
    -- calculating compilation time in seconds
    local compilation_time = (venv.compilation_stop - venv.compilation_start) / 60
    ---@type TemplateData
    local template = {
        input = calculate_flow(venv.input, compilation_time),
        output = calculate_flow(venv.output, compilation_time),
        building_cost = get_vsurface_building_cost(surface_index),
        energy_drain = vsurface_data.energy_drain,
    }
    TCCManager.add_template(template, venv.template_name)
end

-------------------------------------------------------------------------------
---------------------------- TIME-BASED PROCESSES -----------------------------
-------------------------------------------------------------------------------

---Checks for deficit in computation. It there is, takes action.
local function enforce_computation_limits()
    if TCCManager.is_computation_sufficient() then return end
    -- stopping newest vsurface compilation (1 per tick)
    local compilation_stopped = stop_newest_compilation()
    if compilation_stopped then return end
    -- deleting newest vsurface (1 per tick)
    delete_newest_vsurface()
end

---Does time-based compilation processing (1 compilation per tick)
local function process_compilations()
    local vsurfaces = storage.vsurfaces
    -- if compilation queue is empty, return
    local queue = vsurfaces.compilation_queue
    if #queue == 0 then return end

    -- getting index of the surface we want to update this tick
    local index = vsurfaces.next_compilation
    if not queue[index] then index = 1 end
    vsurfaces.next_compilation = index + 1
    local surface_index = queue[index]

    ---@type table<integer, VSurfaceData>
    local lookup = vsurfaces.lookup
    local data = lookup[surface_index]
    -- checking that data is present
    if not data then
        -- vsurface data was deleted, removing this compilation
        table.remove(queue, index)
        return
    end

    -- checking that surface still exists in game and is valid
    -- compilation can't be finished without valid surface
    local surface = game.get_surface(surface_index)
    if not surface or not surface.valid then
        -- surface was deleted, terminating compilation
        terminate_compilation(surface_index)
        return
    end

    -- everything is ok: normal compilation process
    local tick = game.tick
    local venv = data.compilation_venv
    if tick > venv.compilation_stop then
        -- compilation has finished, creating template
        create_template(data)
        terminate_compilation(surface_index)
        return
    end
    venv.last_update = tick
end

function VSurfaceManager.on_tick_updater()
    enforce_computation_limits()
    process_compilations()
end

return VSurfaceManager