--[[
Template energy IOs are used in creation of templates on virtualization surfaces.
They serve as inputs and outputs for electric energy.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Mandatory entity configuration is provided:
    1. io_mode. Used to determine the entity operation.
II. Entity is located on a vsurface.

Optional entity controls this building can have:
1. capability_override. Used to artificially lower flow limit of this entity.

Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. is_output. Used to determine entity operation
3. buffer_key. Used to make calls to venv processor
4. flow_limit. Used to make calls to factorio API
5. surface_index. Used to make calls to venv processor
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick processing:
1. ls_flow. Can be used to track entity work.
--]]

local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local TemplateEnergyIO = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
TemplateEnergyIO.configuration = {
    "io_mode",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "template-energy-io-mk1"] = 2.4e8,
    [PREFIX .. "template-energy-io-mk2"] = 2.4e9,
    [PREFIX .. "template-energy-io-mk3"] = 2.4e10,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function TemplateEnergyIO.initialize(properties)
    -- Checking that io mode is selected
    local io_mode = properties.io_mode
    if not io_mode then
        properties.status = Utilities.entity_status.no_io_mode
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
    properties.buffer_key = "electric_energy"
    local is_output = (io_mode == "output")
    properties.is_output = is_output
    -- setting up electric priority based on io mode
    entity.electric_interface_mode = (
        is_output and
        defines.electric_interface_mode.primary_input or
        defines.electric_interface_mode.primary_output
    )
    local base_flow = flow_limits[properties.entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    local override = properties.capability_override or 1
    properties.flow_limit = base_flow * quality_mult * override
    properties.surface_index = entity.surface_index
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function TemplateEnergyIO.uninitialize(properties)
    properties.buffer_key = nil
    properties.is_output = nil
    properties.flow_limit = nil
    properties.surface_index = nil
    properties.ls_flow = nil
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function TemplateEnergyIO.update(properties)
    local delta = 0
    local entity = properties.entity
    local current_energy = entity.energy
    local flow_limit = properties.flow_limit
    if properties.is_output then
        delta = math.min(current_energy, flow_limit)
        if delta > 0 then
            entity.energy = current_energy - delta
            VSurfaceManager.add_to_venv_output(
                properties.surface_index,
                properties.buffer_key,
                delta
            )
        end
    else
        delta = math.min(
            entity.electric_buffer_size - current_energy,
            flow_limit
        )
        if delta > 0 then
            entity.energy = current_energy + delta
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

return TemplateEnergyIO