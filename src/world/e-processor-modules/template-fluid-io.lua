--[[
Template fluid IOs are used in creation of templates on virtualization surfaces.
They serve as inputs and outputs for fluids.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Mandatory entity configuration is provided:
    1. io_mode. Used to determine the entity operation.
    2. selected_fluid. Used to determine the buffer key.
II. Entity is located on a vsurface.

Optional entity controls this building can have:
1. capability_override. Used to artificially lower flow limit of this entity.

Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. is_output. Used to determine entity operation
3. buffer_key. Used to make calls to venv processor
4. flow_limit. maximum flow rate for this entity
5. io_request. Used to make calls to factorio API
6. surface_index. Used to make calls to venv processor
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick processing:
1. ls_flow. Can be used to track entity work.
--]]

local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local TemplateFluidIO = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
TemplateFluidIO.configuration = {
    "io_mode",
    "selected_fluid",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "template-fluid-io-mk1"] = 1200,
    [PREFIX .. "template-fluid-io-mk2"] = 12000,
    [PREFIX .. "template-fluid-io-mk3"] = 120000,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function TemplateFluidIO.initialize(properties)
    -- Checking that io mode is selected
    local io_mode = properties.io_mode
    if not io_mode then
        properties.status = Utilities.entity_status.no_io_mode
        return Utilities.registry_sections.incorrect
    end
    -- Checking that fluid is selected
    local selected_fluid = properties.selected_fluid
    if not selected_fluid then
        properties.status = Utilities.entity_status.no_selected_fluid
        return Utilities.registry_sections.incorrect
    end
    -- Checking that entity is located on a virtualization surface
    local entity = properties.entity
    if not VSurfaceManager.is_vsurface(entity.surface_index) then
        properties.status = Utilities.entity_status.vsurface_only_work
        return Utilities.registry_sections.incorrect
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    properties.is_output = (io_mode == "output")
    properties.buffer_key = selected_fluid
    local base_flow = flow_limits[properties.entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    local override = properties.capability_override or 1
    local flow_limit = base_flow * quality_mult * override
    properties.flow_limit = flow_limit
    properties.io_request = {name = selected_fluid, amount = flow_limit}
    properties.surface_index = entity.surface_index
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function TemplateFluidIO.uninitialize(properties)
    properties.is_output = nil
    properties.buffer_key = nil
    properties.flow_limit = nil
    properties.io_request = nil
    properties.surface_index = nil
    properties.ls_flow = nil
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function TemplateFluidIO.update(properties)
    local delta = 0
    -- removing or inserting fluid
    if properties.is_output then
        ---@diagnostic disable-next-line
        delta = properties.entity.extract_fluid(properties.io_request)
        if delta > 0 then
            VSurfaceManager.add_to_venv_output(
                properties.surface_index,
                properties.buffer_key,
                delta
            )
        end
    else
        ---@diagnostic disable-next-line
        delta = properties.entity.insert_fluid(properties.io_request)
        if delta > 0 then
            VSurfaceManager.add_to_venv_input(
                properties.surface_index,
                properties.buffer_key,
                delta
            )
        end
    end
    properties.ls_flow = delta
    return Utilities.registry_sections.active
end

return TemplateFluidIO