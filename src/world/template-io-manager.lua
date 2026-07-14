--[[
Template IOs help in creation of templates. They serve as inputs and outputs
of items, fluids and electric energy on virtualization surfaces.

-------------------------------------------------------------------------------
TEMPLATE IO PROPERTIES
-------------------------------------------------------------------------------
entity LuaEntity: reference to entity object 
unit_number number: unique entity identifier
is_output bool|nil (mainframe-io, template-io): true if entity is output
selected_item table|nil (item-io): {name = string, quality = string} (user input)
buffer_key string|nil (item-io): "name//quality" (assigned by processor for fast access)
selected_fluid string|nil (fluid-io): name of selected fluid if any (user input)
--]]

local VSurfaceManager = require("src.world.vsurface-manager")
local VEnvProcessor = require("src.simulation.venv-processor")

local TemplateIO = {}

---Updates given template item io
---@param properties table entity data from entity registry
function TemplateIO.process_template_item_io(properties)
    -- does not operate without selected item
    local buffer_key = properties.buffer_key
    if not buffer_key then return end

    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    local surface_index = entity.surface_index
    if not VSurfaceManager.get_vsurface_data(surface_index) then return end

    -- removing or adding selected item to physical inventory
    -- and storing delta in venv if surface is compiling
    local inventory = entity.get_inventory(defines.inventory.chest)
    local item = properties.selected_item
    local delta = 0
    if properties.is_output then
        delta = inventory.remove({
            name = item.name,
            quality = item.quality,
            count = 1000000,
        })
    else
        delta = inventory.insert({
            name = item.name,
            quality = item.quality,
            count = 1000000,
        })
    end
    VEnvProcessor.add_io_count(surface_index, properties.is_output, buffer_key, delta)
end

---Updates given template fluid io
---@param properties table entity data from entity registry
function TemplateIO.process_template_fluid_io(properties)
    -- does not operate without selected fluid
    local fluid_name = properties.selected_fluid
    if not fluid_name then return end

    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    local surface_index = entity.surface_index
    if not VSurfaceManager.get_vsurface_data(surface_index) then return end

    -- removing or adding selected fluid to physical inventory
    -- and storing delta in venv if surface is compiling
    local delta = 0
    if properties.is_output then
        delta = entity.extract_fluid({
            name = fluid_name,
            amount = 1000000
        })
    else
        delta = entity.insert_fluid({
            name = fluid_name,
            amount = 1000000
        })
    end
    VEnvProcessor.add_io_count(surface_index, properties.is_output, fluid_name, delta)
end

---Updates given template energy io
---@param properties table entity data from entity registry
function TemplateIO.process_template_energy_io(properties)
    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    local surface_index = entity.surface_index
    if not VSurfaceManager.get_vsurface_data(surface_index) then return end

    -- removing or adding energy to this IO
    -- and storing delta in venv if surface is compiling
    local buffer_key = "electric_energy"
    local delta = 0
    if properties.is_output then
        delta = entity.energy
        entity.energy = 0
    else
        delta = entity.electric_buffer_size - entity.energy
        entity.energy = entity.electric_buffer_size
    end
    VEnvProcessor.add_io_count(surface_index, properties.is_output, buffer_key, delta)
end

return TemplateIO