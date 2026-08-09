--[[
Venv processor orchestrates compilation process of Vsurfaces. This processor handles
compilation requests (start/stop) and does tick-based processing of compiling venvs.
When a compilation successfully starts, "virtual environment" is created. It is tied 
to Vsurface on which the compilation is running. One vsurface can only host 1 compilation
at a time. All venvs are located at storage.venvs. Key for this table is surface index,
value is a table containing venv information. All venvs are processed at once every second.
--]]

---Table containing compilation environment data
---@class CompilationVEnv
---@field template_name string name of compiling template
---@field input table<BufferKeyString, number> accumulated compilation inputs
---@field output table<BufferKeyString, number> accumulated compilation outputs
---@field compilation_time number full compilation time in seconds
---@field remaining_time number remaining compilation time in seconds


local VSurfaceManager = require("src.world.vsurface-manager")
local TemplateCompiler = require("src.simulation.template-compiler")
local ChunkProcessor = require("src.world.vsurface-chunk-processor")

local VEnvProcessor = {}

local base_compilation_time = 200


---Adds given item/fluid/energy count to input/output.
---@param surface_index integer unique surface identifier
---@param key BufferKeyString item/fluid/energy identifier "steel-plate//normal", "water", "electric_energy"
---@param count integer count to add (function only does something when count > 0)
---@param is_output boolean|nil true to add to output, otherwise adds to input
function VEnvProcessor.add_io_count(surface_index, key, count, is_output)
    local venv = storage.venvs[surface_index]
    if not venv or not key or count <= 0 then return end
    local section = is_output and "output" or "input"
    venv[section][key] = (venv[section][key] or 0) + count
end

---Gets compilation progress of a given vsurface or nil if venv was not found.
---@param surface_id number|string|LuaSurface|nil surface identification
---@return number|nil elapsed_time, number|nil remaining_time
function VEnvProcessor.get_compilation_progress(surface_id)
    -- getting vsurface index
    local vsurface_data = VSurfaceManager.get_vsurface_data(surface_id)
    if not vsurface_data then return end

    local surface_index = vsurface_data.surface_index
    local venv = storage.venvs[surface_index]
    if not venv then return end

    local elapsed_time = venv.compilation_time - venv.remaining_time
    return elapsed_time, venv.remaining_time
end

---Checks if template with given name is already compiling
---@param template_name string unique template identifier
---@return boolean status true if template with provided name is compiling
local function template_name_compiling(template_name)
    for _, venv in pairs(storage.venvs) do
        if venv.template_name == template_name then return true end
    end
    return false
end

---Checks if compilation of a given surface can be started
---@param surface_id string|integer|LuaSurface|nil surface identification
---@param template_name string|nil unique template identifier
---@return boolean status true if compilation can be started
---@return string|nil reason why compilation can not be started if any
function VEnvProcessor.can_start_compilation(surface_id, template_name)
    -- checking that template name is provided
    local name = template_name
    if not name or not name:match("%S") then
        return false, "Template name is missing"
    end
    local trimmed_name = name:match("^%s*(.-)%s*$")
    -- checking that template name is not occupied in template storage
    if TemplateCompiler.get_template(trimmed_name) then
        return false, "Template with provided name already exists"
    end
    -- checking that template with provided name is not currently compiling
    if template_name_compiling(trimmed_name) then
        return false, "Template with provided name already compiling"
    end
    -- checking that surface is valid 
    if not VSurfaceManager.check_surface_validity(surface_id) then
        return false, "Vsurface is invalid"
    end
    -- checking that vsurface data exists in storage
    local vsurface_data = VSurfaceManager.get_vsurface_data(surface_id)
    if not vsurface_data then
        return false, "Vsurface data not found"
    end
    -- checking that surface is not already compiling
    if VEnvProcessor.get_compilation_progress(surface_id) then
        return false, "Surface is already compiling"
    end
    return true
end

---Attempts to starts a compilation of a given surface
---@param surface_id string|integer|LuaSurface|nil surface identification
---@param template_name string|nil unique template identifier
---@return boolean status true if compilation was successfully started
---@return string|nil reason why compilation was not started if any
function VEnvProcessor.start_compilation(surface_id, template_name)
    local status, reason = VEnvProcessor.can_start_compilation(surface_id, template_name)
    if not status then return false, reason end

    local vsurface_data = VSurfaceManager.get_vsurface_data(surface_id)
    -- vsurface data exists, template name valid (checked above)
    ---@cast vsurface_data table
    ---@cast template_name string

    local surface_index = vsurface_data.surface_index
    local trimmed_name = template_name:match("^%s*(.-)%s*$")

    -- creating venv for this compilation effectively starting it
    storage.venvs[surface_index] = {
        template_name = trimmed_name,
        input = {},
        output = {},
        compilation_time = base_compilation_time,
        remaining_time = base_compilation_time
    }

    -- switching vsurface state in chunk registry
    ChunkProcessor.set_compiling_flag(surface_index, true)

    return true
end

---Orders template creation and deletes assocciated venv.
---Called when compilation time runs out.
---@param surface_index integer unique surface identifier
local function stop_compilation(surface_index)
    local venv = storage.venvs[surface_index]
    TemplateCompiler.create_template(venv, surface_index)
    ChunkProcessor.set_compiling_flag(surface_index, false)
    storage.venvs[surface_index] = nil
end

---Stops compilation of a given surface in case surface
---without creating a template. Can be called when surface is no longer valid.
local function emergency_stop_compilation(surface_index)
    storage.venvs[surface_index] = nil
    ChunkProcessor.set_compiling_flag(surface_index, false)
end

---Time-based processor for all venvs. All venvs are processed at once.
---All venvs must be processed once every second.
function VEnvProcessor.process_compiling_surfaces()
    for surface_index, venv in pairs(storage.venvs) do
        -- we need to check that surface is still valid 
        -- otherwise terminate the compilation
        if VSurfaceManager.check_surface_validity(surface_index) then
            venv.remaining_time = venv.remaining_time - 1
            if venv.remaining_time == 0 then
                stop_compilation(surface_index)
            end
        else
            emergency_stop_compilation(surface_index)
        end
    end
end

return VEnvProcessor