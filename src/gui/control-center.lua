--[[


--]]

---@class ControlCenterElements base elements: these are always present
---@field main_window LuaGuiElement reference to control center main window
---@field surface_mode_btn LuaGuiElement top panel button used to switch the window to surface mode
---@field template_mode_btn LuaGuiElement top panel button used to switch the window to template mode
---@field cluster_mode_btn LuaGuiElement top panel button used to switch the window to cluster mode
---@field left_frame LuaGuiElement "flow" type element used to display other elements on the left side
---@field right_frame LuaGuiElement "flow" type element used to display other elements on the right side

---@class ControlCenterData base fields
---@field opened true|nil true if window is currently on the screen
---@field mode string|nil current opened mode of the window (for example "surfaces")
---@field elements ControlCenterElements


local CCSurfaces = require("src.gui.cc-modules.surfaces")
local CCTemplates = require("src.gui.cc-modules.templates")
local CCClusters = require("src.gui.cc-modules.clusters")
local CommonGui = require("src.gui.common")
local GuiUpdater = require("src.gui.updater")


local PREFIX = "FV-"
local ControlCenter = {}


------------------------------ TOP PANEL BUTTONS ------------------------------

---Table with all possible control center modes
local control_center_modes = {
    surfaces = "surfaces",
    templates = "templates",
    clusters = "clusters"
}

---Contains configuration data for buttons displayed on the top panel
local top_panel_buttons = {
    {
        mode = "surfaces",
        name = PREFIX .. "cc-surface-mode",
        caption = {"cc-general.surfaces"},
        elem_name = "surface_mode_btn",
    },
    {
        mode = "templates",
        name = PREFIX .. "cc-template-mode",
        caption = {"cc-general.templates"},
        elem_name = "template_mode_btn",
    },
    {
        mode = "clusters",
        name = PREFIX .. "cc-cluster-mode",
        caption = {"cc-general.clusters"},
        elem_name = "cluster_mode_btn",
    },
}

---Configures top panel buttons accoding to selected window mode
---@param gui_data ControlCenterData
local function configure_top_panel_buttons(gui_data)
    local elements = gui_data.elements
    local mode = gui_data.mode
    for _, config in ipairs(top_panel_buttons) do
        local button = elements[config.elem_name]
        if button and button.valid then
            button.toggled = (config.mode == mode)
        end
    end
end

---Creates a window mode selection buttons in the top panel
---@param parent LuaGuiElement buttons will be added here
---@param gui_data ControlCenterData
local function create_top_panel_buttons(parent, gui_data)
    local elements = gui_data.elements
    for _, config in ipairs(top_panel_buttons) do
        local button = parent.add{
            type = "button",
            name = config.name,
            caption = config.caption,
        }
        elements[config.elem_name] = button
        button.style.horizontally_stretchable = true
    end
    configure_top_panel_buttons(gui_data)
end

--------------------------------- WINDOW BASE ---------------------------------

---Constructs control center window base on the screen of a given player
---@param player LuaPlayer assumed to be valid
local function create_control_center_base(player)
    -- creating base window and "opening" it
    local main_window = CommonGui.create_base_window(
        player,
        PREFIX .. "control-center-window",
        {"cc-general.title"}
    )
    player.opened = main_window

    -- getting or creating gui data for given player
    local player_index = player.index
    local control_center = storage.control_center
    local gui_data = control_center[player_index] or {}
    control_center[player_index] = gui_data
    -- mandatory fields of gui_data
    gui_data.opened = true
    ---@diagnostic disable-next-line
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
    create_top_panel_buttons(top_panel_flow, gui_data)

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

-------------------------- WINDOW MODE SELECTION-------------------------------

---Populates left and right frames according to mode selection
---@param gui_data ControlCenterData
local function populate_control_center_base(gui_data)
    local mode = gui_data.mode
    if mode == control_center_modes.surfaces then
        CCSurfaces.construct_left_side(gui_data)
        CCSurfaces.construct_right_side(gui_data)
    end
    if mode == control_center_modes.templates then
        CCTemplates.construct_left_side(gui_data)
        CCTemplates.construct_right_side(gui_data)
    end
    if mode == control_center_modes.clusters then
        CCClusters.construct_left_side(gui_data)
        CCClusters.construct_right_side(gui_data)
    end
end

---Sets gui_data.mode to provided value or clears it if new_val == old_val.
---@param gui_data ControlCenterData
---@param new_mode string
local function toggle_control_center_mode(gui_data, new_mode)
    local old_mode = gui_data.mode
    if old_mode == new_mode then
        gui_data.mode = nil
    else
        gui_data.mode = new_mode
    end
    -- updating top panel buttons to match new state
    configure_top_panel_buttons(gui_data)

    -- clearing both left and right frames when mode changes
    local elements = gui_data.elements
    elements.left_frame.clear()
    elements.right_frame.clear()
    populate_control_center_base(gui_data)
end

---Handles "surfaces" mode button being pressed
---@param event EventData.on_gui_click
function ControlCenter.handle_surface_mode_button(event)
    toggle_control_center_mode(
        storage.control_center[event.player_index],
        control_center_modes.surfaces
    )
end

---Handles "templates" mode button being pressed
---@param event EventData.on_gui_click
function ControlCenter.handle_template_mode_button(event)
    toggle_control_center_mode(
        storage.control_center[event.player_index],
        control_center_modes.templates
    )
end

---Handles "clusters" mode button being pressed
---@param event EventData.on_gui_click
function ControlCenter.handle_cluster_mode_button(event)
    toggle_control_center_mode(
        storage.control_center[event.player_index],
        control_center_modes.clusters
    )
end

----------------------------- TIME-BASED UPDATES ------------------------------

---@type table<string, fun(gui_data: ControlCenterData, update_cycle: integer)>
local update_router = {
    [control_center_modes.surfaces] = CCSurfaces.on_tick_updater,
    [control_center_modes.templates] = CCTemplates.on_tick_updater,
}

---Used for fast time-based control center updates. Called about once a tick
---@param gui_data ControlCenterData
local function on_tick_updater(gui_data, update_cycle)
    local handler = update_router[gui_data.mode]
    if not handler then return end
    handler(gui_data, update_cycle)
end

GuiUpdater.add_schema("control_center", on_tick_updater)

--------------------------- WINDOW OPEN/CLOSE LOGIC ---------------------------

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
    populate_control_center_base(gui_data)
    -- registering window for time-based updates
    GuiUpdater.register_gui("control_center", gui_data, player)
end

---Closes control center window when event is triggered
---@param event EventData.on_gui_closed
function ControlCenter.handle_window_closed(event)
    GuiUpdater.close_window(event.player_index)
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