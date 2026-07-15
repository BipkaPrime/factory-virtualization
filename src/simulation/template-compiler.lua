--[[
Main purpose of this file is to take "venv" data and transform it into compiled template.
It also handles requests like get_template, get_all_templates, etc.

When venv processor successfully finished compilation process of a vsurface,
it orders template compiler to create a template from data in the venv.
All compiled template are located at storage.templates. For this table key is 
template name (string), value is template data (table). Template names are their
unique identifiers.

--TODO ADD:
science table: {labs = {}, logistics = {}, point_per_item = {}}.
    All inner tables are hashmaps. For all tables, the key is ingredient name.
    For labs and logistics value is research points per second.
    For points_per_item value is number of research points produced per 1 spent item.
    These values are calculated for normal quality ingredients.
--]]

---Table containing compiled template data
---@class TemplateData
---@field input table<BufferKeyString, number> input per second
---@field output table<BufferKeyString, number> output per second
---@field building_cost table<BufferKeyString, number> items needed for construction of this template
---@field energy_drain number energy drain of this template (due to surface area)
---@field research_template boolean true if this is a research template


local VSurfaceManager = require("src.world.vsurface-manager")

local TemplateCompiler = {}

-------------------------------------------------------------------------------
-- INFORMATION REQUEST HANDLERS
-------------------------------------------------------------------------------

---Retrieves a compiled template data from storage
---@param template_name string unique template identifier
---@return table|nil template compiled template data if found
function TemplateCompiler.get_template(template_name)
    return storage.templates[template_name]
end

---Collects names of all compiled templates
---@return string[] names
function TemplateCompiler.get_all_template_names()
    local result = {}
    for name, _ in pairs(storage.templates) do
        table.insert(result, name)
    end
    return result
end

---Gets all inputs of a given template
---@param template_name string|nil unique template identifier
---@return table<BufferKeyString, number> inputs
function TemplateCompiler.get_inputs(template_name)
    if not template_name then return {} end
    local template = storage.templates[template_name]
    if not template then return {} end
    return template.input
end

---Gets all outputs of a given template
---@param template_name string|nil unique template identifier
---@return table<BufferKeyString, number> outputs
function TemplateCompiler.get_outputs(template_name)
    if not template_name then return {} end
    local template = storage.templates[template_name]
    if not template then return {} end
    return template.output
end

---Gets building cost of a given template
---@param template_name string|nil unique template identifier
---@return table<ItemKeyString, number> items key is "name//quality"
function TemplateCompiler.get_building_cost(template_name)
    if not template_name then return {} end
    local template = storage.templates[template_name]
    if not template then return {} end
    return template.building_cost
end

---Gets energy consumption and energy drain of a given template
---@param template_name string|nil unique template identifier
---@return number energy_input, number energy_drain 
function TemplateCompiler.get_energy_consumption(template_name)
    if not template_name then return 0, 0 end
    local template = storage.templates[template_name]
    if not template then return 0, 0 end
    local energy_input = template.input.electric_energy or 0
    local energy_drain = template.energy_drain or 0
    return energy_input, energy_drain
end

---Gets energy production of a given template
---@param template_name string|nil unique template identifier
---@return number energy_production
function TemplateCompiler.get_energy_production(template_name)
    if not template_name then return 0 end
    local template = storage.templates[template_name]
    if not template then return 0 end
    return template.output.electric_energy or 0
end

-------------------------------------------------------------------------------
-- TEMPLATE CREATION FUNCTIONS
-------------------------------------------------------------------------------

---Helps in template creation. Calculates flow per second.
---@param counts table<string, number> total counts over a period of time
---@param time number total time
---@return table<string, number> flow counts divided by time
local function calculate_flow(counts, time)
    -- protection against zero division
    local safe_time = (not time or time <= 0) and 1 or time

    local result = {}
    for key, count in pairs(counts) do
        result[key] = count/safe_time
    end
    return result
end

---Creates template from virtual environment data.
---@param venv table virtual environment data
---@param surface_index integer unique surface identifier
function TemplateCompiler.create_template(venv, surface_index)
    local template = {}
    template.input = calculate_flow(venv.input, venv.compilation_time)
    template.output = calculate_flow(venv.output, venv.compilation_time)
    template.building_cost = VSurfaceManager.get_vsurface_building_cost(surface_index)
    template.energy_drain = VSurfaceManager.get_vsurface_energy_drain(surface_index)
    template.research_template = venv.research_template
    --TODO: Add science

    storage.templates[venv.template_name] = template
end

return TemplateCompiler