--[[
Template IOs help in creation of templates. They serve as inputs and outputs
of items, fluids and electric energy on virtualization surfaces.
--]]

local VEnvProcessor = require("src.simulation.venv-processor")

local TemplateIO = {}

---Updates given template item io
---@param properties EntityProperties
function TemplateIO.process_template_item_io(properties)
    properties.ls_flow = 0
    -- does not operate on any surface except vsufaces
    if not properties.on_vsurface then return end

    -- does not operate without selected item
    local item = properties.selected_item
    if not item then return end

    -- removing or adding selected item to physical inventory
    local entity = properties.entity
    ---@type LuaInventory assuming inventory was cached
    local inventory = properties.inventory
    item.count = properties.flow_limit
    local delta = 0
    if properties.is_output then
        ---@diagnostic disable-next-line: param-type-mismatch
        delta = inventory.remove(item)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        delta = inventory.insert(item)
    end
    properties.ls_flow = delta

    -- storing delta in venv if surface is compiling
    ---@type string assuming buffer key was cached
    local buffer_key = properties.buffer_key
    local surface_index = entity.surface_index
    VEnvProcessor.add_io_count(surface_index, buffer_key, delta, properties.is_output)
end

---Updates given template fluid io
---@param properties EntityProperties
function TemplateIO.process_template_fluid_io(properties)
    properties.ls_flow = 0
    -- does not operate on any surfaces except vsufaces
    if not properties.on_vsurface then return end

    -- does not operate without selected fluid
    local fluid = properties.selected_fluid
    if not fluid then return end

    -- removing or adding selected fluid to physical inventory
    local entity = properties.entity
    fluid.amount = properties.flow_limit
    local delta = 0
    if properties.is_output then
        ---@diagnostic disable-next-line: param-type-mismatch
        delta = entity.extract_fluid(fluid)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        delta = entity.insert_fluid(fluid)
    end
    properties.ls_flow = delta
    -- storing delta in venv if surface is compiling
    local surface_index = entity.surface_index
    VEnvProcessor.add_io_count(surface_index, fluid.name, delta, properties.is_output)
end

---Updates given template energy io
---@param properties EntityProperties
function TemplateIO.process_template_energy_io(properties)
    properties.ls_flow = 0
    -- does not operate on any surfaces except vsufaces
    if not properties.on_vsurface then return end

    -- removing or adding energy to this IO
    local entity = properties.entity
    ---@type string assuming buffer key was cached
    local buffer_key = properties.buffer_key
    local flow_limit = properties.flow_limit
    local current_energy = entity.energy
    local delta = 0
    if properties.is_output then
        delta = math.min(current_energy, flow_limit)
        entity.energy = current_energy - delta
    else
        delta = math.min(entity.electric_buffer_size - current_energy, flow_limit)
        entity.energy = current_energy + delta
    end
    properties.ls_flow = delta
    -- storing delta in venv if surface is compiling
    local surface_index = entity.surface_index
    VEnvProcessor.add_io_count(surface_index, buffer_key, delta, properties.is_output)
end

return TemplateIO