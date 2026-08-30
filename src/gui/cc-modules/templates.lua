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
---@field confirm_template_rename_btn LuaGuiElement|nil button used to confirm template rename
---@field confirm_template_rename_label LuaGuiElement|nil label above confirm rename button
---@field template_routing_table LuaGuiElement|nil table used to display template routing
---@field template_routing_labels LuaGuiElement[]|nil contains all template routing labels 

---@class ControlCenterData additional fields that can be used in "templates" mode
---@field inactive_template_query string|nil search query for inactive template selector
---@field selected_template string|nil display name of selected template
---@field template_submode string|nil submode the gui is currently in
---@field active_template_query string|nil search query for active template selector
---@field template_rename_name string|nil new template name when renaming template


local CommonGui = require("src.gui.common")
local TCCManager = require("src.simulation.tcc-manager")
local ClusterProcessor = require("src.simulation.cluster-processor")


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
    if TCCManager.is_template_active(selected_option) then
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
    CommonGui.scroll_to_selection(selector)
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
    if TCCManager.is_template_inactive(selected_option) then
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
    CommonGui.scroll_to_selection(selector)
end

-------------------------------------------------------------------------------
---------------------------- RIGHT FRAME ELEMENTS -----------------------------
-------------------------------------------------------------------------------

------------------------------- TEMPLATE INPUTS -------------------------------

---Constructs a table with sprite button data from template buffer entry.
---Does not handle "electric_energy" energy key: it's not displayed as button.
---@param buffer_key BufferKeyString
---@param count number|nil number displayed on the button
---@return SpriteButtonData
local function construct_sprite_button_data(buffer_key, count)
    ---@type SpriteButtonData
    local data = {}
    data.count = count
    -- looking for "//" seperator in buffer key
    local start_idx, stop_idx = string.find(buffer_key, "//", 1, true)
    if start_idx then
        -- handling item key type: "name//quality"
        local name = string.sub(buffer_key, 1, start_idx - 1)
        local quality = string.sub(buffer_key, stop_idx + 1)
        data.sprite = "item/" .. name
        data.quality = quality
        ---@diagnostic disable-next-line
        data.tooltip = {"?", {"item-name." .. name}, {"entity-name." .. name}}
    else
        -- handling fluid key type "name"
        data.sprite = "fluid/" .. buffer_key
        data.tooltip = {"fluid-name." .. buffer_key}
    end
    return data
end

---Adds a sprite button table to given parent element displaying contents of buffer.
---@param parent LuaGuiElement
---@param buffer table<BufferKeyString, number>
local function add_sprite_button_table(parent, buffer)
    -- sprite button table for item and fluid inputs
    local btn_table = CommonGui.add_sprite_button_table(parent)
    local buttons_data = {}
    for buffer_key, count in pairs(buffer) do
        if buffer_key ~= "electric_energy" then
            local btn_data = construct_sprite_button_data(buffer_key, count)
            table.insert(buttons_data, btn_data)
        end
    end
    CommonGui.update_sprite_button_table(btn_table, {}, buttons_data)
end

---Adds a section that displays template inputs.
---This element does not need updates
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_template_inputs_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-templates.input-per-craft"}
    )
    -- sprite button table for item and fluid inputs
    local tmpl_name = gui_data.selected_template
    local inputs, energy_drain = TCCManager.get_template_inputs(tmpl_name)
    add_sprite_button_table(section, inputs)

    -- labels describing energy demand
    local flow = section.add{type = "flow", direction = "vertical"}
    flow.style.vertical_spacing = 0
    -- total energy input label
    local total_energy = (inputs.electric_energy or 0) + energy_drain
    local total_fmt = CommonGui.large_number_to_string(total_energy)
    local total_caption = {"cc-templates.input-energy", total_fmt}
    flow.add{type = "label", caption = total_caption}
    -- energy drain label
    local drain_fraction = (total_energy ~= 0) and (energy_drain / total_energy) or 0
    local drain_fmt = CommonGui.large_number_to_string(energy_drain)
    local percent_fmt = CommonGui.number_to_string(drain_fraction * 100, 2)
    local drain_caption = {"cc-templates.energy-drain", drain_fmt, percent_fmt}
    flow.add{type = "label", caption = drain_caption}
end

------------------------------ TEMPLATE OUTPUTS -------------------------------

---Adds a section that displays template outputs.
---This element does not need updates
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_template_outputs_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-templates.output-per-craft"}
    )
    -- sprite button table for item and fluid outputs
    local tmpl_name = gui_data.selected_template
    local outputs = TCCManager.get_template_outputs(tmpl_name)
    add_sprite_button_table(section, outputs)

    local energy_output = outputs["electric_energy"] or 0
    local energy_fmt = CommonGui.large_number_to_string(energy_output)
    local energy_caption = {"cc-templates.output-energy", energy_fmt}
    section.add{type = "label", caption = energy_caption}
end

------------------------- TEMPLATE CONSTRUCTION COST --------------------------

---Adds a section that displays template construction cost.
---This element does not need updates
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_template_build_cost_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-templates.construction-cost"}
    )
    -- sprite button table for building materials
    local tmpl_name = gui_data.selected_template
    local build_cost = TCCManager.get_template_building_cost(tmpl_name)
    add_sprite_button_table(section, build_cost)
end


--------------------------- TEMPLATE ROUTING TABLE ----------------------------

local yes_caption = {"cc-templates.true-marker"}
local no_caption = {"cc-templates.false-marker"}

---Helps in template routing table update. Updates one table row.
---@param routing_table LuaGuiElement
---@param labels LuaGuiElement[]
---@param used_labels integer
---@param cluster_name string
---@param is_transmit boolean
---@param is_receive boolean
---@return integer used_labels
local function fill_template_routing_row(
    routing_table,
    labels,
    used_labels,
    cluster_name,
    is_transmit,
    is_receive
)
    if #labels > used_labels then
        -- there are enough labels: updating existing
        labels[used_labels + 1].caption = cluster_name
        labels[used_labels + 2].caption = is_transmit and yes_caption or no_caption
        labels[used_labels + 3].caption = is_receive and yes_caption or no_caption
    else
        -- there are not enough labels: creating new ones
        table.insert(
            labels,
            routing_table.add{
                type = "label",
                caption = cluster_name
            }
        )
        table.insert(
            labels,
            routing_table.add{
                type = "label",
                caption = is_transmit and yes_caption or no_caption
            }
        )
        table.insert(
            labels,
            routing_table.add{
                type = "label",
                caption = is_receive and yes_caption or no_caption
            }
        )
    end
    return used_labels + 3
end

---Updates section used to display template routing
---@param gui_data ControlCenterData
local function update_template_routing_table(gui_data)
    local routing_table = gui_data.elements.template_routing_table
    if not routing_table or not routing_table.valid then return end
    -- all labels are considered to be valid as long as routing table is
    ---@type LuaGuiElement[]
    local labels = gui_data.elements.template_routing_labels
    local used_labels = 0

    local template_name = gui_data.selected_template
    local transmit_uuids = TCCManager.get_transmit_cluster_uuids(template_name)
    local receive_uuids = TCCManager.get_receive_cluster_uuids(template_name)

    -- converting cluster uuids to cluster names
    ClusterProcessor.convert_to_cluster_names(transmit_uuids)
    ClusterProcessor.convert_to_cluster_names(receive_uuids)
    local transmit_names = transmit_uuids
    local receive_names = receive_uuids

    table.sort(transmit_names)
    table.sort(receive_names)
    local transmit_pointer = 1
    local receive_pointer = 1
    -- constructing template routing table from two sorted arrays
    while transmit_pointer <= #transmit_names and receive_pointer <= #receive_names do
        local transmit = transmit_names[transmit_pointer]
        local receive = receive_names[receive_pointer]
        if transmit == receive then
            used_labels = fill_template_routing_row(
                routing_table,
                labels,
                used_labels,
                transmit,
                true,
                true
            )
            transmit_pointer = transmit_pointer + 1
            receive_pointer = receive_pointer + 1
        elseif transmit < receive then
            used_labels = fill_template_routing_row(
                routing_table,
                labels,
                used_labels,
                transmit,
                true,
                false
            )
            transmit_pointer = transmit_pointer + 1
        else -- transmit > receive
            used_labels = fill_template_routing_row(
                routing_table,
                labels,
                used_labels,
                receive,
                false,
                true
            )
            receive_pointer = receive_pointer + 1
        end
    end
    -- adding leftovers from transmit names
    for i = transmit_pointer, #transmit_names do
        used_labels = fill_template_routing_row(
            routing_table,
            labels,
            used_labels,
            transmit_names[i],
            true,
            false
        )
    end
    -- adding leftovers from receive names
    for i = receive_pointer, #receive_names do
        used_labels = fill_template_routing_row(
            routing_table,
            labels,
            used_labels,
            receive_names[i],
            false,
            true
        )
    end
    -- destoying any unwanted labels (in case routing table got shorter)
    for i = #labels, used_labels + 1, -1 do
        labels[i].destroy()
        labels[i] = nil
    end
end

---Adds section used to display template routing
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_template_routing_table(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-templates.template-routing-table"}
    )
    local routing_table = section.add{
        type = "table",
        column_count = 3,
        style = "template_routing_table",
    }

    -- table header
    routing_table.add{
        type = "label",
        caption = {"cc-templates.cluster-name"},
        style = "bold_label"
    }
    routing_table.add{
        type = "label",
        caption = {"cc-templates.transmit"},
        style = "bold_label"
    }
    routing_table.add{
        type = "label",
        caption = {"cc-templates.receive"},
        style = "bold_label"
    }
    gui_data.elements.template_routing_table = routing_table
    gui_data.elements.template_routing_labels = {}
    update_template_routing_table(gui_data)
end

--------------------------- TEMPLATE RENAME SECTION ---------------------------

---Updates section used to rename selected template
---@param gui_data ControlCenterData
local function update_rename_template_section(gui_data)
    local elements = gui_data.elements
    local button = elements.confirm_template_rename_btn
    if not button or not button.valid then return end
    local label = elements.confirm_template_rename_label
    if not label or not label.valid then return end
    local status, reason = TCCManager.can_rename_template(
        gui_data.selected_template,
        gui_data.template_rename_name
    )
    button.enabled = status
    label.caption = reason or ""
end

---Adds section used to rename selected template
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_rename_template_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-templates.confirm-template-rename"}
    )
    -- old name label
    local old_name = gui_data.selected_template or "None"
    local old_name_caption = {"cc-templates.old-name", old_name}
    section.add{type = "label", caption = old_name_caption}
    -- new name textfield
    local h_flow = section.add{type = "flow", direction = "horizontal"}
    h_flow.style.vertical_align = "center"
    h_flow.add{type = "label", caption = {"cc-templates.new-name"}}
    h_flow.add{
        type = "textfield",
        name = PREFIX .. "cc-template-rename-textfield",
        lose_focus_on_confirm = true,
        text = gui_data.template_rename_name or ""
    }
    -- confirm button and status label above
    local flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"

    -- button and status label
    local label = flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    local button = flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-template-rename",
        caption = {"cc-templates.confirm-rename-btn"},
        style = "confirm_button",
        tooltip = {"cc-templates.confirm-rename-tooltip"},
    }
    gui_data.elements.confirm_template_rename_btn = button
    gui_data.elements.confirm_template_rename_label = label
    update_rename_template_section(gui_data)
end

--------------------------- TEMPLATE DELETE SECTION ---------------------------

---Adds section used to delete selected template
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_delete_template_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-templates.confirm-template-deletion"}
    )

    -- General warning for all templates
    local template_name = gui_data.selected_template
    local general_caption = {
        "cc-templates.deletion-warning-general",
        template_name
    }
    local general_label = section.add{type = "label", caption = general_caption}
    general_label.style.single_line = false

    -- Additional warning if template is active
    if TCCManager.is_template_active(template_name) then
        local transmit = TCCManager.get_transmit_cluster_uuids(template_name)
        local receive = TCCManager.get_receive_cluster_uuids(template_name)
        local active_caption = {
            "cc-templates.deletion-warning-active",
            #transmit,
            #receive,
        }
        local active_label = section.add{
            type = "label",
            caption = active_caption
        }
        active_label.style.single_line = false
    end

    -- Confirm deletion button
    local flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"
    flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-template-deletion",
        caption = {"cc-templates.confirm-deletion-btn"},
        style = "red_confirm_button",
        tooltip = {"cc-templates.confirm-deletion-tooltip"},
    }
end

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
    if gui_data.selected_template then
        add_template_inputs_section(right_frame, gui_data)
        add_template_outputs_section(right_frame, gui_data)
        add_template_build_cost_section(right_frame, gui_data)
        if TCCManager.is_template_active(gui_data.selected_template) then
            add_template_routing_table(right_frame, gui_data)
        end
    end
    local submode = gui_data.template_submode
    if submode == template_submodes.rename_template then
        add_rename_template_section(right_frame, gui_data)
    elseif submode == template_submodes.delete_template then
        add_delete_template_section(right_frame, gui_data)
    end
end

---Time based updater for the window in templates mode
---@param gui_data ControlCenterData
---@param update_cycle integer
function CCTemplates.on_tick_updater(gui_data, update_cycle)
    if update_cycle % 30 == 0 then
        update_template_routing_table(gui_data)
    end
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

--------------------------- TEMPLATE RENAME SECTION ---------------------------

---Handles new name textfield being changed in template rename section
---@param event EventData.on_gui_text_changed
function CCTemplates.handle_template_rename_textfield(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.template_rename_name = event.text
    update_rename_template_section(gui_data)
end

---Handles confirm template rename button being pressed
---@param event EventData.on_gui_click
function CCTemplates.handle_template_rename_confirm_btn(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    local old_name = gui_data.selected_template
    local new_name = gui_data.template_rename_name
    local status = TCCManager.rename_template(old_name, new_name)
    -- rename failed: updating rename section
    if not status then
        update_rename_template_section(gui_data)
        return
    end
    -- rename successful: updating gui state
    gui_data.template_rename_name = nil
    gui_data.selected_template = new_name
    gui_data.template_submode = nil
    update_left_rebuild_right(gui_data)
end

--------------------------- TEMPLATE DELETE SECTION ---------------------------

---Handles confirm template deletion button being pressed
---@param event EventData.on_gui_click
function CCTemplates.handle_template_deletion_confirm_btn(event)
    local player_index = event.player_index
    ---@type ControlCenterData
    local gui_data = storage.control_center[player_index]
    local template_name = gui_data.selected_template
    local status, reason = TCCManager.delete_template(template_name)
    if not status then CommonGui.print_message(player_index, reason) return end

    -- deletion successful, cleaning up gui
    gui_data.selected_template = nil
    gui_data.template_submode = nil
    update_left_rebuild_right(gui_data)
end


return CCTemplates