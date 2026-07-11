--[[
Main purpose of this file is to take "venv" data and transform it into compiled template.
It also handles requests like get_template, get_all_templates, etc.

When venv processor successfully finished compilation process of a vsurface,
it orders template compiler to create a template from data in the venv.
All compiled template are located at storage.templates. For this table key is 
template name (string), value is template data (table). Template names are their
unique identifiers.

-------------------------------------------------------------------------------
TEMPLATE KEYS
-------------------------------------------------------------------------------
input table: inputs per second
output table: outputs per second.
building_cost table: contains items needed for construction of this template.
    input, output and building_cost tables share the same structure. Key is 
    item/fluid/energy identifier: "name//quality" for items, "name" for fluids,
    "electric_energy" for energy. For input/output value is flow/second. For building_cost
    value is integer (number of corresponding item to complete this template). 
energy_drain float: energy drain of this template (due to surface area)
research_template bool: true if this is a research template
science table: {labs = {}, logistics = {}, point_per_item = {}}.
    All inner tables are hashmaps. For all tables, the key is ingredient name.
    For labs and logistics value is research points per second.
    For points_per_item value is number of research points produced per 1 spent item.
    These values are calculated for normal quality ingredients.
--]]

local VSurfaceManager = require("src.world.vsurface-manager")

local TemplateCompiler = {}

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