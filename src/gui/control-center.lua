--[[


--]]

---
---@class ControlCenterElements base elements: these are always present
---@field main_window LuaGuiElement reference to control center main window
---@field surface_mode_btn LuaGuiElement top panel button used to switch the window to surface mode
---@field template_mode_btn LuaGuiElement top panel button used to switch the window to template mode
---@field cluster_mode_btn LuaGuiElement top panel button used to switch the window to cluster mode
---@field left_frame LuaGuiElement "flow" type element used to display other elements on the left side
---@field right_frame LuaGuiElement "flow" type element used to display other elements on the right side

---@class ControlCenterElements surface mode elements: these can only be present in surface mode
---@field new_surface_btn LuaGuiElement button that is used to open vsurface creation interface
---@field delete_surface_btn LuaGuiElement button that is used to delete selected idle vsurface
---@field idle_surface_search LuaGuiElement textfield above idle surface selector
---@field idle_surface_selector LuaGuiElement selector displaying idle vsurfaces
---@field compiling_surface_search LuaGuiElement textfield above compiling surface selector
---@field compiling_surface_selector LuaGuiElement selector displaying compiling vsurfaces
---@field start_compilation_btn LuaGuiElement start compilation button on the left


---@class ControlCenterData base fields
---@field opened true|nil true if window is currently on the screen
---@field mode string|nil current opened mode of the window (for example "surfaces")
---@field elements ControlCenterElements

---@class ControlCenterData surface mode fields
---@field surface_submode string|nil used to handle mutually exclusive gui states
---@field selected_vsurface string|nil name of selected vsurface
---@field idle_surface_query string|nil last user input into idle surfaces textfield
---@field compiling_surface_query string|nil last user input into compiling surfaces textfield



local CommonGui = require("src.gui.common")
local VSurfaceManager = require("src.world.vsurface-manager")


local PREFIX = "FV-"
local ControlCenter = {}

-------------------------------------------------------------------------------
-- SURFACE MODE CONTROL ELEMENTS
-------------------------------------------------------------------------------

-- TODO: add gui_data "submode" field, to handle mutually exclusive gui states
-- like "new surface button pressed", "start compilation button pressed",
-- "delete selected button pressed", "stop compilation button pressed"
---New surface button should create vsurface creation interface on the right side,
---start compilation button should create start compilation interface on the right side,
---same goes for for delete surface and stop compilation: they should create confirmation
---interfaces on the right side. Only one of these can be present at a time.
---It's important to note that selected vsurface is also mutually exclusive with 
---"new surface button pressed", but not with others. When selected vsurface changes,
---submode should be cleared. When submode is set to new surface pressed, selected vsurface
---should be cleared.

---Table with all possible surface submode values
local surface_submodes = {
    new_surface = "new_surface",
    delete_selected = "delete_selected",
    start_compilation = "start_compilation",
    stop_compilation = "stop_compilation",
}

local SurfaceControlElem = {}

---Configures all control elements that are submode-sensitive
---@param gui_data ControlCenterData
local function configure_surface_submode_sensitive_controls(gui_data)
    SurfaceControlElem.configure_new_surface_button(gui_data)
    SurfaceControlElem.configure_surface_delete_button(gui_data)
    SurfaceControlElem.configure_compilation_start_button(gui_data)
    SurfaceControlElem.configure_compilation_stop_button(gui_data)
end

-------------------------------------------------------------------------------

---Configures "create new vsurface" button according to gui_data
---@param gui_data ControlCenterData
function SurfaceControlElem.configure_new_surface_button(gui_data)
    local button = gui_data.elements.new_surface_btn
    if not button.valid then return end
    -- button is toggled if gui in "new_surface" submode
    button.toggled = (gui_data.surface_submode == surface_submodes.new_surface)
end

---Adds "create new vsurface" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function create_new_surface_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-new-surface-btn",
        caption = {"control-center.create-new-vsurface"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.new_surface_btn = button
    SurfaceControlElem.configure_new_surface_button(gui_data)
end

---Handles "create new vsurface" button being pressed
---@param event EventData.on_gui_click
function ControlCenter.handle_new_surface_button(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]

    if gui_data.surface_submode == surface_submodes.new_surface then
        -- "new_surface" submode is active, disabling it
        gui_data.surface_submode = nil
    else
        -- "new_surface" submode is not active, activating it
        gui_data.surface_submode = surface_submodes.new_surface
        -- "new_surface" submode is mutually exclusive with vsurface selection
        gui_data.selected_vsurface = nil
    end

    -- calling all configuration functions
    for _, configurator in pairs(SurfaceControlElem) do
        configurator(gui_data)
    end
    -- clearing all elements in the right frame in preparation
    -- of displaying new surface creation elements.
    gui_data.elements.right_frame.clear()
end

-------------------------------------------------------------------------------

---Configures idle vsurface selector on the left side of GUI
---@param gui_data ControlCenterData
local function configure_idle_surface_selector(gui_data)
    local selector = gui_data.elements.idle_surface_selector
    if not selector.valid then return end
    local options = VSurfaceManager.get_idle_vsurfaces()
    local query = gui_data.idle_surface_query
    local selected = gui_data.selected_vsurface
    -- if selected surface is not idle, it's not displayed
    if not VSurfaceManager.is_idle(selected) then
        selected = nil
    end
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures idle surface selector and searchfield above
---@param gui_data ControlCenterData
function SurfaceControlElem.configure_idle_surface_selection_widget(gui_data)
    local search = gui_data.elements.idle_surface_search
    if not search.valid then return end
    search.text = gui_data.idle_surface_query or ""
    configure_idle_surface_selector(gui_data)
end

---Adds selection widget for idle vsurfaces to given parent element. Widget consists of
---of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function create_idle_surface_selection_widget(parent, gui_data)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "cc-idle-surface-search",
        PREFIX .. "cc-idle-surface-selector",
        {"control-center.idle-vsurfaces"}
    )
    local elements = gui_data.elements
    elements.idle_surface_search = search
    elements.idle_surface_selector = selector
    SurfaceControlElem.configure_idle_surface_selection_widget(gui_data)
end

---Handles idle surface textfield being changed
---@param event EventData.on_gui_text_changed
function ControlCenter.handle_idle_surface_search(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.idle_surface_query = event.text
    configure_idle_surface_selector(gui_data)
end

---Handles idle surface selector being changed
---@param event EventData.on_gui_selection_state_changed
function ControlCenter.handle_idle_surface_selector(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    local selector = event.element
    local old_name = gui_data.selected_vsurface
    local new_name = selector.items[selector.selected_index]

    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        gui_data.selected_vsurface = nil
        configure_idle_surface_selector(gui_data)
    else
        ---@diagnostic disable-next-line
        gui_data.selected_vsurface = new_name
    end
    -- submode should be cleared when selected vsurface changes
    gui_data.surface_submode = nil
    configure_surface_submode_sensitive_controls(gui_data)
    SurfaceControlElem.configure_compiling_surface_selection_widget(gui_data)

    -- clearing all elements in the right frame
    gui_data.elements.right_frame.clear()
end

-------------------------------------------------------------------------------

---Configures "delete selected vsurface" button according to gui_data
---@param gui_data ControlCenterData 
function SurfaceControlElem.configure_surface_delete_button(gui_data)
    local button = gui_data.elements.delete_surface_btn
    if not button.valid then return end
    -- button is enabled only when surface is selected and idle
    local surface_name = gui_data.selected_vsurface
    button.enabled = VSurfaceManager.is_idle(surface_name)
    -- button is toggled if gui in "delete_selected" submode
    button.toggled = (gui_data.surface_submode == surface_submodes.delete_selected)
end

---Adds "delete selected vsurface" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function create_surface_delete_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-delete-surface-btn",
        caption = {"control-center.delete-selected-vsurface"},
        style = "red_button",
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.delete_surface_btn = button
    SurfaceControlElem.configure_surface_delete_button(gui_data)
end

---Handles "delete selected vsurface" button being pressed
---@param event EventData.on_gui_click
function ControlCenter.handle_surface_delete_button(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]

    -- toggling "delete_selected" submode
    if gui_data.surface_submode == surface_submodes.delete_selected then
        -- "delete_selected" submode is active, disabling it
        gui_data.surface_submode = nil
    else
        -- "delete_selected" submode is not active, activating it
        gui_data.surface_submode = surface_submodes.delete_selected
    end

    -- updating gui state
    configure_surface_submode_sensitive_controls(gui_data)
    -- clearing all elements in the right frame
    gui_data.elements.right_frame.clear()
end

-------------------------------------------------------------------------------

---Configures "start compilation" button according to gui_data
---@param gui_data ControlCenterData
function SurfaceControlElem.configure_compilation_start_button(gui_data)
    local button = gui_data.elements.start_compilation_btn
    if not button.valid then return end
    button.toggled = not not gui_data.start_compilation_pressed
end

---Adds "start compilation" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function create_compilation_start_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-start-compilation-btn",
        caption = {"control-center.start-compilation"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.start_compilation_btn = button
    SurfaceControlElem.configure_compilation_start_button(gui_data)
end

---Handles "start compilation" button being pressed
---@param event EventData.on_gui_click
function ControlCenter.handle_compilation_start_button(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.start_compilation_pressed = true
    gui_data.new_surface_pressed = nil


    -- calling all configuration functions
    for _, configurator in pairs(SurfaceControlElem) do
        configurator(gui_data)
    end
    -- clearing all elements in the right frame in preparation
    -- of displaying new surface creation elements.
    gui_data.elements.right_frame.clear()
end


-------------------------------------------------------------------------------

---Configures compiling vsurface selector on the left side of GUI
---@param gui_data ControlCenterData
local function configure_compiling_surface_selector(gui_data)
    local selector = gui_data.elements.compiling_surface_selector
    if not selector.valid then return end
    local options = VSurfaceManager.get_compiling_vsurfaces()
    local query = gui_data.compiling_surface_query
    local selected = gui_data.selected_vsurface
    -- if selected surface is not compiling, it's not displayed
    if not VSurfaceManager.is_compiling(selected) then
        selected = nil
    end
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures compiling surface selector and searchfield above
---@param gui_data ControlCenterData
function SurfaceControlElem.configure_compiling_surface_selection_widget(gui_data)
    local search = gui_data.elements.compiling_surface_search
    if not search.valid then return end
    search.text = gui_data.compiling_surface_query or ""
    configure_compiling_surface_selector(gui_data)
end

---Adds selection widget for compiling vsurfaces to given parent element. Widget consists of
---of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function create_compiling_surface_selection_widget(parent, gui_data)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "cc-compiling-surface-search",
        PREFIX .. "cc-compiling-surface-selector",
        {"control-center.compiling-vsurfaces"}
    )
    local elements = gui_data.elements
    elements.compiling_surface_search = search
    elements.compiling_surface_selector = selector
    SurfaceControlElem.configure_compiling_surface_selection_widget(gui_data)
end

---Handles compiling surface textfield being changed
---@param event EventData.on_gui_text_changed
function SurfaceControlElem.handle_compiling_surface_search(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.compiling_surface_query = event.text
    configure_compiling_surface_selector(gui_data)
end

---Handles compiling surface selector being changed
---@param event EventData.on_gui_selection_state_changed
function SurfaceControlElem.handle_compiling_surface_selector(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    local selector = event.element
    local old_name = gui_data.selected_vsurface
    local new_name = selector.items[selector.selected_index]

    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        gui_data.selected_vsurface = nil
        configure_compiling_surface_selector(gui_data)
    else
        ---@diagnostic disable-next-line
        gui_data.selected_vsurface = new_name
        gui_data.new_surface_pressed = nil
        SurfaceControlElem.configure_new_surface_button(gui_data)
    end

    SurfaceControlElem.configure_idle_surface_selection_widget(gui_data)
    SurfaceControlElem.configure_surface_delete_button(gui_data)
    SurfaceControlElem.configure_compilation_start_button(gui_data)
    SurfaceControlElem.configure_compilation_stop_button(gui_data)
    -- clearing all elements in the right frame
    gui_data.elements.right_frame.clear()
end

-------------------------------------------------------------------------------

function SurfaceControlElem.configure_compilation_stop_button(gui_data)

end

local function create_compilation_stop_button(parent, gui_data)

end

function ControlCenter.handle_compilation_stop_button(event)

end


-------------------------------------------------------------------------------
-- WINDOW CONSTRUCTION
-------------------------------------------------------------------------------

---Contains configuration data for buttons displayed on the top panel
local top_panel_buttons = {
    {
        mode = "surfaces",
        name = PREFIX .. "cc-surface-mode",
        caption = {"control-center.surfaces"},
        elem_name = "surface_mode_btn",
    },
    {
        mode = "templates",
        name = PREFIX .. "cc-template-mode",
        caption = {"control-center.templates"},
        elem_name = "template_mode_btn",
    },
    {
        mode = "clusters",
        name = PREFIX .. "cc-cluster-mode",
        caption = {"control-center.clusters"},
        elem_name = "cluster_mode_btn",
    },
}

---Creates a window mode selection buttons in the top panel
---@param parent LuaGuiElement buttons will be added here
---@param gui_data ControlCenterData
local function create_top_panel_buttons(parent, gui_data)
    local elements = gui_data.elements
    local mode = gui_data.mode
    for _, config in ipairs(top_panel_buttons) do
        local button = parent.add{
            type = "button",
            name = config.name,
            caption = config.caption,
        }
        button.toggled = (mode == config.mode)
        elements[config.elem_name] = button
        button.style.horizontally_stretchable = true
    end
end

---Constructs control center window base on the screen of a given player
---@param player LuaPlayer assumed to be valid
local function create_control_center_base(player)
    -- creating base window and "opening" it
    local main_window = CommonGui.create_base_window(
        player,
        PREFIX .. "control-center-window",
        {"gui-label.control-center"}
    )
    player.opened = main_window

    -- getting or creating gui data for given player
    local player_index = player.index
    local control_center = storage.control_center
    local gui_data = control_center[player_index] or {}
    control_center[player_index] = gui_data
    -- mandatory fields of gui_data
    gui_data.opened = true
    gui_data.elements = {main_window = main_window}

    -- top panel: window mode selection
    local top_panel = main_window.add{
        type = "frame",
        direction = "horizontal",
        style = "inside_deep_frame"
    }
    local top_panel_style = top_panel.style
    top_panel_style.padding = 2
    top_panel_style.bottom_margin = 12
    local top_panel_flow = top_panel.add{
        type = "flow",
        direction = "horizontal"
    }
    top_panel_flow.style.horizontal_spacing = 3
    create_top_panel_buttons(top_panel_flow, gui_data.elements)

    local main_flow = main_window.add{
        type = "flow",
        direction="horizontal",
    }
    local main_flow_style = main_flow.style
    main_flow_style.height = 600

    -- left half of interface: control elements
    local left_frame = main_flow.add{
        type="frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    left_frame.style.right_margin = 12
    local left_flow = left_frame.add{
        type = "flow",
        direction = "vertical"
    }
    local left_flow_style = left_flow.style
    left_flow_style.width = 200
    left_flow_style.vertically_stretchable = true
    left_flow_style.vertical_spacing = 12
    gui_data.elements.left_frame = left_flow

    -- right half of interface: info elements
    local right_frame = main_flow.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical"
    }
    local right_pane = right_frame.add{
        type = "scroll-pane",
        vertical_scroll_policy = "always",
    }
    local right_pane_style = right_pane.style
    right_pane_style.width = 444
    right_pane_style.vertically_stretchable = true

    gui_data.elements.right_frame = right_pane
    return gui_data
end

---Constructs surface mode interface
---@param gui_data ControlCenterData
local function create_surface_mode_interface(gui_data)
    local left_frame = gui_data.elements.left_frame


end

-------------------------------------------------------------------------------
-- WINDOW MODE SELECTION
-------------------------------------------------------------------------------

function ControlCenter.handle_surface_mode_button(event)

end

function ControlCenter.handle_template_mode_button(event)

end

function ControlCenter.handle_cluster_mode_button(event)

end

-------------------------------------------------------------------------------
-- OPEN/CLOSE LOGIC
-------------------------------------------------------------------------------

---Opens/closes control center window depending on its current state
---@param player LuaPlayer assumed to be valid
local function toggle_control_center_window(player)
    local player_index = player.index
    local gui_data = storage.control_center[player_index]

    -- closing the window if it was opened
    if gui_data and gui_data.opened then
        player.opened = nil
        return
    end

    gui_data = create_control_center_base(player)
    -- TODO: add elements
end

---Closes control center window when event is triggered
---@param event EventData.on_gui_closed
function ControlCenter.handle_window_closed(event)
    local gui_data = storage.control_center[event.player_index]
    gui_data.opened = nil
    gui_data.elements.main_window.destroy()
    gui_data.elements = nil
end

---Toggles control center window when shortcut bar element is clicked
---@param event EventData.on_lua_shortcut
function ControlCenter.handle_shortcut(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_control_center_window(player)
end

---Toggles control center window when hotkey is pressed
---@param event EventData.CustomInputEvent
function ControlCenter.handle_hotkey(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_control_center_window(player)
end

return ControlCenter