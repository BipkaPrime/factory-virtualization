--[[
Template IOs help in creation of templates. They serve as inputs and outputs
of items, fluids and electric energy on virtualization surfaces.
--]]

local VSurfaceManager = require("src.world.vsurface-manager")
local VEnvProcessor = require("src.simulation.venv-processor")

local TemplateIO = {}
local PREFIX = "FV-"

local flow_limits = {
    [PREFIX .. "template-item-io-mk1"] = 100,
    [PREFIX .. "template-item-io-mk2"] = 1000,
    [PREFIX .. "template-item-io-mk3"] = 10000,
    [PREFIX .. "template-fluid-io-mk1"] = 1000,
    [PREFIX .. "template-fluid-io-mk2"] = 10000,
    [PREFIX .. "template-fluid-io-mk3"] = 100000,
    [PREFIX .. "template-energy-io-mk1"] = 1e9,
    [PREFIX .. "template-energy-io-mk2"] = 1e10,
    [PREFIX .. "template-energy-io-mk3"] = 1e11,
}

---Updates given template item io
---@param properties TemplateItemIOProperties
function TemplateIO.process_template_item_io(properties)
    -- does not operate without selected item
    local item = properties.selected_item
    if not item then return end

    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    local surface_index = entity.surface_index
    if not VSurfaceManager.get_vsurface_data(surface_index) then return end

    -- removing or adding selected item to physical inventory
    -- and storing delta in venv if surface is compiling
    local inventory = properties.inventory
    item.count = flow_limits[entity.name]
    local delta = 0
    if properties.is_output then
        ---@diagnostic disable-next-line: param-type-mismatch
        delta = inventory.remove(item)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        delta = inventory.insert(item)
    end
    ---@type string assuming buffer key was created at the moment of item selection
    local buffer_key = properties.buffer_key
    VEnvProcessor.add_io_count(surface_index, buffer_key, delta, properties.is_output)
end

---Updates given template fluid io
---@param properties TemplateFluidIOProperties
function TemplateIO.process_template_fluid_io(properties)
    -- does not operate without selected fluid
    local fluid = properties.selected_fluid
    if not fluid then return end

    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    local surface_index = entity.surface_index
    if not VSurfaceManager.get_vsurface_data(surface_index) then return end

    -- removing or adding selected fluid to physical inventory
    -- and storing delta in venv if surface is compiling
    fluid.amount = flow_limits[entity.name]
    local delta = 0
    if properties.is_output then
        ---@diagnostic disable-next-line: param-type-mismatch
        delta = entity.extract_fluid(fluid)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        delta = entity.insert_fluid(fluid)
    end
    VEnvProcessor.add_io_count(surface_index, fluid.name, delta, properties.is_output)
end

---Updates given template energy io
---@param properties TemplateEnergyIOProperties
function TemplateIO.process_template_energy_io(properties)
    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    local surface_index = entity.surface_index
    if not VSurfaceManager.get_vsurface_data(surface_index) then return end

    -- removing or adding energy to this IO
    -- and storing delta in venv if surface is compiling
    local buffer_key = "electric_energy"
    local flow_limit = flow_limits[entity.name]
    local delta = 0
    if properties.is_output then
        delta = math.min(entity.energy, flow_limit)
        entity.energy = entity.energy - delta
    else
        delta = math.min(entity.electric_buffer_size - entity.energy, flow_limit)
        entity.energy = entity.energy + delta
    end
    VEnvProcessor.add_io_count(surface_index, buffer_key, delta, properties.is_output)
end

return TemplateIO