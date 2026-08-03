--[[
Template energy IOs are used in creation of templates on virtualization surfaces.
They serve as inputs and outputs of energy.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. IO mode. Used to determine the entity operation.
II. Entity is located on a vsurface.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. Is output. Used to determine entity operation
2. Buffer key. Used to make calls to venv processor
3. Flow limit. Used to make calls to factorio API

Properties that can be assigned during on-tick processing:
1. Ls flow. Can be used to track entity work.
--]]

local VEnvProcessor = require("src.simulation.venv-processor")
local VSurfaceManager = require("src.world.vsurface-manager")


local PREFIX = "FV-"
local TemplateEnergyIO = {}

---List of all copyable properties of this entity
TemplateEnergyIO.copyable = {
    "io_mode",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "template-energy-io-mk1"] = 1e8,
    [PREFIX .. "template-energy-io-mk2"] = 1e9,
    [PREFIX .. "template-energy-io-mk3"] = 1e10,
}

---Checks that all requirements for operation of template energy IO are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function TemplateEnergyIO.attempt_entity_initialization(properties)
    -- 1. IO mode is selected
    local io_mode = properties.io_mode
    if not io_mode then return false end
    -- 2. Entity is located on a vsurface
    local entity = properties.entity
    if not VSurfaceManager.get_vsurface_data(entity.surface_index) then return false end

    ---All requirements are met. Preparing properties for on-tick processing
    properties.buffer_key = "electric_energy"
    properties.is_output = (io_mode == "output")
    properties.flow_limit = flow_limits[properties.entity_name]
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function TemplateEnergyIO.on_processing_stopped(properties)
    properties.ls_flow = nil
    properties.flow_limit = nil
    properties.is_output = nil
    properties.buffer_key = nil
end

---Used for on-tick processing of template energy IOs.
---@param properties EntityProperties
function TemplateEnergyIO.process_entity(properties)
    local delta = 0
    local entity = properties.entity
    local current_energy = entity.energy
    local flow_limit = properties.flow_limit
    if properties.is_output then
        delta = math.min(current_energy, flow_limit)
        entity.energy = current_energy - delta
    else
        delta = math.min(
            entity.electric_buffer_size - current_energy,
            flow_limit
        )
        entity.energy = current_energy + delta
    end
    properties.ls_flow = delta

    ---Storing delta in venv if surface is compiling
    VEnvProcessor.add_io_count(
        properties.entity.surface_index,
        properties.buffer_key,
        delta,
        properties.is_output
    )
end

return TemplateEnergyIO