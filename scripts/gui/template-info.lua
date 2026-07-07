-- This file is used to display information about compiled templates.
-- Created gui element cannot be interacted with.

local misc = require("scripts.misc")
local common = require("scripts.gui.common")

local Helper = {}

-- converts table section containing items from 2-level hmap
-- of form "table[item_name][quality_name] = count" to displayable form
-- of array of {type, name, count, quality}. Appends data to the end of
-- output_table if it's provided.
local function collect_item_table(input_table, output_table)
    local result = output_table or {}
    if not input_table then return result end
    for name, q_counts in pairs(input_table) do
        for quality, count in pairs(q_counts) do
            local data = {
                type = "item",
                name = name,
                count = count,
                quality = quality
            }
            table.insert(result, data)
        end
    end
    return result
end

-- converts table section containing fluids from hmap
-- of form "table[fluid_name] = count" to displayable form
-- of array of {type, name, count, quality}. Appends data to the end of
-- output_table if it's provided.
local function collect_fluid_table(input_table, output_table)
    local result = output_table or {}
    if not input_table then return result end
    for name, count in pairs(input_table) do
        local data = {
            type = "fluid",
            name = name,
            count = count
        }
        table.insert(result, data)
    end
    return result
end

-- collects template building cost in form
-- of array of {type, name, count, quality}
local function get_building_cost(template_name)
    local template = storage.compiled_templates[template_name]
    if not template then return {} end
    return collect_item_table(template.building_cost)
end

-- Adds section describing template construction cost
function Helper.template_construction_cost(parent, template_name)
    local section = common.info_element_base(
        parent,
        {"gui-label.construction-cost"}
    )
    local build_cost = get_building_cost(template_name)
    common.sprite_button_panel(section, build_cost)
end

-- collects template inputs in form
-- of array of {type, name, count, quality}
local function get_inputs(template_name)
    local template = storage.compiled_templates[template_name]
    if not template or not template.input then return {} end
    local inputs = {}
    collect_item_table(template.input.items, inputs)
    collect_fluid_table(template.input.fluids, inputs)
    return inputs
end

-- collects template energy cost. Returns 3 strings representing
-- energy demand like "105 GW"/"10.7 kW"/etc.
-- Returned values are: energy input, simulation cost, total cost
local function get_energy_costs(template_name)
    local template = storage.compiled_templates[template_name]
    if not template then return "0 W", "0 W", "0 W" end
    -- regular energy input
    local energy_input = 0
    if template.input and template.input.energy then
        energy_input = template.input.energy
    end
    local input_formated = misc.format_double(energy_input) .. "W"
    -- simulation cost
    local area = template.area
    local sim_cost = misc.template_area_to_power(area)
    local sim_formated = misc.format_double(sim_cost) .. "W"
    -- total cost
    local total_cost = energy_input + sim_cost
    local total_formated = misc.format_double(total_cost) .. "W"
    return input_formated, sim_formated, total_formated
end

-- Adds section describing template inputs per second
function Helper.template_inputs_per_second(parent, template_name)
    local section = common.info_element_base(
        parent,
        {"gui-label.template-input"}
    )
    local inputs = get_inputs(template_name)
    common.sprite_button_panel(section, inputs)
    -- energy inputs
    local primary, simulation, total = get_energy_costs(template_name)
    common.add_bold_label(section, {"", {"gui-label.template-energy-input"}, ": ", primary})
    common.add_bold_label(section, {"", {"gui-label.template-simulation-cost"}, ": ", simulation})
    common.add_bold_label(section, {"", {"gui-label.template-total-energy"}, ": ", total})
end

-- collects template outputs in form
-- of array of {type, name, count, quality}
local function get_outputs(template_name)
    local template = storage.compiled_templates[template_name]
    if not template or not template.output then return {} end
    local outputs = {}
    collect_item_table(template.output.items, outputs)
    collect_fluid_table(template.output.fluids, outputs)
    return outputs
end

-- collects template energy production.
-- @returns string: for example "105 GW", "10.7 kW"
local function get_energy_production(template_name)
    local template = storage.compiled_templates[template_name]
    if not template then return "0 W" end
    local energy_prod = 0
    if template.output and template.output.energy then
        energy_prod = template.output.energy
    end
    return misc.format_double(energy_prod) .. "W"
end

-- Adds section describing template outputs per second
function Helper.template_outputs_per_second(parent, template_name)
    local section = common.info_element_base(
        parent,
        {"gui-label.template-output"}
    )
    local outputs = get_outputs(template_name)
    common.sprite_button_panel(section, outputs)
    -- energy production
    local energy_prod = get_energy_production(template_name)
    common.add_bold_label(section, {"", {"gui-label.template-energy-output"}, ": ", energy_prod})
end

-- converts template data section containing science production from hmap
-- of form "table[ingredient_name] = value" to displayable form
-- of array of {type, name, count, quality}.
local function collect_science_table(input_table)
    if not input_table then return {} end
    local result = {}
    for name, count in pairs(input_table) do
        data = {
            type = "item",
            name = name,
            count = count,
            quality = "normal"
        }
        table.insert(result, data)
    end
    return result
end

-- collects template research capability consisting of 3 arrays
-- labs potential, logistics potential, research points per item
-- {type, name, count, quality = "normal"}.
local function get_science_production(template_name)
    local template = storage.compiled_templates[template_name]
    if not template or not template.science then return {}, {}, {} end
    local labs = collect_science_table(template.science.labs_potential)
    local logistics = collect_science_table(template.science.logistics_potential)
    local ppi = collect_science_table(template.science.points_per_item)
    return labs, logistics, ppi
end

-- Adds 3 sections describing template research capabilities
function Helper.template_research_production(parent, template_name)
    local labs, logistics, ppi = get_science_production(template_name)
    local section1 = common.info_element_base(
        parent,
        {"gui-label.research-per-second-labs"}
    )
    common.sprite_button_panel(section1, labs)
    local section2 = common.info_element_base(
        parent,
        {"gui-label.research-per-second-logistics"}
    )
    common.sprite_button_panel(section2, logistics)
    local section3 = common.info_element_base(
        parent,
        {"gui-label.research-points-per-item"}
    )
    common.sprite_button_panel(section3, ppi)
end

return Helper