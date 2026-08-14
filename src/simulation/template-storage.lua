--[[
Templates are essentially black-box mathematical models of a production line
with defined inputs, outputs, construction costs, etc.

All compiled template are located at storage.templates: table<string, TemplateData>
Templates are identifier by their names, which must be unique

For this table key is 
template name (string), value is template data (table). Template names are their
unique identifiers.
--]]

---Table containing compiled template data
---@class TemplateData
---@field input table<BufferKeyString, number> input per second
---@field output table<BufferKeyString, number> output per second
---@field building_cost table<BufferKeyString, number> items needed for construction of this template
---@field energy_drain number energy drain of this template

local TemplateStorage = {}

-------------------------------------------------------------------------------
-- INFORMATION REQUEST HANDLERS
-------------------------------------------------------------------------------

---Checks if provided template name is available
---@param template_name string unique template identifier
---@return boolean status true if name is available
function TemplateStorage.is_name_available(template_name)
    return not storage.templates[template_name]
end

---Saves provided template data to storage
---@param template TemplateData
---@param template_name string unique template identifier
function TemplateStorage.save_template(template, template_name)
    storage.templates[template_name] = template
end

---Gets building cost of a given template
---@param template_name string|nil unique template identifier
---@return table<BufferKeyString, number> items key is "name//quality"
function TemplateStorage.get_building_cost(template_name)
    if not template_name then return {} end
    local template = storage.templates[template_name]
    if not template then return {} end
    return template.building_cost
end


--[[

---Retrieves a compiled template data from storage
---@param template_name string unique template identifier
---@return TemplateData|nil template compiled template data if found
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




--]]

return TemplateStorage