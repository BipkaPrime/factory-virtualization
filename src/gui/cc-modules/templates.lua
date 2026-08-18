--[[
Helps in handling of control center GUI. Contains definitions, configurators
and handlers for GUI elements that are used in "templates" mode. As well as
all the logic required to operate the window in this mode.

Control center gui in "templates" mode can be used to manage compiled templates.
Rename, delete compiled templates as well as view template data.
--]]

---@class ControlCenterElements additional LuaGuiElements that can be used in "templates" mode
---@field inactive_template_selector LuaGuiElement|nil list-box used for inactive template selection
---@field rename_template_btn LuaGuiElement|nil button used to switch gui into rename_template submode
---@field delete_template_btn LuaGuiElement|nil button used to switch gui into delete_template submode
---@field active_template_selector LuaGuiElement|nil list-box used for active template selection

---@class ControlCenterData additional fields that can be used in "templates" mode
---@field inactive_template_query string|nil search query for inactive template selector
---@field selected_template string|nil display name of selected template
---@field template_submode string|nil submode the gui is currently in
---@field active_template_query string|nil search query for active template selector


local CommonGui = require("src.gui.common")
local TCCManager = require("src.simulation.tcc-manager")


local PREFIX = "FV-"
local CCTemplates = {}

---All possible submodes of control center in "templates" mode.
---Used to handle mutually exclusive GUI states.
local template_submodes = {
    rename_template = "rename_template",
    delete_template = "delete_template",
}

-------------------------------------------------------------------------------
----------- LEFT FRAME CONTROL ELEMENTS: CREATION AND CONFIGURATION -----------
-------------------------------------------------------------------------------

------------------------- INACTIVE TEMPLATE SELECTION -------------------------

---Updates inactive template selector according to gui_data
---@param gui_data ControlCenterData
local function update_inactive_template_selector(gui_data)
    local selector = gui_data.elements.inactive_template_selector
    if not selector or not selector.valid then return end
    local query = gui_data.inactive_template_query
    local options = TCCManager.get_inactive_template_names(query)
    -- sorting options in alphabetical order
    table.sort(options)
    local selected_option = gui_data.selected_template
    -- not disaplaying template if it's active
    if selected_option and TCCManager.is_template_active(selected_option) then
        selected_option = nil
    end
    CommonGui.update_selector(selector, options, selected_option)
end

---Adds selection widget for inactive templates. Widget consists of
---of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_inactive_template_selection_widget(parent, gui_data)
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "cc-inactive-template-search",
        PREFIX .. "cc-inactive-template-selector",
        {"cc-templates.inactive-templates"},
        180
    )
    search.text = gui_data.inactive_template_query or ""
    gui_data.elements.inactive_template_selector = selector
    update_inactive_template_selector(gui_data)
    -- scrolling to selected item
    local selected_index = selector.selected_index
    if selected_index ~= 0 then
        selector.scroll_to_item(selected_index, "top-third")
    end
end

-------------------------------- RENAME BUTTON --------------------------------

---Updates "rename template" button according to gui_data
---@param gui_data ControlCenterData
local function update_rename_template_button(gui_data)
    local button = gui_data.elements.rename_template_btn
    if not button or not button.valid then return end
    -- button is enabled if template is selected
    button.enabled = not not gui_data.selected_template
    -- button is toggled if gui is in "rename_template" submode
    button.toggled = (gui_data.template_submode == template_submodes.rename_template)
end

---Adds "rename template" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_rename_template_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-rename-template",
        caption = {"cc-templates.rename-template-btn"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.rename_template_btn = button
    update_rename_template_button(gui_data)
end

-------------------------------- DELETE BUTTON --------------------------------

---Updates "delete template" button according to gui_data
---@param gui_data ControlCenterData
local function update_delete_template_button(gui_data)
    local button = gui_data.elements.delete_template_btn
    if not button or not button.valid then return end
    -- button is enabled if template is selected
    button.enabled = not not gui_data.selected_template
    -- button is toggled if gui is in "delete_template" submode
    button.toggled = (gui_data.template_submode == template_submodes.delete_template)
end

---Adds "delete template" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_delete_template_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-delete-template",
        caption = {"cc-templates.delete-template-btn"},
        style = "red_button",
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.delete_template_btn = button
    update_delete_template_button(gui_data)
end

-------------------------- ACTIVE TEMPLATE SELECTION --------------------------

---Updates active template selector according to gui_data
---@param gui_data ControlCenterData
local function update_active_template_selector(gui_data)
    local selector = gui_data.elements.active_template_selector
    if not selector or not selector.valid then return end
    local query = gui_data.active_template_query
    local options = TCCManager.get_active_template_names(query)
    -- sorting options in alphabetical order
    table.sort(options)
    local selected_option = gui_data.selected_template
    -- not disaplaying template if it's inactive
    if selected_option and TCCManager.is_template_inactive(selected_option) then
        selected_option = nil
    end
    CommonGui.update_selector(selector, options, selected_option)
end

---Adds selection widget for active templates. Widget consists of
---of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_active_template_selection_widget(parent, gui_data)
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "cc-active-template-search",
        PREFIX .. "cc-active-template-selector",
        {"cc-templates.active-templates"},
        180
    )
    search.text = gui_data.active_template_query or ""
    gui_data.elements.active_template_selector = selector
    update_active_template_selector(gui_data)
    -- scrolling to selected item
    local selected_index = selector.selected_index
    if selected_index ~= 0 then
        selector.scroll_to_item(selected_index, "top-third")
    end
end

-------------------------------------------------------------------------------
---------------------------- RIGHT FRAME ELEMENTS -----------------------------
-------------------------------------------------------------------------------

--------------------------- SELECTED TEMPLATE INFO ----------------------------


---------------------------- TEMPLATE ROUTING INFO ----------------------------


--------------------------- TEMPLATE RENAME SECTION ---------------------------


--------------------------- TEMPLATE DELETE SECTION ---------------------------


-------------------------------------------------------------------------------
------------------------ GUI CONSTRUCTION AND UPDATES -------------------------
-------------------------------------------------------------------------------

---Constructs left side of templates mode interface
---@param gui_data ControlCenterData
function CCTemplates.construct_left_side(gui_data)
    local left_frame = gui_data.elements.left_frame
    add_inactive_template_selection_widget(left_frame, gui_data)
    add_rename_template_button(left_frame, gui_data)
    add_delete_template_button(left_frame, gui_data)
    local spacer = left_frame.add{type = "flow"}
    spacer.style.vertically_stretchable = true
    add_active_template_selection_widget(left_frame, gui_data)
end

---Constructs right side of templates mode interface
---@param gui_data ControlCenterData
function CCTemplates.construct_right_side(gui_data)
    local right_frame = gui_data.elements.right_frame
    
end

function CCTemplates.fast_interface_updater(gui_data)

end

function CCTemplates.slow_interface_updater(gui_data)

end

-------------------------------------------------------------------------------
---------------------------- GUI STATE MANAGEMENT -----------------------------
-------------------------------------------------------------------------------

---Updates all elements in the left frame, rebuilds the right frame
---@param gui_data ControlCenterData
local function update_left_rebuild_right(gui_data)
    update_inactive_template_selector(gui_data)
    update_rename_template_button(gui_data)
    update_delete_template_button(gui_data)
    update_active_template_selector(gui_data)
    gui_data.elements.right_frame.clear()
    CCTemplates.construct_right_side(gui_data)
end

---Used to set template submode to provided value. If provided value
---matches with current submode, it's cleared instead.
---@param gui_data ControlCenterData
---@param new_submode string|nil submode value to set
local function toggle_template_submode(gui_data, new_submode)
    if gui_data.template_submode == new_submode then
        gui_data.template_submode = nil
    else
        gui_data.template_submode = new_submode
    end
    update_left_rebuild_right(gui_data)
end

---Used to set selected template to new value. If provided value
---matches with current selection, it is cleared instead.
---@param gui_data ControlCenterData
---@param new_selection string|nil
local function toggle_template_selection(gui_data, new_selection)
    local old_selection = gui_data.selected_template
    if old_selection == new_selection then
        gui_data.selected_template = nil
    else
        gui_data.selected_template = new_selection
    end
    -- when template selection changes, submode is reset as well
    gui_data.template_submode = nil
    update_left_rebuild_right(gui_data)
end

-------------------------------------------------------------------------------
-------------------- LEFT FRAME CONTROL ELEMENTS: HANDLERS --------------------
-------------------------------------------------------------------------------

------------------------- INACTIVE TEMPLATE SELECTION -------------------------

---Handles inactive template textfield being changed
---@param event EventData.on_gui_text_changed
function CCTemplates.handle_inactive_template_search(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.inactive_template_query = event.text
    update_inactive_template_selector(gui_data)
end

---Handles inactive template selector being changed
---@param event EventData.on_gui_selection_state_changed
function CCTemplates.handle_inactive_template_selector(event)
    local selector = event.element
    local new_selection = selector.get_item(selector.selected_index)
    toggle_template_selection(
        storage.control_center[event.player_index],
        ---@diagnostic disable-next-line
        new_selection
    )
end

-------------------------------- RENAME BUTTON --------------------------------

---Handles "rename template" button being pressed
---@param event EventData.on_gui_click
function CCTemplates.handle_rename_template_button(event)
    toggle_template_submode(
        storage.control_center[event.player_index],
        template_submodes.rename_template
    )
end

-------------------------------- DELETE BUTTON --------------------------------

---Handles "delete template" button being pressed
---@param event EventData.on_gui_click
function CCTemplates.handle_delete_template_button(event)
    toggle_template_submode(
        storage.control_center[event.player_index],
        template_submodes.delete_template
    )
end

-------------------------- ACTIVE TEMPLATE SELECTION --------------------------

---Handles active template textfield being changed
---@param event EventData.on_gui_text_changed
function CCTemplates.handle_active_template_search(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.active_template_query = event.text
    update_active_template_selector(gui_data)
end

---Handles active template selector being changed
---@param event EventData.on_gui_selection_state_changed
function CCTemplates.handle_active_template_selector(event)
    local selector = event.element
    local new_selection = selector.get_item(selector.selected_index)
    toggle_template_selection(
        storage.control_center[event.player_index],
        ---@diagnostic disable-next-line
        new_selection
    )
end

-------------------------------------------------------------------------------
------------------- RIGHT FRAME CONTROL ELEMENTS: HANDLERS --------------------
-------------------------------------------------------------------------------

--------------------------- SELECTED TEMPLATE INFO ----------------------------


---------------------------- TEMPLATE ROUTING INFO ----------------------------


--------------------------- TEMPLATE RENAME SECTION ---------------------------


--------------------------- TEMPLATE DELETE SECTION ---------------------------


return CCTemplates