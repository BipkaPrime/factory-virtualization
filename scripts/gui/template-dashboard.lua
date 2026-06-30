



-- Updates template selector for dashboard when search query changes
-- Used when on_gui_text_changed event is triggered
function Helper.process_dashboard_template_search(event)
    -- cheking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- checking the element name
    if element.name ~= gui_names.prefix .. gui_names.dashboard_template_searchfield then return end

    -- modifying selector options based on search query
    local selector = element.parent[gui_names.prefix .. gui_names.dashboard_template_selector]
    local options = utils.get_all_templates()
    local query = element.text
    local selected_option = storage.dashboard[event.player_index].template
    gui_common.arrange_selector(selector, options, query, selected_option)
end

-- Updates surface selector for dashboard when search query changes
-- Used when on_gui_text_changed event is triggered
function Helper.process_dashboard_surface_search(event)
    -- cheking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- checking the element name
    if element.name ~= gui_names.prefix .. gui_names.dashboard_surface_searchfield then return end

    -- modifying selector options based on search query
    local selector = element.parent[gui_names.prefix .. gui_names.dashboard_surface_selector]
    local template = storage.dashboard[event.player_index].selected_template
    local options = utils.get_all_surfaces(template)
    local query = element.text
    local selected_option = storage.dashboard[event.player_index].selected_surface
    gui_common.arrange_selector(selector, options, query, selected_option)
end

-- Dashboard datafield consists of these
local function dashboard_section_base(parent_element, label)
    local main_frame = parent_element.add{
        type = "frame",
        style = "bordered_frame"
    }
    main_frame.style.minimal_width = 424

    local main_flow = main_frame.add{
        type = "flow",
        direction = "vertical",
    }

    -- Label at the top of this section
    local label_element = main_flow.add{
        type = "label",
        caption = label,
        style = "bold_label",
    }
    label_element.style.font_color = {255, 230, 199}

    return main_flow
end

-- Adds section that represents building cost of template
local function arrange_build_cost(template_data, gui_element)
    -- collecting building cost data
    local data = {}
    for name, quantities in pairs(template_data.building_cost) do
        for quality, count in pairs(quantities) do
            table.insert(data, {type = "item", name = name, count = count, quality = quality})
        end
    end
    -- checking that building data is not empty
    if #data > 0 then
        -- sorting collected data
        table.sort(data, utils.sprite_buttons_comparison)

        -- inserting sorted sprite buttons into the gui
        local section = dashboard_section_base(gui_element, {"gui-label.construction-cost"})
        local sprite_table = gui_common.empty_grid_panel(section)
        gui_common.populate_sprite_grid(sprite_table, data)
    end
end

-- Adds section representing template inputs
local function arrange_inputs(template_data, gui_element)
    local section = dashboard_section_base(gui_element, {"gui-label.template-input"})
    local buttons = utils.collect_io_data(template_data.input)
    if #buttons > 0 then
        local sprite_table = gui_common.empty_grid_panel(section)
        gui_common.populate_sprite_grid(sprite_table, buttons)
    end

    -- adding energy cost
    local energy_cost = 0
    if template_data.input and template_data.input.energy then
        energy_cost = template_data.input.energy
        if energy_cost > 0 then
            local formated = utils.format_double(energy_cost) .. "W"
            gui_common.add_label(section, {"", {"gui-label.template-energy-input"}, ": ", formated})
        end
    end
    -- adding simulation cost
    local simulation_cost = utils.template_area_to_power(template_data.area)
    if simulation_cost > 0 then
        local formated = utils.format_double(simulation_cost) .. "W"
        gui_common.add_label(section, {"", {"gui-label.template-simulation-cost"}, ": ", formated})
    end
    -- adding total cost
    local total = energy_cost + simulation_cost
    if total > 0 then
        local formated = utils.format_double(total) .. "W"
        gui_common.add_label(section, {"", {"gui-label.template-total-energy"}, ": ", formated})
    end
end

-- Adds section representing template outputs
local function arrange_outputs(template_data, gui_element)
    local section = dashboard_section_base(gui_element, {"gui-label.template-output"})
    local buttons = utils.collect_io_data(template_data.output)
    if #buttons > 0 then
        local sprite_table = gui_common.empty_grid_panel(section)
        gui_common.populate_sprite_grid(sprite_table, buttons)
    end

    -- adding energy production
    if template_data.output and template_data.output.energy then
        local energy_production = template_data.output.energy
        if energy_production > 0 then
            local formated = utils.format_double(energy_production) .. "W"
            gui_common.add_label(section, {"", {"gui-label.template-energy-output"}, ": ", formated})
        end
    end
    -- adding pollution
    if template_data.pollution then
        local pollution = utils.format_double(template_data.pollution)
        gui_common.add_label(section, {"", {"gui-label.template-pollution-output"}, ": ", pollution})
    end
end

-- Adds 2 sections representing template research points output
local function arrange_science_production(template_data, gui_element)
    if not template_data.science then return end
    local labs_buttons, logistics_buttons = utils.collect_science_capability(template_data.science)
    -- lab capability section
    local labs_section = dashboard_section_base(gui_element, {"gui-label.research-capability-labs"})
    local sprite_table_labs = gui_common.empty_grid_panel(labs_section)
    gui_common.populate_sprite_grid(sprite_table_labs, labs_buttons)
    -- logistics capability section
    local logistics_section = dashboard_section_base(gui_element, {"gui-label.research-capability-logistics"})
    local sprite_table_logistics = gui_common.empty_grid_panel(logistics_section)
    gui_common.populate_sprite_grid(sprite_table_logistics, logistics_buttons)
end

-- Displays data about selected template on dashboard
-- or about virtual environment if surface is also selected.
local function populate_dashboard_datafield(player_idx)
    -- getting gui element we want to write in
    local player = game.get_player(player_idx)
    local dashboard_window = player.gui.screen[gui_names.prefix .. gui_names.dashboard_window]
    local main_content_frame = dashboard_window[gui_names.prefix .. gui_names.dashboard_content_frame]
    local right_content_frame = main_content_frame[gui_names.prefix .. gui_names.dashboard_right_content_frame]
    local datafield = right_content_frame[gui_names.prefix .. gui_names.dashboard_datafield]

    datafield.clear()

    -- getting selected template and surface
    local selected_options = storage.dashboard[player_idx]
    local template = selected_options.template
    local surface = selected_options.surface

    if not surface then
        -- only template is selected
        local template_data = storage.compiled_templates[template]
        arrange_build_cost(template_data, datafield)
        arrange_inputs(template_data, datafield)
        arrange_outputs(template_data, datafield)
        arrange_science_production(template_data, datafield)
    else
        -- both template and surface are selected
        -- TODO: display venv data
    end
end


-- Handles event of player selecting something in template selector
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_dashboard_template_selector(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- checking the element name
    if element.name ~= gui_names.prefix .. gui_names.dashboard_template_selector then return end

    -- saving selected template
    local selector_options = element.items
    local idx = element.selected_index
    storage.dashboard[event.player_index].template = selector_options[idx]

    -- updating dashboard datafield
    populate_dashboard_datafield(event.player_index)

    -- enabling surface selector
    local surface_selection = element.parent.parent[gui_names.prefix .. gui_names.dashboard_surface_selection_flow]
    utils.set_element_state(surface_selection, true)
end

-- Handles event of player selecting something in surface selector
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_dashboard_surface_selector(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- checking the element name
    if element.name ~= gui_names.prefix .. gui_names.dashboard_surface_selector then return end

    -- saving selected surface
    local selector_options = element.items
    local idx = element.selected_index
    storage.dashboard[event.player_index].surface = selector_options[idx]

    -- updating dashboard datafield
    populate_dashboard_datafield(event.player_index)
end

-- Closes the dashboard if it's opened when player.opened changes. 
-- For instance if ESC/E are pressed or when another window is opened. 
-- Used when on_gui_closed event is triggered
function Helper.process_dashboard_gui_closed(event)
    -- cheking if element is valid
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    local window_name = element.name
    if window_name ~= gui_names.prefix .. gui_names.dashboard_window then return end

    -- getting the player object
    local player = game.get_player(event.player_index)
    if not player then return end

    -- closing dashboard for given player
    storage.dashboard[event.player_index] = nil
    local dashboard_element = player.gui.screen[gui_names.prefix .. gui_names.dashboard_window]
    if dashboard_element then
        dashboard_element.destroy()
    end
end


return Helper