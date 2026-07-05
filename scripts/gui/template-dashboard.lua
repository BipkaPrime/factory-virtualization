-- Template dashboard is a gui window which displays information
-- about all compiled templates and all virtual environments on all surfaces.

-- Main considerations to keep in mind when creating this gui.
-- 1. I want all data to persist if interface is closed and then opened again.
--    To achieve this, we store all data related to interface state in storage.
-- 2. We have to update parts of the interface in responce to user inputs.
--    To do this conveniently, we store references to all objects that we want to update,
--    because it's much more convenient and robust then traversing gui by element names.
-- 3. We have to process user inputs. For that we give names to all elements that user
--    can interact with: main_window, textfields, dropdowns, etc.

--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = storage.template_dashboard[player_index]. table keys:
-- opened bool: true if dashboard is currently opened
-- template_query string: template search query
-- template_name string: name of selected template
-- surface_query string: surface search query
-- surface_name string: name of selected surface
-- elements.main_window LuaGuiElement: reference to dashboard main window
-- elements.template_search LuaGuiElement: reference to template searchfield
-- elements.template_selector LuaGuiElement: reference to template selector
-- elements.surface_search LuaGuiElement: reference to surface searchfield
-- elements.surface_selector LuaGuiElement: reference to surface selector
-- elements.datafield LuaGuiElement: reference to scroll pane on the right where info is displayed

local names = require("scripts.gui.names")
local common = require("scripts.gui.common")
local info_elem = require("scripts.gui.info-elem")
local misc = require("scripts.misc")

local Helper = {}

local function update_template_selector(dashboard_data)
    local selector = dashboard_data.elements.template_selector
    if not selector or not selector.valid then return end
    local query = dashboard_data.template_query
    local selected = dashboard_data.template_name
    local options = misc.get_all_templates()
    common.arrange_selector(selector, options, query, selected)
end

local function update_surface_selector(dashboard_data)
    -- TODO
end

-- Creates a template dashboard base.
-- It's assumed that template dashboard is not opened when this is called
local function template_dashboard_base(player)
    -- creating base window and "opening" it
    local main_frame = common.gui_base_window(
        player,
        names.prefix .. names.td_window,
        {"gui-title.td-window"}
    )
    player.opened = main_frame
    storage.template_dashboard[player.index] = storage.template_dashboard[player.index] or {}
    local dashboard_data = storage.template_dashboard[player.index]
    dashboard_data.opened = true
    dashboard_data.elements = {main_window = main_frame}

    -- invisible container for other frames
    local main_flow = main_frame.add{
        type="flow",
        direction="horizontal",
    }
    main_flow.style.height = 560

    -- left half of interface
    local left_frame = main_flow.add{
        type="frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    left_frame.style.right_margin = 12

    -- template selection widget
    local search, selector = common.selection_widget(
        left_frame,
        names.prefix .. names.td_template_search,
        names.prefix .. names.td_template_selector,
        {"gui-label.select-template"}
    )
    dashboard_data.elements.template_search = search
    dashboard_data.elements.template_selector = selector
    search.text = dashboard_data.template_query or ""
    update_template_selector(dashboard_data)

    -- surface selection widget
    local search, selector = common.selection_widget(
        left_frame,
        names.prefix .. names.td_surface_search,
        names.prefix .. names.td_surface_selector,
        {"gui-label.surface-selection"}
    )
    dashboard_data.elements.surface_search = search
    dashboard_data.elements.surface_selector = selector
    update_surface_selector(dashboard_data)

    -- right half of interface
    local right_frame = main_flow.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical"
    }
    right_frame.style.width = 444

    -- main datafield
    local datafield = right_frame.add{type = "scroll-pane"}
    datafield.style.vertically_stretchable = true
    dashboard_data.elements.datafield = datafield
end

local function template_info_gui(dashboard_data)
    local datafield = dashboard_data.elements.datafield
    local template_name = dashboard_data.template_name
    info_elem.template_construction_cost(datafield, template_name)
    info_elem.template_inputs_per_second(datafield, template_name)
    info_elem.template_outputs_per_second(datafield, template_name)
    info_elem.template_research_production(datafield, template_name)
end

local function venv_info_gui(dashboard_data)
    -- TODO
end

-- Updates data displayed on the right side of interface
local function update_datafield(dashboard_data)
    dashboard_data.elements.datafield.clear()
    local template_name = dashboard_data.template_name
    local surface_name = dashboard_data.surface_name
    if not template_name and not surface_name then return end
    if surface_name then
        -- template and surface selected
        venv_info_gui(dashboard_data)
    else
        -- only template selected
        template_info_gui(dashboard_data)
    end
end

-- Opens template dashboard for a given player or closes if already opened
local function toggle_template_dashboard(player)
    local dashboard_data = storage.template_dashboard[player.index]
    -- closing the window if it was opened
    if dashboard_data and dashboard_data.opened then
        player.opened = nil
        return
    end

    template_dashboard_base(player)
    update_datafield(storage.template_dashboard[player.index])
end

-- Time-based template dashboard updater
function Helper.update_opened_dashboards()
    for _, dashboard_data in pairs(storage.template_dashboard) do
        -- TODO
    end
end

-- Handles template searchfield being changed
-- Used when on_gui_text_changed event is triggered
function Helper.process_template_search(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    dashboard_data.template_query = event.element.text
    update_template_selector(dashboard_data)
end

-- Handles template selector being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_template_selector(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    local element = event.element
    local old_name = dashboard_data.template_name
    local new_name = element.items[element.selected_index]
    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        dashboard_data.template_name = nil
        update_template_selector(dashboard_data)
    else
        dashboard_data.template_name = new_name
    end
    update_datafield(dashboard_data)
end

-- Closes the template dashboard when player.opened changes.
-- Used when on_gui_closed event is triggered
function Helper.process_template_dashboard_gui_closed(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    dashboard_data.opened = nil
    dashboard_data.elements.main_window.destroy()
end

-- Toggles template dashboard when shortcut bar element is clicked
function Helper.process_dashboard_shortcut(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_template_dashboard(player)
end

-- Toggles template dashboard when custom hotkey is pressed
script.on_event(names.prefix .. names.td_hotkey, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_template_dashboard(player)
end)

-- After player changes surface with template dashboard opened
-- player.opened can be assigned nil with window still opened
-- So if window should be opened, we set player.opened to it.
function Helper.process_player_changed_surface(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    if not dashboard_data or not dashboard_data.opened then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = dashboard_data.elements.main_window
end

return Helper