--[[
Template fluid IOs are used in creation of templates on virtualization surfaces.
They serve as inputs and outputs of fluids.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. IO mode. Used to determine the entity operation.
    2. Selected fluid. Used to determine the buffer key.
II. Entity is located on a vsurface.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. Is output. Used to determine entity operation
2. Flow limit. Used to make calls to factorio API.
3. IO request. Used to make calls to factorio API.

Properties that can be assigned during on-tick processing:
1. Ls flow. Can be used to track entity work.
--]]

local VEnvProcessor = require("src.simulation.venv-processor")
local VSurfaceManager = require("src.world.vsurface-manager")


local PREFIX = "FV-"
local TemplateFluidIO = {}

---List of all copyable properties of this entity
TemplateFluidIO.copyable = {
    "io_mode",
    "selected_fluid",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "template-fluid-io-mk1"] = 500,
    [PREFIX .. "template-fluid-io-mk2"] = 5000,
    [PREFIX .. "template-fluid-io-mk3"] = 50000,
}

---Checks that all requirements for operation of template fluid IO are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function TemplateFluidIO.attempt_entity_initialization(properties)
    -- 1. IO mode is selected
    local io_mode = properties.io_mode
    if not io_mode then return false end
    -- 2. Fluid is selected
    local selected_fluid = properties.selected_fluid
    if not selected_fluid then return false end
    -- 3. Entity is located on a vsurface
    local entity = properties.entity
    if not VSurfaceManager.get_vsurface_data(entity.surface_index) then return false end

    ---All requirements are met. Preparing properties for on-tick processing
    -- assigning io mode flag to entity
    properties.is_output = (io_mode == "output")
    -- caching flow limit of the entity to selected fluid table
    local flow_limit = flow_limits[properties.entity_name]
    properties.flow_limit = flow_limit
    properties.io_request = {name = selected_fluid, amount = flow_limit}
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function TemplateFluidIO.on_processing_stopped(properties)
    properties.ls_flow = nil
    properties.is_output = nil
    properties.io_request = nil
    properties.flow_limit = nil
end

---Used for on-tick processing of template fluid IOs.
---@param properties EntityProperties
function TemplateFluidIO.process_entity(properties)
    local delta = 0
    -- removing or inserting fluid
    if properties.is_output then
        ---@diagnostic disable-next-line
        delta = properties.entity.extract_fluid(properties.io_request)
    else
        ---@diagnostic disable-next-line
        delta = properties.entity.insert_fluid(properties.io_request)
    end
    properties.ls_flow = delta

    ---Storing delta in venv if surface is compiling
    VEnvProcessor.add_io_count(
        properties.entity.surface_index,
        properties.selected_fluid,
        delta,
        properties.is_output
    )
end

return TemplateFluidIO