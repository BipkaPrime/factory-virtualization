-- Template dashboards is a gui window that displays information
-- about current state of all venvs there are.

local gui_names = require("scripts.gui.gui-names")
local gui_common = require("scripts.gui.common-gui-elements")
local utils = require("scripts.gui.utils")

local Helper = {}


-- Opens/Closes template dashboard for a given player
function Helper.toggle_template_dashboard(player)
    -- closing dashboard if it was opened
    if player.gui.screen[gui_names.prefix .. gui_names.dashboard_window] then
        player.opened = nil
        return
    end

    -- opening dashboard
    local main_frame = gui_common.gui_base_window(player, gui_names.prefix .. gui_names.dashboard_window)
    player.opened = main_frame
    storage.dashboard[player.index] = {}

    -- invisible container for other frames
    local main_content_frame = main_frame.add{
        type="flow",
        name = gui_names.prefix .. gui_names.dashboard_content_frame,
        direction="horizontal",
    }
    main_content_frame.style.height = 548

    -- left half of interface
    local left_content_frame = main_content_frame.add{
        type="frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    left_content_frame.style.right_margin = 12

    -- template selection element
    local row1 = gui_common.selection_widget(
        left_content_frame,
        gui_names.prefix .. gui_names.dashboard_template_selection_flow,
        gui_names.prefix .. gui_names.dashboard_template_searchfield,
        gui_names.prefix .. gui_names.dashboard_template_selector,
        {"gui-label.frequency-selection"}
    )
    row1.style.bottom_margin = 12

    -- populate template selector with all compiled templates
    local template_selector = row1[gui_names.prefix .. gui_names.dashboard_template_selector]
    local available_templates = utils.get_all_freq()
    gui_common.arrange_selector(template_selector, available_templates, nil, nil)

    -- surface selection element
    local row2 = gui_common.selection_widget(
        left_content_frame,
        gui_names.prefix .. gui_names.dashboard_surface_selection_flow,
        gui_names.prefix .. gui_names.dashboard_surface_searchfield,
        gui_names.prefix .. gui_names.dashboard_surface_selector,
        {"gui-label.surface-selection"}
    )
    -- disabling surface selection. It should be enabled only when template is selected.
    utils.set_element_state(row2, false)

    -- right half of interface
    local right_content_frame = main_content_frame.add{
        type = "frame",
        name = gui_names.prefix .. gui_names.dashboard_right_content_frame,
        style = "inside_shallow_frame",
        direction = "vertical"
    }
    right_content_frame.style.width = 444

    -- main datafield
    local datafield = right_content_frame.add{
        type = "scroll-pane",
        name = gui_names.prefix .. gui_names.dashboard_datafield,
    }
    datafield.style.vertically_stretchable = true
end

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
    local options = utils.get_all_freq()
    local query = element.text
    local selected_option = storage.dashboard[event.player_index].template
    gui_common.arrange_selector(selector, options, query, selected_option)
end

-- gathers names of all surfaces, which have vevs associated with given template 
local function get_all_surfaces(template)
    local result = {}
    local template_data = storage.virtual_environments[template]
    -- checking that at least something is found
    if not template_data then return end
    for surface_id, _ in pairs(template_data) do
        table.insert(result, game.get_surface(surface_id).name)
    end
    return result
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

    -- saving selected surface
    local template = storage.dashboard[event.player_index].selected_template
    local options = get_all_surfaces(template)
    local query = element.text
    local selected_option = storage[event.player_index].selected_surface
    gui_common.arrange_selector(selector, options, query, selected_option)
end

-- Adds table with sprite buttons that represents building cost of template
local function arrange_build_cost(cost_table, gui_element)
    local sprite_table = gui_common.empty_grid_panel(gui_element, {"gui-label.construction-cost"})
    for name, quantities in pairs(cost_table) do
        for quality, count in pairs(quantities) do
            gui_common.insert_item_icon(sprite_table, name, count, quality)
        end
    end
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

        arrange_build_cost(template_data.building_cost, datafield)

        



        
        -- TODO: display template data
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