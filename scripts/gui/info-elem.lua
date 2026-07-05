-- This file contains definitions for information gui elements.
-- They cannot be interacted with and only there to display information.

local elem_data = require("scripts.gui.info-elem-data")
local common = require("scripts.gui.common")

local Helper = {}

-- Base gui element for all info elements
-- Basically a bordered frame with set width and label
-- @returns LuaGuiElement: reference to main flow 
local function info_element_base(parent, label)
    local main_frame = parent.add{
        type = "frame",
        style = "bordered_frame"
    }
    main_frame.style.minimal_width = 424
    local main_flow = main_frame.add{
        type = "flow",
        direction = "vertical",
    }
    -- Label at the top of this section
    local subtitle = main_flow.add{
        type = "label",
        caption = label,
        style = "bold_label",
    }
    subtitle.style.font_color = {255, 230, 199}

    return main_flow
end

-- Adds bold label to a given element
local function add_bold_label(parent, caption)
    parent.add{
        type = "label",
        caption = caption,
        style = "bold_label"
    }
end

function Helper.vmainframe_status_display(parent, reg_data)
    local section = info_element_base(parent, "VMAINFRAME INFO DISPLAY")
    local status = "STATUS: TEMPLATE NOT SELECTED"
    if reg_data.operational then
        status = "STATUS: OPERATIONAL"
    elseif reg_data.active_template then
        status = "STATUS: REQUESTING CONSTRUCTION MATERIALS"
    end
    add_bold_label(section, status)
end

function Helper.vmainframe_building_requests(parent, reg_data)
    local section = info_element_base(parent, "MISSING CONSTRUCTION MATERIALS")
    local requests = elem_data.get_vmainframe_requests(reg_data)
    common.sprite_button_panel(section, requests)
end

-- Adds section describing template construction cost
function Helper.template_construction_cost(parent, template_name)
    local section = info_element_base(
        parent,
        {"gui-label.construction-cost"}
    )
    local build_cost = elem_data.get_building_cost(template_name)
    common.sprite_button_panel(section, build_cost)
end

-- Adds section describing template inputs per second
function Helper.template_inputs_per_second(parent, template_name)
    local section = info_element_base(
        parent,
        {"gui-label.template-input"}
    )
    local inputs = elem_data.get_inputs(template_name)
    common.sprite_button_panel(section, inputs)
    -- energy inputs
    local primary, simulation, total = elem_data.get_energy_costs(template_name)
    add_bold_label(section, {"", {"gui-label.template-energy-input"}, ": ", primary})
    add_bold_label(section, {"", {"gui-label.template-simulation-cost"}, ": ", simulation})
    add_bold_label(section, {"", {"gui-label.template-total-energy"}, ": ", total})
end

-- Adds section describing template outputs per second
function Helper.template_outputs_per_second(parent, template_name)
    local section = info_element_base(
        parent,
        {"gui-label.template-output"}
    )
    local outputs = elem_data.get_outputs(template_name)
    common.sprite_button_panel(section, outputs)
    -- energy production
    local energy_prod = elem_data.get_energy_production(template_name)
    add_bold_label(section, {"", {"gui-label.template-energy-output"}, ": ", energy_prod})
end

-- Adds 3 sections describing template research capabilities
function Helper.template_research_production(parent, template_name)
    local labs, logistics, ppi = elem_data.get_science_production(template_name)
    local section1 = info_element_base(
        parent,
        {"gui-label.research-per-second-labs"}
    )
    common.sprite_button_panel(section1, labs)
    local section2 = info_element_base(
        parent,
        {"gui-label.research-per-second-logistics"}
    )
    common.sprite_button_panel(section2, logistics)
    local section3 = info_element_base(
        parent,
        {"gui-label.research-points-per-item"}
    )
    common.sprite_button_panel(section3, ppi)
end

return Helper