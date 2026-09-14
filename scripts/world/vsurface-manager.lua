--[[
This mod allows players to create "virtualization surfaces".
They are basically sandboxes where player can build anything for free.
They are used in creationof templates. To create a template player has
to build a factory on a vsurface and then start compilation of that surface.
When compilation finishes successfully, template is created.

Computation is required to sustain existance of a virtualiation surface.
If there is a computation deficit, vsurfaces are deleted one by one until
there is no deficit. The same goes for compilation of vsurfaces,
which require significantly more computation.

Data for all vsurfaces is located at storage.vsurfaces: VSurfaceStorage

This file handles vsurface requests like:
1. create/delete/rename vsurface
2. start/stop vsurface compilation
3. add to compilation_venv input/output
4. get vsurface information requests
--]]

---Table containing user inputs necessery for creation of vsurface
---@class VSurfaceConfig
---@field name string|nil name of new vsurface
---@field width number|nil width of new vsurface
---@field height number|nil height of new vsurface
---@field generate_as string|nil name of planet which magpen should be used

---Contains validation report data of one item/fluid/energy
---@class ValidationEntry
---@field input number amount from input table
---@field produced number produced amount from statistics
---@field output number amount from output table
---@field consumed number consumed amount from statistics
---@field deviation_abs number absolute deviation of (inputs - outputs) from 0
---@field deviation_rel number relative deviation of (inputs - outputs) from 0
---@field acceptable boolean true if deviations are considered acceptable

---@class VSurfaceData
---@field surface_index integer unique surface identifier
---@field surface_name string internal (and display) name for the surface
---@field surface LuaSurface object corresponding to this surface
---@field width number width of the surface in tiles
---@field height number height of the surface in tiles
---@field compiling boolean true if surface is currently compiling
---@field idle_demand number computation required when idle
---@field compiling_demand number computation required when compiling
---@field energy_drain number template energy drain
---@field input table<BufferKeyString, number> accumulated vsurface inputs
---@field output table<BufferKeyString, number> accumulated vsurface outputs
---@field item_stat LuaFlowStatistics item production stat for surface
---@field fluid_stat LuaFlowStatistics fluid production stat for surface
---@field validation_report table<BufferKeyString, ValidationEntry>
---@field template_name string|nil name of compiling template
---@field compilation_start integer|nil tick at which compilation was started
---@field compilation_stop integer|nil tick at which compilation should end
---@field last_update integer|nil tick at which compilation was last updated
---@field last_validation integer|nil tick of last compilation validation

---@class VSurfaceStorage
---@field array VSurfaceData[] contains surfaces in order of creation
---@field lookup_by_index table<integer, VSurfaceData> key is surface_index
---@field lookup_by_name table<string, VSurfaceData> key is surface name
---@field compilation_queue VSurfaceData[] contains compiling vsurfaces in
---order their compilation was started
---@field next_compilation integer points to next index to be updated
---in compilation queue


local ChunkProcessor = require("scripts.world.vsurface-chunk-processor")
local TCCManager = require("scripts.simulation.tcc-manager")
local CommonGui = require("scripts.gui.common")

local PREFIX = "FV-"
local VSurfaceManager = {}

---Vsurface compilation time in ticks (10 minutes)
local COMPILATION_TIME = 36000
---Time between compilation validation report updates (5 seconds)
local VALIDATION_INTERVAL = 300

---Gets vsurface data by surface name
---@param surface_name string|nil
---@return VSurfaceData|nil
local function get_vsurface_data_by_name(surface_name)
    if not surface_name then return end
    return storage.vsurfaces.lookup_by_name[surface_name]
end

-------------------------------------------------------------------------------
---------------------------- CREATE DELETE RENAME -----------------------------
-------------------------------------------------------------------------------

------------------------------ VSURFACE CREATION ------------------------------

---Calculates idle computation demand for a vsurface given its config
---@param vsurface_config VSurfaceConfig
function VSurfaceManager.get_idle_computation_demand(vsurface_config)
    return VSurfaceManager.get_compiling_computation_demand(
        vsurface_config
    ) / 10
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
        return false, {"vsurface-manager.name-missing"}
    end
    -- checking that no surface or planet is associated with provided name
    if game.get_surface(name) ~= nil or game.planets[name] ~= nil then
        return false, {"vsurface-manager.name-unavailable"}
    end
    -- validating surface width
    local width = vsurface_config.width
    if not width or type(width) ~= "number" or width < 1 or width > 1024 then
        return false, {"vsurface-manager.width-incorrect"}
    end
    -- validating surface height
    local height = vsurface_config.height
    if not height or type(height) ~= "number" or height < 1 or height > 1024 then
        return false, {"vsurface-manager.height-incorrect"}
    end
    -- checking that TCC max template drain is sufficient
    local template_drain = VSurfaceManager.get_vsurface_energy_drain(
        vsurface_config
    )
    if template_drain > TCCManager.get_max_template_drain() then
        local max_tier = TCCManager.get_max_template_tier()
        return false, {
            "vsurface-manager.tier-too-high",
            CommonGui.number_to_string(max_tier, 2)
        }
    end
    -- checking that computation amount is sufficient
    local computation_demand = VSurfaceManager.get_idle_computation_demand(
        vsurface_config
    )
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

    ---@type number checked above
    local width = vsurface_config.width
    ---@type number checked above
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
        return false, {"vsurface-manager.creation-error"}
    end

    -- modifying surface attributes
    surface.always_day = true
    surface.ignore_surface_conditions = true
    if not planet_generation then
        surface.generate_with_lab_tiles = true
    end

    -- generating vsurface chunks
    local chunk_radius = math.ceil(math.max(width, height) / 64)
    surface.request_to_generate_chunks({0, 0}, chunk_radius)

    -- adding vsurface data to storage
    ---@type LuaForce
    local player_force = game.forces["player"]
    local surface_index = surface.index
    ---@type VSurfaceData
    local vsurface_data = {
        surface_index = surface_index,
        surface_name = surface_name,
        surface = surface,
        width = width,
        height = height,
        compiling = false,
        idle_demand = VSurfaceManager.get_idle_computation_demand(
            vsurface_config
        ),
        compiling_demand = VSurfaceManager.get_compiling_computation_demand(
            vsurface_config
        ),
        energy_drain = VSurfaceManager.get_vsurface_energy_drain(
            vsurface_config
        ),
        input = {},
        output = {},
        item_stat = player_force.get_item_production_statistics(surface),
        fluid_stat = player_force.get_fluid_production_statistics(surface),
        validation_report = {},
    }
    local vsurfaces = storage.vsurfaces
    table.insert(vsurfaces.array, vsurface_data)
    vsurfaces.lookup_by_index[surface_index] = vsurface_data
    vsurfaces.lookup_by_name[surface_name] = vsurface_data

    -- adding surface to chunk registry for chunk processing
    ChunkProcessor.register_surface(surface)
    -- adding idle computation demand of created vsurface
    TCCManager.increase_computation_curr_demand(vsurface_data.idle_demand)
    return true
end

------------------------------- VSURFACE RENAME -------------------------------

---Checks if given vsurface can be renamed
---@param old_name string|nil current vsurface name
---@param new_name string|nil new vsurface name
---@return boolean status true if vsurface can be renamed
---@return LocalisedString|nil reason why vsurface cannot be renamed
function VSurfaceManager.can_rename_vsurface(old_name, new_name)
    -- checking that old name is provided
    if not old_name then
        return false, {"vsurface-manager.old-name-missing"}
    end
    -- checking that new name is not empty
    if not new_name or not string.find(new_name, "%S", 1, false) then
        return false, {"vsurface-manager.new-name-empty"}
    end
    -- checking that names are different
    if new_name == old_name then
        return false, {"vsurface-manager.names-not-different"}
    end
    -- checking that new name is not occupied
    if game.get_surface(new_name) ~= nil or game.planets[new_name] ~= nil then
        return false, {"vsurface-manager.new-name-unavailable"}
    end
    -- checking that vsurface data exists in storage
    local vsurface_data = storage.vsurfaces.lookup_by_name[old_name]
    if not vsurface_data then
        return false, {"vsurface-manager.old-name-no-data"}
    end
    -- checking that LuaSurface is valid
    if not vsurface_data.surface.valid then
        return false, {"vsurface-manager.vsurface-invalid"}
    end
    return true
end

---Attempts to rename given vsurface
---@param old_name string|nil current vsurface name
---@param new_name string|nil new vsurface name
---@return boolean status true if vsurface can be renamed
---@return LocalisedString|nil reason why vsurface cannot be renamed
function VSurfaceManager.rename_vsurface(old_name, new_name)
    local status, reason = VSurfaceManager.can_rename_vsurface(
        old_name,
        new_name
    )
    if not status then return status, reason end
    ---@cast old_name string
    ---@cast new_name string

    -- Everything ok: renaming given vsurface
    local vsurfaces = storage.vsurfaces
    local lookup_by_name = vsurfaces.lookup_by_name
    local vsurface_data = lookup_by_name[old_name]
    vsurface_data.surface.name = new_name
    vsurface_data.surface_name = new_name
    lookup_by_name[old_name] = nil
    lookup_by_name[new_name] = vsurface_data
    return true
end

------------------------------ VSURFACE DELETION ------------------------------

---Deletes vsurface data from storage. Should only be used on idle vsurfaces.
---@param vsurface_data VSurfaceData
local function delete_vsurface_data(vsurface_data)
    local vsurfaces = storage.vsurfaces
    -- Removing data from the array
    local array = vsurfaces.array
    for i, data in ipairs(array) do
        if data == vsurface_data then
            table.remove(array, i)
            break
        end
    end
    -- removing data from index lookup by index
    local surface_index = vsurface_data.surface_index
    vsurfaces.lookup_by_index[surface_index] = nil
    -- removing data from lookup by name
    local surface_name = vsurface_data.surface_name
    vsurfaces.lookup_by_name[surface_name] = nil

    -- removing computation demand of deleted vsurface
    TCCManager.decrease_computation_curr_demand(vsurface_data.idle_demand)
end

---Attempts to delete a vsurface provided its name
---@param surface_name string|nil name of the surface
---@return boolean status, LocalisedString|nil reason
function VSurfaceManager.delete_vsurface_by_name(surface_name)
    -- checking that surface name was provided
    if not surface_name then
        return false, {"vsurface-manager.deletion-error-no-name"}
    end
    -- checking that vsurface data is present in storage
    local vsurface_data = storage.vsurfaces.lookup_by_name[surface_name]
    if not vsurface_data then
        return false, {"vsurface-manager.deletion-error-no-data"}
    end
    -- checking that surface is not currently compiling
    if vsurface_data.compiling then
        return false, {"vsurface-manager.deletion-error-compiling"}
    end
    -- attempting to delete the surface from the game engine
    local surface_index = vsurface_data.surface_index
    if game.get_surface(surface_index) and not game.delete_surface(surface_index) then
        -- surface exists in game but for some reason can't be deleted
        return false, {"vsurface-manager.deletion-error-protected"}
    end
    delete_vsurface_data(vsurface_data)
    return true
end

---Deletes the most recently created vsurface. Intended to be used
---in computation deficit situation.
---@return boolean status true if vsurface was deleted
local function delete_newest_vsurface()
    local array = storage.vsurfaces.array
    local vsurface_data = array[#array]
    -- can't delete anything if array is empty
    if not vsurface_data then return false end

    -- don't want to delete a surface if it's compiling
    -- it should be stopped elsewhere before deletion
    if vsurface_data.compiling then return false end

    -- attempting to delete the surface
    local surface_index = vsurface_data.surface_index
    if not game.delete_surface(surface_index) then return false end

    -- removing vsurface data from storage
    delete_vsurface_data(vsurface_data)

    -- vsurface deletion chat warning
    local print_msg = {
        "vsurface-manager.critical-warn-vsurface-deleted",
        vsurface_data.surface_name
    }
    game.print(print_msg)
    return true
end

-------------------------------------------------------------------------------
--------------------------- COMPILATION START/STOP ----------------------------
-------------------------------------------------------------------------------

---Checks if compilation of a given surface can be started
---@param surface_name string|nil
---@param template_name string|nil unique template identifier
---@return boolean status, LocalisedString|nil reason
function VSurfaceManager.can_start_compilation(surface_name, template_name)
    -- checking that surface name is provided
    if not surface_name or not string.find(surface_name, "%S", 1, false) then
        return false, {"vsurface-manager.target-vsurface-missing"}
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
    -- checking that vsurface is valid
    if not vsurface_data.surface.valid then
        return false, {"vsurface-manager.vsurface-invalid"}
    end
    -- checking that computation is sufficient
    local comp_delta = vsurface_data.compiling_demand - vsurface_data.idle_demand
    local available_computation = TCCManager.get_available_computation()
    if comp_delta > available_computation then
        return false, {"vsurface-manager.not-enough-computation"}
    end
    return true
end

---Attempts to start a compilation of a given vsurface
---@param surface_name string|nil name of vsurface to compile
---@param template_name string|nil unique template identifier
---@return boolean status, LocalisedString|nil reason
function VSurfaceManager.start_compilation(surface_name, template_name)
    local status, reason = VSurfaceManager.can_start_compilation(
        surface_name,
        template_name
    )
    if not status then return false, reason end

    local vsurface_data = get_vsurface_data_by_name(surface_name)
    ---Vsurface data exists, template name valid (checked above)
    ---@cast vsurface_data VSurfaceData
    ---@cast template_name string

    -- updating vsurface data before compilation start
    vsurface_data.compiling = true
    vsurface_data.input = {}
    vsurface_data.output = {}
    vsurface_data.validation_report = {}
    vsurface_data.template_name = template_name
    local current_tick = game.tick
    vsurface_data.compilation_start = current_tick
    vsurface_data.compilation_stop = current_tick + COMPILATION_TIME
    vsurface_data.last_update = current_tick
    vsurface_data.last_validation = current_tick
    -- clearing statistics (surface validity checked above)
    vsurface_data.item_stat.clear()
    vsurface_data.fluid_stat.clear()

    -- adding vsurface to compilation queue
    local queue = storage.vsurfaces.compilation_queue
    table.insert(queue, vsurface_data)

    -- increasing computation demand of this vsurface
    local comp_delta = vsurface_data.compiling_demand - vsurface_data.idle_demand
    TCCManager.increase_computation_curr_demand(comp_delta)

    -- switching vsurface state in chunk registry
    ChunkProcessor.set_compiling_flag(vsurface_data.surface_index, true)

    return true
end

---Used when compilation for a given surface needs to end for any reason
---@param vsurface_data VSurfaceData
local function terminate_compilation(vsurface_data)
    local vsurfaces = storage.vsurfaces
    -- removing the vsurface from compilation queue
    local queue = vsurfaces.compilation_queue
    for i, data in ipairs(queue) do
        if data == vsurface_data then
            table.remove(queue, i)
            break
        end
    end
    -- updating vsurface data table
    vsurface_data.compiling = false
    vsurface_data.template_name = nil
    vsurface_data.compilation_start = nil
    vsurface_data.compilation_stop = nil
    vsurface_data.last_update = nil
    vsurface_data.last_validation = nil

    -- decreasing computation demand of this surface
    local comp_delta = vsurface_data.compiling_demand - vsurface_data.idle_demand
    TCCManager.decrease_computation_curr_demand(comp_delta)

    -- switching vsurface state in chunk registry
    ChunkProcessor.set_compiling_flag(vsurface_data.surface_index, false)
end

---Attempts to stop compilation of a given vsurface (player request)
---@param surface_name string|nil name of vsurface
---@return boolean status true if compulation was stopped
---@return LocalisedString|nil reason why compilation was not stopped
function VSurfaceManager.stop_compilation(surface_name)
    local vsurface_data = get_vsurface_data_by_name(surface_name)
    -- checking that vsurface data is found
    if not vsurface_data then
        return false, {"vsurface-manager.termination-error-no-data"}
    end
    if not vsurface_data.compiling then
        return false, {"vsurface-manager.termination-error-not-compiling"}
    end
    terminate_compilation(vsurface_data)
    return true
end

---Stops last compilation in queue (computation deficit)
---@return boolean status true if compilation was terminated
local function stop_newest_compilation()
    local queue = storage.vsurfaces.compilation_queue
    local vsurface_data = queue[#queue]
    -- compilation queue is empty: nothing to stop
    if not vsurface_data then return false end
    terminate_compilation(vsurface_data)

    -- compilation terminated chat warning
    local warning_msg = {
        "vsurface-manager.critical-warn-compilation-stopped",
        vsurface_data.surface_name
    }
    game.print(warning_msg)
    return true
end

-------------------------------------------------------------------------------
---------------------------- VSURFACE INFO GETTERS ----------------------------
-------------------------------------------------------------------------------

------------------------------- BY SURFACE NAME -------------------------------

---Checks if given vsurface exists
---@param surface_name string|nil
---@return boolean true if vsurface exists
function VSurfaceManager.does_vsurface_exist(surface_name)
    return not not get_vsurface_data_by_name(surface_name)
end

---Gets width and height of a given vsurface
---@param surface_name string|nil
---@return integer width, integer height
function VSurfaceManager.get_vsurface_dimensions(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return 0, 0 end
    return data.width, data.height
end

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

---Gets status of a given vsurface
---@param surface_name string|nil
---@return LocalisedString status
function VSurfaceManager.get_vsurface_status(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return {"vsurface-manager.status-not-found"} end
    if data.compiling then return {"vsurface-manager.status-compiling"} end
    return {"vsurface-manager.status-idle"}
end

---Gets idle and compiling computation demands of given vsurface
---@param surface_name string|nil
---@return number idle_demand, number compiling_demand
function VSurfaceManager.get_computation_demands(surface_name)
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

---Gets complexity tier of given vsurface
---@param surface_name string|nil
function VSurfaceManager.get_vsurface_tier(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return -1 end
    local energy_drain = data.energy_drain
    return TCCManager.get_template_tier(energy_drain)
end

---@param surface_name string|nil display name of surface
---@return integer|nil surface_index
---@return number|nil pos_x
---@return number|nil pos_y
function VSurfaceManager.get_vsurface_position(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return end
    return data.surface_index, 0, 0
end

---@param surface_name string|nil display name of surface
---@return table<BufferKeyString, number> input
---@return table<BufferKeyString, number> output
function VSurfaceManager.get_vsurface_io_tables(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return {}, {} end
    return data.input, data.output
end

---@param surface_name string|nil display name of surface
---@return table<BufferKeyString, ValidationEntry>
function VSurfaceManager.get_validation_report(surface_name)
    local data = get_vsurface_data_by_name(surface_name)
    if not data then return {} end
    return data.validation_report
end

---Gets template name that is currently compiling
---@param surface_name string|nil
---@return string
function VSurfaceManager.get_template_name(surface_name)
    local vsurface_data = get_vsurface_data_by_name(surface_name)
    if not vsurface_data then return "—" end
    return vsurface_data.template_name or "—"
end

---Gets compilation progress of given vsurface. If vsurface data is not
---found or compilation is not in progress, returns zeroes.
---@param surface_name string|nil
---@return number elapsed_time, number total_time
function VSurfaceManager.get_compilation_progress(surface_name)
    local vsurface_data = get_vsurface_data_by_name(surface_name)
    if not vsurface_data then return 0, 0 end
    local start_time = vsurface_data.compilation_start or 0
    local end_time = vsurface_data.compilation_stop or 0
    local last_update = vsurface_data.last_update or 0
    local elapsed_time = last_update - start_time
    local total_time = end_time - start_time
    return elapsed_time, total_time
end

------------------------------ BY SURFACE INDEX -------------------------------

---Checks if surface with provided index is a vsurface
---@param surface_index number unique surface identifier
---@return boolean status true if vsurface data is found
function VSurfaceManager.is_vsurface(surface_index)
    return not not storage.vsurfaces.lookup_by_index[surface_index]
end

------------------------------ GENERAL REQUESTS ------------------------------

---Gathers names of all idle vsurfaces in order of their creation
---@param query string|nil search query
---@return string[]
function VSurfaceManager.get_idle_vsurfaces(query)
    local array = storage.vsurfaces.array
    local has_query = query and string.find(query, "%S", 1, false)

    local result = {}
    for _, vsurface_data in ipairs(array) do
        -- colection names of vsurfaces that are not compiling
        if not vsurface_data.compiling then
            local name = vsurface_data.surface_name
            -- collection vsurface names that match with query
            ---@diagnostic disable-next-line
            if not has_query or string.find(name, query, 1, true) then
                table.insert(result, name)
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
    local queue = storage.vsurfaces.compilation_queue
    local has_query = query and string.find(query, "%S", 1, false)

    local result = {}
    -- collecting names of vsurfaces from the compilation queue
    for _, vsurface_data in ipairs(queue) do
        local name = vsurface_data.surface_name
        -- collecting vsurface names that match with query
        ---@diagnostic disable-next-line
        if not has_query or string.find(name, query, 1, true) then
            table.insert(result, name)
        end
    end
    return result
end

-------------------------------------------------------------------------------
---------------------------- VSURFACE IO REQUESTS -----------------------------
-------------------------------------------------------------------------------

---Adds given count to provided entry of vsurface environment input.
---@param surface_index integer unique surface identifier
---@param key BufferKeyString "steel-plate//normal", "water", "electric_energy"
---@param count number count to add
function VSurfaceManager.add_to_vsurface_input(surface_index, key, count)
    local data = storage.vsurfaces.lookup_by_index[surface_index]
    if not data then return end
    local input = data.input
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
function VSurfaceManager.add_to_vsurface_output(surface_index, key, count)
    local data = storage.vsurfaces.lookup_by_index[surface_index]
    if not data then return end
    local output = data.output
    -- creating output entry if it does not exist
    if not output[key] then
        output[key] = 0
    end
    output[key] = output[key] + count
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
    local key = string.format("%s//%s", name, quality)
    total_cost[key] = (total_cost[key] or 0) + count
end

---Calculates total building cost of a vsurface.
---Counts tiles, buildings and modules.
---@param surface LuaSurface assumed to be valid
---@return table<BufferKeyString, number> building_cost
local function get_vsurface_building_cost(surface)
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
        result[key] = count / time
    end
    return result
end

---Creates a template from vsurface compilation data.
---Assuming surface is valid (checked in on_tick updater)
---@param vsurface_data VSurfaceData
local function create_template(vsurface_data)
    local start = vsurface_data.compilation_start
    local stop = vsurface_data.compilation_stop
    -- compilation time in seconds
    local time = (stop - start) / 60
    ---@type TemplateData
    local template = {
        input = calculate_flow(vsurface_data.input, time),
        output = calculate_flow(vsurface_data.output, time),
        building_cost = get_vsurface_building_cost(vsurface_data.surface),
        energy_drain = vsurface_data.energy_drain,
    }
    TCCManager.add_template(template, vsurface_data.template_name)
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

---Gets (creates if necessery) validation report entry by key
---@param validation_report table<BufferKeyString, ValidationEntry>
---@param key BufferKeyString
---@return ValidationEntry entry 
local function get_validation_report_entry(validation_report, key)
    local entry = validation_report[key]
    if entry then return entry end
    entry = {
        input = 0,
        produced = 0,
        output = 0,
        consumed = 0,
        deviation_abs = 0,
        deviation_rel = 0,
        acceptable = true,
    }
    validation_report[key] = entry
    return entry
end

---Updates validation report of an ongoing compilation.
---Assuming surface and all LuaStatistics are valid.
---@param vsurface_data VSurfaceData
local function update_validation_report(vsurface_data)
    local report = vsurface_data.validation_report
    local entry

    -- Collecting data from "input" table
    for key, count in pairs(vsurface_data.input) do
        entry = get_validation_report_entry(report, key)
        entry.input = count
    end

    -- Collecting data from "output" table
    for key, count in pairs(vsurface_data.output) do
        entry = get_validation_report_entry(report, key)
        entry.output = count
    end
    -- energy is not validated (no need)
    report.electric_energy = nil

    -- Collecting data from item production statistics
    local item_stat = vsurface_data.item_stat
    for quality, counts in pairs(item_stat.input_quality_counts) do
        for name, amount in pairs(counts) do
            entry = get_validation_report_entry(
                report,
                string.format("%s//%s", name, quality)
            )
            entry.produced = amount
        end
    end
    for quality, counts in pairs(item_stat.output_quality_counts) do
        for name, amount in pairs(counts) do
            entry = get_validation_report_entry(
                report,
                string.format("%s//%s", name, quality)
            )
            entry.consumed = amount
        end
    end

    -- Collecting data from fluid production statistics
    local fluid_stat = vsurface_data.fluid_stat
    for name, amount in pairs(fluid_stat.input_counts) do
        entry = get_validation_report_entry(report, name)
        entry.produced = amount
    end
    for name, amount in pairs(fluid_stat.output_counts) do
        entry = get_validation_report_entry(report, name)
        entry.consumed = amount
    end

    -- Running validation
    for _, report_entry in pairs(report) do
        local in_sum = report_entry.input + report_entry.produced
        local out_sum = report_entry.output + report_entry.consumed
        local deviation_abs = math.abs(in_sum - out_sum)
        local base = (in_sum + out_sum) / 2
        local deviation_rel = (base ~= 0) and deviation_abs / base or 0
        report_entry.deviation_abs = deviation_abs
        report_entry.deviation_rel = deviation_rel
        report_entry.acceptable = deviation_rel < 0.01
    end
end

---Does time-based compilation processing (1 compilation per tick)
local function process_compilations()
    local vsurfaces = storage.vsurfaces
    -- if compilation queue is empty, return
    local queue = vsurfaces.compilation_queue
    if #queue == 0 then return end

    -- Getting index of compilation to be updated this tick
    local index = vsurfaces.next_compilation
    if not queue[index] then index = 1 end
    vsurfaces.next_compilation = index + 1
    local vsurface_data = queue[index]

    -- Checking that vsurface is valid
    if not vsurface_data.surface.valid then
        -- termination compilation and clearing data from the structure
        terminate_compilation(vsurface_data)
        delete_vsurface_data(vsurface_data)
        return
    end

    -- Ending the compilation when time runs out
    local tick = game.tick
    if tick > vsurface_data.compilation_stop then
        update_validation_report(vsurface_data)
        -- checking that all report deviations are acceptable
        local compilation_valid = true
        for _, entry in pairs(vsurface_data.validation_report) do
            if not entry.acceptable then
                compilation_valid = false
                break
            end
        end
        if compilation_valid then
            -- compilation successfully finished
            local msg = {
                "vsurface-manager.template-compiled",
                vsurface_data.template_name
            }
            game.print(msg)
            create_template(vsurface_data)
            game.forces["player"].script_trigger_research(
                PREFIX .. "compile-any-template"
            )
            terminate_compilation(vsurface_data)
        else
            -- compilation failed
            local msg = {
                "vsurface-manager.template-not-compiled",
                vsurface_data.template_name
            }
            game.print(msg)
            terminate_compilation(vsurface_data)
        end
        return
    end

    -- Updating validation report when necessery
    if tick - vsurface_data.last_validation >= VALIDATION_INTERVAL then
        update_validation_report(vsurface_data)
    end

    vsurface_data.last_update = tick
end

function VSurfaceManager.on_tick_updater()
    enforce_computation_limits()
    process_compilations()
end

-------------------------------------------------------------------------------
------------------------------- DATA LIFECYCLE --------------------------------
-------------------------------------------------------------------------------

function VSurfaceManager.on_configuration_changed()
    -- TODO: 
end


return VSurfaceManager