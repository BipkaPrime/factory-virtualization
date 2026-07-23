--[[
Template dashboard allows players to look inside template storage as well 
as cluster storage. Displays template information if template is selected.
Displays vcluster information if template and surface are selected.

We want to store a bunch of data regarding this window in storage for 2 reasons.
First one is QoL of user, we want window state to persist through close-open cycle.
That's why we will be storing all user inputs in storage.
Second on is QoL of developer. We want to store references to all created gui elements
that we will be modifying in some way. This is much more convenient than traversing gui
tree by element names. Template dashboard data for all players is located at
storage.template_dashboard. For this table key is player index, value is table containing
dashboard data.
--]]

---Table with references to dashboard gui elements
---@class DashboardElements
---@field main_window LuaGuiElement
---@field template_search LuaGuiElement
---@field template_selector LuaGuiElement
---@field surface_search LuaGuiElement
---@field surface_selector LuaGuiElement
---@field datafield LuaGuiElement

---Table with dashboard gui data
---@class DashboardData
---@field opened boolean|nil true if dashboard is currently opened
---@field template_query string|nil template search query
---@field template_name string|nil name of selected template
---@field surface_query string|nil surface search query
---@field surface_name string|nil name of selected surface
---@field elements DashboardElements


local TemplateCompiler = require("src.simulation.template-compiler")
local ClusterProcessor = require("src.simulation.cluster-processor")
local ClusterInfo = require("src.gui.cluster-info")
local CommonGui = require("src.gui.common")

local PREFIX = "FV-"
local TemplateDashboard = {}

-------------------------------------------------------------------------------
-- CONTROL ELEMENTS: CREATE/CONFIGURE FUNCTIONS
-------------------------------------------------------------------------------

---Configures template selector
---@param dashboard_data DashboardData
local function configure_template_selector(dashboard_data)
    local selector = dashboard_data.elements.template_selector
    if not selector.valid then return end

    local options
    local surface_name = dashboard_data.surface_name
    if not surface_name then
        -- surface is not selected, showing all templates
        options = TemplateCompiler.get_all_template_names()
    else
        -- surface is selected, showing clusters on that surface
        options = ClusterProcessor.get_surface_clusters_by_name(surface_name)
    end
    local query = dashboard_data.template_query
    local selected = dashboard_data.template_name
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures template selector and searchbox above
---@param dashboard_data DashboardData
local function configure_template_selection_widget(dashboard_data)
    local search = dashboard_data.elements.template_search
    if not search.valid then return end
    search.text = dashboard_data.template_query or ""
    configure_template_selector(dashboard_data)
end

---Adds template selection widget to a given element. Widget consists of
---"label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement widget will added here
---@param dashboard_data DashboardData
local function create_template_selection_widget(parent, dashboard_data)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "td-template-search",
        PREFIX .. "td-template-selector",
        {"gui-label.select-template"}
    )
    dashboard_data.elements.template_search = search
    dashboard_data.elements.template_selector = selector
    configure_template_selection_widget(dashboard_data)
end

---Configures surface selector
---@param dashboard_data DashboardData
local function configure_surface_selector(dashboard_data)
    local selector = dashboard_data.elements.surface_selector
    if not selector.valid then return end

    local options
    local template_name = dashboard_data.template_name
    if not template_name then
        -- template is not selected, showing all surfaces with clusters
        options = ClusterProcessor.get_all_surfaces()
    else
        -- template is selected, showing surfaces with this template name
        options = ClusterProcessor.get_template_clusters(template_name)
    end

    local query = dashboard_data.surface_query
    local selected = dashboard_data.surface_name
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures surface selector and searchbox above
---@param dashboard_data DashboardData
local function configure_surface_selection_widget(dashboard_data)
    local search = dashboard_data.elements.surface_search
    if not search.valid then return end
    search.text = dashboard_data.surface_query or ""
    configure_surface_selector(dashboard_data)
end

---Adds surface selection widget to a given element. Widget consists of
---"label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement widget will added here
---@param dashboard_data DashboardData
local function create_surface_selection_widget(parent, dashboard_data)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "td-surface-search",
        PREFIX .. "td-surface-selector",
        {"gui-label.select-surface"}
    )
    dashboard_data.elements.surface_search = search
    dashboard_data.elements.surface_selector = selector
    configure_surface_selection_widget(dashboard_data)
end

-------------------------------------------------------------------------------
-- INFORMATION ELEMENTS: CREATE FUNCTIONS
-------------------------------------------------------------------------------

---Adds section describing template construction cost
---@param parent LuaGuiElement widget will added here
---@param dashboard_data DashboardData
local function create_template_construction_cost(parent, dashboard_data)
    local template_name = dashboard_data.template_name
    local build_cost = TemplateCompiler.get_building_cost(template_name)

    local section = CommonGui.create_info_element_base(
        parent,
        {"gui-label.construction-cost"}
    )

    local buttons = {}
    for key, count in pairs(build_cost) do
        local button_data = CommonGui.assemble_sprite_button_data(key, count)
        table.insert(buttons, button_data)
    end

    CommonGui.create_sprite_button_table(section, buttons)
end

---Adds section describing template inputs
---@param parent LuaGuiElement widget will added here
---@param dashboard_data DashboardData
local function create_template_inputs_section(parent, dashboard_data)
    local template_name = dashboard_data.template_name
    local inputs = TemplateCompiler.get_inputs(template_name)
    local energy_input, energy_drain = TemplateCompiler.get_energy_consumption(template_name)

    local section = CommonGui.create_info_element_base(
        parent,
        {"gui-label.template-input"}
    )
    -- table with item and fluid inputs
    local buttons = {}
    for key, count in pairs(inputs) do
        if key ~= "electric_energy" then
            local button_data = CommonGui.assemble_sprite_button_data(key, count)
            table.insert(buttons, button_data)
        end
    end
    CommonGui.create_sprite_button_table(section, buttons)

    -- energy inputs
    local primary = CommonGui.format_number(energy_input) .. "W"
    local drain = CommonGui.format_number(energy_drain) .. "W"
    local total = CommonGui.format_number(energy_input + energy_drain) .. "W"
    CommonGui.create_bold_label(section, {"", {"gui-label.template-energy-input"}, ": ", primary})
    CommonGui.create_bold_label(section, {"", {"gui-label.template-energy-drain"}, ": ", drain})
    CommonGui.create_bold_label(section, {"", {"gui-label.template-total-energy"}, ": ", total})
end

---Adds section describing template outputs
---@param parent LuaGuiElement widget will be added here
---@param dashboard_data DashboardData
local function create_template_outputs_section(parent, dashboard_data)
    local template_name = dashboard_data.template_name
    local outputs = TemplateCompiler.get_outputs(template_name)
    if not next(outputs) then return end

    local section = CommonGui.create_info_element_base(
        parent,
        {"gui-label.template-output"}
    )
    -- table with item and fluid outputs
    local buttons = {}
    for key, count in pairs(outputs) do
        if key ~= "electric_energy" then
            local button_data = CommonGui.assemble_sprite_button_data(key, count)
            table.insert(buttons, button_data)
        end
    end
    CommonGui.create_sprite_button_table(section, buttons)

    -- energy production
    local energy_output = TemplateCompiler.get_energy_production(template_name)
    local energy_out = CommonGui.format_number(energy_output) .. "W"
    CommonGui.create_bold_label(section, {"", {"gui-label.template-energy-output"}, ": ", energy_out})
end

-------------------------------------------------------------------------------
-- GUI CONSTRUCTION
-------------------------------------------------------------------------------

---Creates template dashboard base. Dashboard must be closed when calling this.
---Base consists of elements that are always present in the window.
---@param player LuaPlayer player for which window is created. Assumed to be valid.
local function create_template_dashboard_base(player)
    -- creating base window and "opening" it
    local main_window = CommonGui.create_base_window(
        player,
        PREFIX .. "td-window",
        {"gui-label.template-dashboard"}
    )
    player.opened = main_window

    -- fetching or creating dashboard data in storage for given player
    storage.template_dashboard[player.index] = storage.template_dashboard[player.index] or {}
    local dashboard_data = storage.template_dashboard[player.index]
    dashboard_data.opened = true
    dashboard_data.elements = {}
    dashboard_data.elements.main_window = main_window

    -- invisible container for other frames
    local main_flow = main_window.add{
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
    local left_flow = left_frame.add{type = "flow", direction = "vertical"}
    left_flow.style.vertical_spacing = 12
    create_template_selection_widget(left_flow, dashboard_data)
    create_surface_selection_widget(left_flow, dashboard_data)

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

---Updates data displayed on the right side of interface
---@param dashboard_data DashboardData
local function update_datafield(dashboard_data)
    local datafield = dashboard_data.elements.datafield
    datafield.clear()

    local template_name = dashboard_data.template_name
    local surface_name = dashboard_data.surface_name
    if template_name and not surface_name then
        -- displaying template information
        create_template_construction_cost(datafield, dashboard_data)
        create_template_inputs_section(datafield, dashboard_data)
        create_template_outputs_section(datafield, dashboard_data)
    elseif template_name and surface_name then
        local cluster = ClusterProcessor.get_cluster_by_names(
            template_name,
            surface_name
        )
        ClusterInfo.create_all_cluster_info(datafield, cluster)
    end
end

-------------------------------------------------------------------------------
-- CONTROL ELEMENTS: HANDLER FUNCTIONS
-------------------------------------------------------------------------------

---Handles template searchfield being changed
---@param event EventData.on_gui_text_changed
function TemplateDashboard.process_template_search(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    dashboard_data.template_query = event.element.text
    configure_template_selector(dashboard_data)
end

---Handles template being changed in the selector
---@param event EventData.on_gui_selection_state_changed
function TemplateDashboard.process_template_selector(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    local selector = event.element
    local old_name = dashboard_data.template_name
    local new_name = selector.items[selector.selected_index]

    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        dashboard_data.template_name = nil
        configure_template_selector(dashboard_data)
    else
        dashboard_data.template_name = new_name
    end
    configure_surface_selector(dashboard_data)
    update_datafield(dashboard_data)
end

---Handles surface searchfield being changed
---@param event EventData.on_gui_text_changed
function TemplateDashboard.process_surface_search(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    dashboard_data.surface_query = event.element.text
    configure_surface_selector(dashboard_data)
end

---Handles surface being changed in the selector
---@param event EventData.on_gui_selection_state_changed
function TemplateDashboard.process_surface_selector(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    local selector = event.element
    local old_name = dashboard_data.surface_name
    local new_name = selector.items[selector.selected_index]

    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        dashboard_data.surface_name = nil
        configure_surface_selector(dashboard_data)
    else
        dashboard_data.surface_name = new_name
    end
    configure_template_selector(dashboard_data)
    update_datafield(dashboard_data)
end

-------------------------------------------------------------------------------
-- MAIN LOGIC: OPEN/CLOSE/UPDATE FUNCTIONS
-------------------------------------------------------------------------------

---Opens template dashboard for a given player or closes if already opened.
---@param player LuaPlayer assumed to be valid
local function toggle_template_dashboard(player)
    local dashboard_data = storage.template_dashboard[player.index]

    -- closing the window if it was opened
    if dashboard_data and dashboard_data.opened then
        player.opened = nil
        return
    end

    create_template_dashboard_base(player)
    dashboard_data = storage.template_dashboard[player.index]
    update_datafield(dashboard_data)
end

---Closes template dashboard when player.opened changes from
---dashboard window to something else.
---@param event EventData.on_gui_closed
function TemplateDashboard.process_template_dashboard_gui_closed(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    dashboard_data.opened = nil
    dashboard_data.elements.main_window.destroy()
    dashboard_data.elements = nil
end

---Toggles template dashboard when shortcut bar element is clicked
---@param event EventData.on_lua_shortcut
function TemplateDashboard.process_dashboard_shortcut(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_template_dashboard(player)
end

---Toggles template dashboard when custom hotkey is pressed
---@param event EventData.CustomInputEvent
function TemplateDashboard.process_dashboard_hotkey(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_template_dashboard(player)
end

---After player changes surface with this custom window opened
---player.opened can be assigned nil with window still opened
---So if window should be opened, we set player.opened to it.
---@param event EventData.on_player_changed_surface
function TemplateDashboard.process_player_changed_surface(event)
    local dashboard_data = storage.template_dashboard[event.player_index]
    if not dashboard_data or not dashboard_data.opened then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = dashboard_data.elements.main_window
end

return TemplateDashboard