--[[
Helps in handling of control center GUI. Contains definitions, configurators
and handlers for GUI elements that are used in "surfaces" mode. As well as
all the logic required to operate the window in this mode.

Control center gui in "surfaces" mode can be used to manage virtualization surfaces.
Create, delete, start compilation, stop compilation, view information
--]]

---@class ControlCenterElements additional LuaGuiElements used in this mode
---@field new_surface_btn LuaGuiElement|nil toggles "new_surface" submode
---@field rename_surface_btn LuaGuiElement|nil toggles "rename_surface" submode
---@field delete_surface_btn LuaGuiElement|nil toggles "delete_surface" submode
---@field idle_surface_selector LuaGuiElement|nil "list-box" for idle surfaces
---@field compiling_surface_selector LuaGuiElement|nil "list-box" for compiling
---@field start_compilation_btn LuaGuiElement|nil toggles "start_compilation" submode
---@field stop_compilation_btn LuaGuiElement|nil toggles "stop_compilation" submode
---@field comp_progressbar LuaGuiElement|nil displays demand/max computation
---@field comp_style LuaStyle|nil style of computation progressbar
---@field new_vsurface_confirm_btn LuaGuiElement|nil button to confirm vsurface creation
---@field new_vsurface_confirm_status LuaGuiElement|nil confirm vsurface creation status
---@field new_vsurface_info_label LuaGuiElement|nil "new_surface" submode
---@field confirm_vsurface_rename_btn LuaGuiElement|nil "rename_surface" submode
---@field confirm_vsurface_rename_label LuaGuiElement|nil "rename_surface" submode
---@field confirm_compile_btn LuaGuiElement|nil "start_compilation" submode
---@field confirm_compile_label LuaGuiElement|nil "start_compilation" submode
---@field vsurface_info_status LuaGuiElement|nil vsurface info section
---@field vsurface_info_demand LuaGuiElement|nil vsurface info section
---@field compiling_template_lbl LuaGuiElement|nil compilation info template name
---@field compilation_progress_label LuaGuiElement|nil compilation info progress label
---@field compilation_progressbar LuaGuiElement|nil compilation info progressbar
---@field tcc_status LuaGuiElement|nil "label", TCC entity info section
---@field tcc_max_tier LuaGuiElement|nil "label", TCC entity info section
---@field view_tcc_btn LuaGuiElement|nil "button", TCC entity info section
---@field comp_input_table LuaGuiElement|nil "table", compilation input section
---@field comp_input_elems LuaGuiElement[]|nil "labels", compilation input section
---@field comp_output_table LuaGuiElement|nil "table", compilation output section
---@field comp_output_elems LuaGuiElement[]|nil "labels", compilation output section
---@field val_report_table LuaGuiElement|nil "table", validation report section
---@field val_report_elems table<integer, LuaGuiElement|LuaStyle>|nil


---@class ControlCenterData additional fields that can be used in "surfaces" mode
---@field surface_submode string|nil used to handle mutually exclusive gui states
---@field selected_vsurface string|nil name of selected vsurface
---@field idle_surface_query string|nil last user input into idle surfaces textfield
---@field compiling_surface_query string|nil last user input into compiling surfaces textfield
---@field vsurface_config VSurfaceConfig|nil data required for creation of vsurface
---@field new_template_name string|nil name of new template
---@field vsurface_rename_name string|nil "rename_surface" new name


local CommonGui = require("src.gui.common")
local VSurfaceManager = require("src.world.vsurface-manager")
local TCCManager = require("src.simulation.tcc-manager")

local PREFIX = "FV-"
local CCSurfaces = {}

---All possible submodes of control center in "surfaces" mode.
---Used to handle mutually exclusive GUI states.
---@enum
local surface_submodes = {
    new_surface = "new_surface",
    rename_surface = "rename_surface",
    delete_surface = "delete_surface",
    start_compilation = "start_compilation",
    stop_compilation = "stop_compilation",
}

-------------------------------------------------------------------------------
----------- LEFT FRAME CONTROL ELEMENTS: CREATION AND CONFIGURATION -----------
-------------------------------------------------------------------------------

----------------------------- NEW SURFACE BUTTON ------------------------------

---Updates "create new vsurface" button according to gui_data
---@param gui_data ControlCenterData
local function update_new_surface_button(gui_data)
    local button = gui_data.elements.new_surface_btn
    if not button or not button.valid then return end
    -- button is toggled if gui is in "new_surface" submode
    button.toggled = (
        gui_data.surface_submode == surface_submodes.new_surface
    )
end

---Adds "create new vsurface" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_new_surface_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-new-surface-btn",
        caption = {"cc-surfaces.create-new-vsurface"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.new_surface_btn = button
    update_new_surface_button(gui_data)
end

---------------------------- RENAME SURFACE BUTTON ----------------------------

---Updates "rename surface" button according to gui_data
---@param gui_data ControlCenterData
local function update_rename_surface_button(gui_data)
    local button = gui_data.elements.rename_surface_btn
    if not button or not button.valid then return end
    -- button is enabled only when vsurface is selected
    button.enabled = not not gui_data.selected_vsurface
    -- button is toggled if gui is in "rename_surface" submode
    button.toggled = (
        gui_data.surface_submode == surface_submodes.rename_surface
    )
end

---Adds "rename surface" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_rename_surface_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-rename-surface-btn",
        caption = {"cc-surfaces.rename-vsurface"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.rename_surface_btn = button
    update_rename_surface_button(gui_data)
end

---------------------------- IDLE SURFACE SELECTOR ----------------------------

---Updates idle vsurface selector
---@param gui_data ControlCenterData
local function update_idle_surface_selector(gui_data)
    local selector = gui_data.elements.idle_surface_selector
    if not selector or not selector.valid then return end
    local query = gui_data.idle_surface_query
    local options = VSurfaceManager.get_idle_vsurfaces(query)
    local selected_option = gui_data.selected_vsurface
    -- if selected vsurface is compiling, it's not displayed as selected
    if VSurfaceManager.is_compiling(selected_option) then
        selected_option = nil
    end
    CommonGui.update_selector(selector, options, selected_option)
end

---Adds selection widget for idle vsurfaces to given parent element. Widget
---consists of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_idle_surface_selection_widget(parent, gui_data)
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "cc-idle-surface-search",
        PREFIX .. "cc-idle-surface-selector",
        {"cc-surfaces.idle-vsurfaces"},
        112
    )
    search.text = gui_data.idle_surface_query or ""
    gui_data.elements.idle_surface_selector = selector
    update_idle_surface_selector(gui_data)
    -- scrolling to selected item when creating the element
    CommonGui.scroll_to_selection(selector)
end

---------------------------- DELETE SURFACE BUTTON ----------------------------

---Updates "delete selected vsurface" button according to gui_data
---@param gui_data ControlCenterData 
local function update_surface_delete_button(gui_data)
    local button = gui_data.elements.delete_surface_btn
    if not button or not button.valid then return end
    -- button is enabled only when surface is selected and not compiling
    local surface_name = gui_data.selected_vsurface
    if surface_name and not VSurfaceManager.is_compiling(surface_name) then
        button.enabled = true
    else
        button.enabled = false
    end
    -- button is toggled if gui in "delete_selected" submode
    button.toggled = (
        gui_data.surface_submode == surface_submodes.delete_surface
    )
end

---Adds "delete selected vsurface" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_surface_delete_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-delete-surface-btn",
        caption = {"cc-surfaces.delete-selected-vsurface"},
        style = "red_button",
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.delete_surface_btn = button
    update_surface_delete_button(gui_data)
end

--------------------------- START COMPILATION BUTTON --------------------------

---Updates "start compilation" button according to gui_data
---@param gui_data ControlCenterData
local function update_compilation_start_button(gui_data)
    local button = gui_data.elements.start_compilation_btn
    if not button or not button.valid then return end
    -- button is enabled only when surface is selected and idle
    local surface_name = gui_data.selected_vsurface
    button.enabled = VSurfaceManager.is_idle(surface_name)
    -- button is toggled if gui in "start_compilation" submode
    button.toggled = (
        gui_data.surface_submode == surface_submodes.start_compilation
    )
end

---Adds "start compilation" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_compilation_start_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-start-compilation-btn",
        caption = {"cc-surfaces.start-compilation"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.start_compilation_btn = button
    update_compilation_start_button(gui_data)
end

-------------------------- COMPILING SURFACE SELECTOR -------------------------

---Updates compiling vsurface selector according to gui data
---@param gui_data ControlCenterData
local function update_compiling_surface_selector(gui_data)
    local selector = gui_data.elements.compiling_surface_selector
    if not selector or not selector.valid then return end
    local query = gui_data.compiling_surface_query
    local options = VSurfaceManager.get_compiling_vsurfaces(query)
    local selected_option = gui_data.selected_vsurface
    -- if selected surface is idle, it's not displayed as selected
    if VSurfaceManager.is_idle(selected_option) then
        selected_option = nil
    end
    CommonGui.update_selector(selector, options, selected_option)
end

---Adds selection widget for compiling vsurfaces to given parent element. Widget
---consists of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_compiling_surface_selection_widget(parent, gui_data)
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "cc-compiling-surface-search",
        PREFIX .. "cc-compiling-surface-selector",
        {"cc-surfaces.compiling-vsurfaces"},
        112
    )
    search.text = gui_data.compiling_surface_query or ""
    gui_data.elements.compiling_surface_selector = selector
    update_compiling_surface_selector(gui_data)
    -- scrolling to selected item when creating the element
    CommonGui.scroll_to_selection(selector)
end

--------------------------- STOP COMPILATION BUTTON ---------------------------

---Updates "stop compilation" button according to gui_data
---@param gui_data ControlCenterData 
local function update_compilation_stop_button(gui_data)
    local button = gui_data.elements.stop_compilation_btn
    if not button or not button.valid then return end
    -- button is enabled only when surface is selected and compiling
    local surface_name = gui_data.selected_vsurface
    button.enabled = VSurfaceManager.is_compiling(surface_name)
    -- button is toggled if gui in "stop_compilation" submode
    button.toggled = (
        gui_data.surface_submode == surface_submodes.stop_compilation
    )
end

---Adds "stop compilation" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_compilation_stop_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-stop-compilation-btn",
        caption = {"cc-surfaces.stop-compilation"},
        style = "red_button",
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.stop_compilation_btn = button
    update_compilation_stop_button(gui_data)
end

-------------------------------------------------------------------------------
---------------------------- RIGHT FRAME ELEMENTS -----------------------------
-------------------------------------------------------------------------------

-------------------------- NEW SURFACE CONFIGURATION --------------------------

---Adds textfield for name of new vsurface and label above
---@param parent LuaGuiElement element will be added here
---@param gui_data ControlCenterData
local function add_new_vsurface_name_textfield(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{type = "label", caption = {"cc-surfaces.new-vsurface-name"}}
    local textfield = flow.add{
        type = "textfield",
        name = PREFIX .. "cc-new-vsurface-name",
        lose_focus_on_confirm = true,
    }
    textfield.style.width = 180
    ---Setting text to anything saved in vsurface config
    ---@type VSurfaceConfig assuming table was created on submode change
    local vsurface_config = gui_data.vsurface_config
    textfield.text = vsurface_config.name or ""
end

---Helps in creation of new vsurface size widget. Adds numeric textfield with caption.
---@param parent LuaGuiElement element will be added here
---@param caption LocalisedString caption displayed above textfield
---@param name string internal name for this element
---@return LuaGuiElement textfield
local function add_vsurface_size_textfield(parent, caption, name)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{type = "label", caption = caption}
    local textfield = flow.add{
        type = "textfield",
        name = name,
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
        lose_focus_on_confirm = true,
    }
    textfield.style.width = 75
    return textfield
end

---Adds 2 textfields where height and width of new vsurface can be specified.
---@param parent LuaGuiElement widget will be added here
---@param gui_data ControlCenterData
local function add_new_vsurface_size_widget(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "horizontal"}
    flow.style.horizontal_spacing = 0
    local width_textfield = add_vsurface_size_textfield(
        flow,
        {"cc-surfaces.new-vsurface-width"},
        PREFIX .. "cc-new-vsurface-width"
    )
    local spacer = flow.add{type = "flow"}
    spacer.style.width = 30
    local height_textfield = add_vsurface_size_textfield(
        flow,
        {"cc-surfaces.new-vsurface-height"},
        PREFIX .. "cc-new-vsurface-height"
    )
    ---Setting text to anything saved in vsurface config
    ---@type VSurfaceConfig assuming table was created on submode change
    local vsurface_config = gui_data.vsurface_config
    local vsurface_width = vsurface_config.width
    if vsurface_width then
        width_textfield.text = tostring(vsurface_width)
    end
    local vsurface_height = vsurface_config.height
    if vsurface_height then
        height_textfield.text = tostring(vsurface_height)
    end
end

---Updates new surface info labels according to vsurface config
---@param gui_data ControlCenterData
local function update_new_surface_info_label(gui_data)
    ---@type VSurfaceConfig assuming it was created on submode change
    local vsurface_config = gui_data.vsurface_config
    local label = gui_data.elements.new_vsurface_info_label
    if not label or not label.valid then return end

    ---Idle computation demand
    local idle_demand = VSurfaceManager.get_idle_computation_demand(
        vsurface_config
    )
    ---Compiling computation demand
    local comp_demand = VSurfaceManager.get_compiling_computation_demand(
        vsurface_config
    )
    ---Template energy drain
    local energy_drain = VSurfaceManager.get_vsurface_energy_drain(vsurface_config)
    -- Template tier
    local tier = TCCManager.get_template_tier(energy_drain)

    local caption = {
        "cc-surfaces.new-vsurface-info-label",
        CommonGui.large_number_to_string(idle_demand),
        CommonGui.large_number_to_string(comp_demand),
        CommonGui.large_number_to_string(energy_drain),
        CommonGui.number_to_string(tier, 2)
    }
    label.caption = caption
end

---Adds new vsurface information labels used to display computation demands,
---template energy drain, etc.
---@param parent LuaGuiElement labels will be added here
---@param gui_data ControlCenterData
local function add_new_surface_info_label(parent, gui_data)
    local label = parent.add{type = "label"}
    label.style.single_line = false
    gui_data.elements.new_vsurface_info_label = label
    update_new_surface_info_label(gui_data)
end

---Adds "generate as" selector which allows to select planet to generate as
---@param parent LuaGuiElement element will be added here
---@param gui_data ControlCenterData
local function add_generate_as_selector(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{type = "label", caption = {"cc-surfaces.new-vsurface-generate-as"}}
    local selector = flow.add{
        type = "list-box",
        name = PREFIX .. "cc-generate-as-selector",
        style = "list_box_in_shallow_frame",
    }
    local selector_style = selector.style
    selector_style.width = 200
    selector_style.height = 92

    ---@type VSurfaceConfig assuming table was created on submode change
    local vsurface_config = gui_data.vsurface_config
    local selected_option = vsurface_config.generate_as
    local options = VSurfaceManager.get_generate_as_options()
    CommonGui.update_selector(selector, options, selected_option)
end

---Updates new vsurface confirm button
---@param gui_data ControlCenterData
local function update_new_vsurface_confirm_button(gui_data)
    local elements = gui_data.elements
    local confirm_button = elements.new_vsurface_confirm_btn
    if not confirm_button or not confirm_button.valid then return end
    local status_label = elements.new_vsurface_confirm_status
    if not status_label or not status_label.valid then return end

    local status, reason = VSurfaceManager.can_create_vsurface(
        gui_data.vsurface_config
    )
    confirm_button.enabled = status
    status_label.caption = reason or ""
end

---Adds new vsurface confirm button with status label above.
---@param parent LuaGuiElement button will be added here
---@param gui_data ControlCenterData
local function add_new_vsurface_confirm_btn(parent, gui_data)
    -- needed for right side alignment
    local flow = parent.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"

    -- button and status label
    local label = flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    local button = flow.add{
        type = "button",
        name = PREFIX .. "cc-new-vsurface-confirm",
        caption = {"cc-surfaces.new-vsurface-confirm"},
        style = "confirm_button",
        tooltip = {"cc-surfaces.new-vsurface-confirm-tooltip"},
    }
    gui_data.elements.new_vsurface_confirm_btn = button
    gui_data.elements.new_vsurface_confirm_status = label
    update_new_vsurface_confirm_button(gui_data)
end

---Adds section for configuration of a new vsurface to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_new_vsurface_configuration_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.new-vsurface-subtitle"}
    )

    ---First row: name, width, height on the left; generate as on the right
    local h_flow = section.add{type = "flow", direction = "horizontal"}
    h_flow.style.horizontal_spacing = 0
    -- first column: name and dimensions
    local v_flow = h_flow.add{type = "flow", direction = "vertical"}
    v_flow.style.vertical_spacing = 12
    add_new_vsurface_name_textfield(v_flow, gui_data)
    add_new_vsurface_size_widget(v_flow, gui_data)
    -- spacer between columns
    local h_spacer = h_flow.add{type = "flow"}
    h_spacer.style.width = 20
    -- second column: generate as selector
    add_generate_as_selector(h_flow, gui_data)

    ---Second row: info labels
    add_new_surface_info_label(section, gui_data)

    --Third row: confirm vsurface creation button and label
    add_new_vsurface_confirm_btn(section, gui_data)
end

---Used to update new vsurface configuration section.
---Can be used for time-based updates.
---@param gui_data ControlCenterData
local function update_new_vsurface_configuration_section(gui_data)
    update_new_vsurface_confirm_button(gui_data)
    update_new_surface_info_label(gui_data)
end

-------------------------- RENAME SELECTED VSURFACE ---------------------------

---Updates section used to rename selected vsurface
---@param gui_data ControlCenterData
local function update_vsurface_rename_section(gui_data)
    local elements = gui_data.elements
    local button = elements.confirm_vsurface_rename_btn
    if not button or not button.valid then return end
    local label = elements.confirm_vsurface_rename_label
    if not label or not label.valid then return end
    local status, reason = VSurfaceManager.can_rename_vsurface(
        gui_data.selected_vsurface,
        gui_data.vsurface_rename_name
    )
    button.enabled = status
    label.caption = reason or ""
end

---Adds section used to rename selected vsurface
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_vsurface_rename_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.rename-section-title"}
    )
    local elements = gui_data.elements

    -- Old name label
    local old_name = gui_data.selected_vsurface or "—"
    local caption = {"cc-surfaces.old-name", old_name}
    section.add{type = "label", caption = caption}

    -- New name textfield
    local h_flow = section.add{type = "flow", direction = "horizontal"}
    h_flow.style.vertical_align = "center"
    h_flow.add{type = "label", caption = {"cc-surfaces.new-name"}}
    h_flow.add{
        type = "textfield",
        name = PREFIX .. "cc-vsurface-rename-textfield",
        lose_focus_on_confirm = true,
        text = gui_data.vsurface_rename_name or ""
    }

    -- Confirm button and status label above
    local flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"

    -- button and status label
    local label = flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    local button = flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-vsurface-rename",
        caption = {"cc-surfaces.confirm-rename-btn"},
        style = "confirm_button",
        tooltip = {"cc-surfaces.confirm-rename-tooltip"},
    }

    elements.confirm_vsurface_rename_btn = button
    elements.confirm_vsurface_rename_label = label
    update_vsurface_rename_section(gui_data)
end

-------------------------- DELETE SELECTED VSURFACE ---------------------------

---Adds section used for confirmation of vsurface deletion.
---Contains a warning and a button to confirm deletion
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_confirm_vsurface_delete_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.vsurface-deletion-subtitle"}
    )
    local surface_name = gui_data.selected_vsurface
    local idle_demand = VSurfaceManager.get_computation_demands(surface_name)
    local demand_fmt = CommonGui.large_number_to_string(idle_demand)
    local caption = {
        "cc-surfaces.vsurface-deletion-warning",
        surface_name or "—",
        demand_fmt
    }
    local warning = section.add{type = "label", caption = caption}
    warning.style.single_line = false

    -- needed for horizontal alignment of delete button
    local flow = section.add{type = "flow", direction = "horizontal"}
    local flow_style = flow.style
    flow_style.width = 400
    flow_style.horizontal_align = "right"
    flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-vsurface-delete",
        caption = {"cc-surfaces.vsurface-deletion-delete"},
        style = "red_confirm_button",
        tooltip = {"cc-surfaces.vsurface-deletion-delete-tooltip"},
    }
end

------------------------------ START COMPILATION ------------------------------

---Adds a warning label to "start compilation" section
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_confirm_compilation_start_warning(parent, gui_data)
    local surface_name = gui_data.selected_vsurface
    local idle_demand, compiling_demand = VSurfaceManager.get_computation_demands(
        surface_name
    )
    local caption = {
        "cc-surfaces.compilation-start-warning",
        surface_name or "—",
        CommonGui.large_number_to_string(compiling_demand - idle_demand)
    }
    local warning = parent.add{type = "label", caption = caption}
    warning.style.single_line = false
end

---Adds a textfield with label above used to enter new template name in
---"start compilation" section.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_new_template_name_textfield(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{
        type = "label",
        caption = {"cc-surfaces.compilation-start-template-name"},
    }
    flow.add{
        type = "textfield",
        name = PREFIX .. "cc-new-template-name",
        lose_focus_on_confirm = true,
        text = gui_data.new_template_name or "",
    }
end

---Adds a button with status label above to "start compilation" section
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_confirm_compilation_start_button(parent, gui_data)
    ---Confirmation button and label above
    local flow = parent.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"

    -- button and status label
    local label = flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    local button = flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-compile",
        caption = {"cc-surfaces.compilation-start-btn"},
        style = "confirm_button",
        tooltip = {"cc-surfaces.compilation-start-tooltip"},
    }
    gui_data.elements.confirm_compile_btn = button
    gui_data.elements.confirm_compile_label = label
end

---Updates "start compilation" section. Can be used for time-based section updates.
---@param gui_data ControlCenterData
local function update_confirm_compilation_start_section(gui_data)
    local button = gui_data.elements.confirm_compile_btn
    if not button or not button.valid then return end
    local label = gui_data.elements.confirm_compile_label
    if not label or not label.valid then return end

    local surface_name = gui_data.selected_vsurface
    local template_name = gui_data.new_template_name
    local status, reason = VSurfaceManager.can_start_compilation(
        surface_name,
        template_name
    )
    button.enabled = status
    label.caption = reason or ""
end

---Adds "start compilation" section
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_confirm_compilation_start_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.compilation-start-subtitle"}
    )
    add_confirm_compilation_start_warning(section, gui_data)
    add_new_template_name_textfield(section, gui_data)
    add_confirm_compilation_start_button(section, gui_data)
    update_confirm_compilation_start_section(gui_data)
end

------------------------------ STOP COMPILATION -------------------------------

---Adds section for confirmation of compilation stop.
---This section does not require time-based updates.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_confirm_compilation_stop_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.compilation-stop-subtitle"}
    )

    ---Warning label
    local surface_name = gui_data.selected_vsurface
    local idle_demand, compiling_demand = VSurfaceManager.get_computation_demands(
        surface_name
    )
    local delta_compute = compiling_demand - idle_demand
    local delta_fmt = CommonGui.large_number_to_string(delta_compute)
    local caption = {
        "cc-surfaces.compilation-stop-warning",
        surface_name or "—",
        delta_fmt
    }
    local warning = section.add{type = "label", caption = caption}
    warning.style.single_line = false

    ---Confirmation button
    local flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"
    flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-compile-stop",
        caption = {"cc-surfaces.compilation-stop-btn"},
        style = "red_confirm_button",
        tooltip = {"cc-surfaces.compilation-stop-tooltip"},
    }
end

------------------------------- TCC ENTITY INFO -------------------------------

local tcc_registered = {"cc-surfaces.tcc-registered"}
local tcc_not_registered = {"cc-surfaces.tcc-not-registered"}

---Updates section used to display info about registered TCC entity
---@param gui_data ControlCenterData
local function update_tcc_entity_info(gui_data)
    local elements = gui_data.elements

    -- Updating TCC entity status label
    local label = elements.tcc_status
    if not label or not label.valid then return end
    local is_reg = TCCManager.is_tcc_registered()
    label.caption = is_reg and tcc_registered or tcc_not_registered

    -- Updating max template tier label
    label = elements.tcc_max_tier
    if not label or not label.valid then return end
    local max_tier = TCCManager.get_max_template_tier()
    local caption = {
        "cc-surfaces.tcc-max-tier",
        CommonGui.number_to_string(max_tier, 2)
    }
    label.caption = caption

    -- Updating view TCC button
    local btn = elements.view_tcc_btn
    if not btn or not btn.valid then return end
    btn.enabled = is_reg
end

---Adds section used to display info about registered TCC entity
---@param parent LuaGuiElement element will be added here
---@param gui_data ControlCenterData
local function add_tcc_entity_info(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.tcc-entity-info"}
    )
    local elements = gui_data.elements
    local h_flow = section.add{type = "flow", direction = "horizontal"}
    h_flow.style.vertical_align = "center"
    local v_flow = h_flow.add{type = "flow", direction = "vertical"}
    v_flow.style.vertical_spacing = 0
    -- TCC entity status label
    elements.tcc_status = v_flow.add{type = "label"}
    -- Max template tier
    elements.tcc_max_tier = v_flow.add{type = "label"}

    -- View tcc entity button
    local spacer = h_flow.add{type = "flow"}
    spacer.style.horizontally_stretchable = true
    local btn = h_flow.add{
        type = "button",
        name = PREFIX .. "cc-view-tcc",
        caption = {"cc-surfaces.view-tcc-entity"},
    }
    btn.style.width = 200
    elements.view_tcc_btn = btn
    update_tcc_entity_info(gui_data)
end

----------------------------- COMPUTATION DISPLAY -----------------------------

---Updates section used to display current computation state
---@param gui_data ControlCenterData
local function update_computation_display_section(gui_data)
    local elements = gui_data.elements
    local bar = elements.comp_progressbar
    if not bar or not bar.valid then return end
    ---@type LuaStyle assuming it's in sync with progressbar
    local style = elements.comp_style

    local demand = TCCManager.get_computation_curr_demand()
    local max_available = TCCManager.get_computation_max_available()
    -- progressbar caption
    local caption = {
        "cc-surfaces.progressbar-text",
        CommonGui.large_number_to_string(demand),
        CommonGui.large_number_to_string(max_available),
    }
    bar.caption = caption
    -- progressbar value
    local bar_value = (
        (max_available ~= 0) and (demand / max_available) or
        (demand > 0) and 1 or 0
    )
    bar.value = bar_value
    -- progressbar color
    local bar_color
    if bar_value <= 0.5 then
        bar_color = CommonGui.green
    elseif bar_value <= 0.85 then
        bar_color = CommonGui.yellow
    else
        bar_color = CommonGui.red
    end
    style.color = bar_color
end

---Adds information element displaying computation resource demand/max.
---@param parent LuaGuiElement element will be added here
---@param gui_data ControlCenterData
local function add_computation_display_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.computation-display-subtitle"}
    )
    local progressbar = section.add{
        type = "progressbar",
        style = "electric_statistics_progressbar",
    }
    local style = progressbar.style
    style.horizontally_stretchable = true
    local elements = gui_data.elements
    elements.comp_progressbar = progressbar
    ---@diagnostic disable-next-line: assign-type-mismatch
    elements.comp_style = style
    update_computation_display_section(gui_data)
end

--------------------------- SELECTED VSURFACE INFO ----------------------------

---Updates vsurface info section
---@param gui_data ControlCenterData
local function update_vsurface_info_section(gui_data)
    local surface_name = gui_data.selected_vsurface
    local elements = gui_data.elements

    -- Updating vsurface status row
    local label = elements.vsurface_info_status
    if not label or not label.valid then return end
    local status = VSurfaceManager.get_vsurface_status(surface_name)
    label.caption = status

    -- Updating computation demand row
    label = elements.vsurface_info_demand
    if not label or not label.valid then return end
    local demand = VSurfaceManager.get_current_computation_demand(surface_name)
    label.caption = CommonGui.large_number_to_string(demand)
end

---Adds section displaying information about selected vsurface
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_vsurface_info_section(parent, gui_data)
    local elements = gui_data.elements
    local surface_name = gui_data.selected_vsurface

    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.vsurface-info-subtitle"}
    )
    local info_table = section.add{
        type = "table",
        column_count = 2,
        style = "vsurface_info_table",
    }

    -- Vsurface name row: does not require updates
    info_table.add{
        type = "label",
        caption = {"cc-surfaces.surface-name"},
        style = "bold_label",
    }
    local label = info_table.add{
        type = "label",
        caption = surface_name or "None"
    }
    label.style.maximal_width = 200
    -- Vsurface dimensions row: does not require updates
    info_table.add{
        type = "label",
        caption = {"cc-surfaces.dimensions"},
        style = "bold_label",
    }
    local width, height = VSurfaceManager.get_vsurface_dimensions(
        surface_name
    )
    local caption = {"cc-surfaces.dimensions-value", width, height}
    info_table.add{type = "label", caption = caption}
    -- Vsurface status row: requires updated
    info_table.add{
        type = "label",
        caption = {"cc-surfaces.surface-status"},
        style = "bold_label",
    }
    elements.vsurface_info_status = info_table.add{type = "label"}
    -- Vsurface computation demand: requires updated
    info_table.add{
        type = "label",
        caption = {"cc-surfaces.computation-demand"},
        style = "bold_label",
    }
    gui_data.elements.vsurface_info_demand = info_table.add{type = "label"}
    -- Per-craft overhead: does not require updates
    info_table.add{
        type = "label",
        caption = {"cc-surfaces.per-craft-overhead"},
        style = "bold_label",
    }
    local drain = VSurfaceManager.get_energy_drain_by_name(surface_name)
    local drain_fmt = CommonGui.large_number_to_string(drain)
    caption = {"cc-surfaces.overhead-value", drain_fmt}
    info_table.add{type = "label", caption = caption}
    -- Template complexity: does not require updates
    info_table.add{
        type = "label",
        caption = {"cc-surfaces.template-complexity"},
        style = "bold_label",
    }
    local tier = (drain ~= 0) and TCCManager.get_template_tier(drain) or -1
    local tier_caption = CommonGui.number_to_string(tier, 2)
    info_table.add{
        type = "label",
        caption = tier_caption
    }
    -- View surface row: does not require updates
    info_table.add{
        type = "label",
        caption = {"cc-surfaces.view-surface"},
        style = "bold_label",
    }
    info_table.add{
        type = "button",
        name = PREFIX .. "cc-view-surface-btn",
        caption = {"cc-surfaces.view"}
    }
    update_vsurface_info_section(gui_data)
end

------------------------------ COMPILATION INFO -------------------------------

---Updates section desplaying compilation info
---@param gui_data ControlCenterData
local function update_compilation_info_section(gui_data)
    local elements = gui_data.elements
    local surface_name = gui_data.selected_vsurface
    local elapsed, total = VSurfaceManager.get_compilation_progress(
        surface_name
    )

    -- Updating compiling template label
    local label = elements.compiling_template_lbl
    if not label or not label.valid then return end
    local template_name = VSurfaceManager.get_template_name(surface_name)
    local template_caption = {
        "cc-surfaces.info-template-name",
        template_name
    }
    label.caption = template_caption


    -- Updating compilation progress label
    label = elements.compilation_progress_label
    if not label or not label.valid then return end
    local percent = (
        (total ~= 0) and
        CommonGui.number_to_string(elapsed / total * 100, 2) or
        0
    )
    local progress_caption = {"cc-surfaces.info-progress", percent}
    label.caption = progress_caption

    -- Updating compilation progressbar
    local bar = elements.compilation_progressbar
    if not bar or not bar.valid then return end
    local bar_caption = {"cc-surfaces.progressbar-text", elapsed, total}
    bar.caption = bar_caption
    local value = (total ~= 0) and (elapsed / total) or 0
    bar.value = value
end

---Adds section displaying compilation info
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_compilation_info_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.info-subtitle"}
    )
    local flow = section.add{type = "flow", direction = "vertical"}
    flow.style.vertical_spacing = 0
    local elements = gui_data.elements
    local surface_name = gui_data.selected_vsurface

    -- Template name label: requires updates
    elements.compiling_template_lbl = flow.add{type = "label"}

    -- Compilation progress label: requires updates
    local progress_label = flow.add{type = "label"}
    elements.compilation_progress_label = progress_label
    progress_label.style.bottom_margin = 4

    -- Compilation progressbar: requires updates
    local bar = flow.add{
        type = "progressbar",
        style = "electric_statistics_progressbar",
    }
    elements.compilation_progressbar = bar
    local bar_style = bar.style
    bar_style.horizontally_stretchable = true
    bar_style.color = CommonGui.green

    update_compilation_info_section(gui_data)
end

------------------------- COMPILATION IO SECTIONS --------------------------

---Picks sprite, tooltip and quality for a buffer key
---@param buffer_key BufferKeyString
---@return string sprite
---@return LocalisedString tooltip
---@return string|nil quality
local function get_sprite_button_data(buffer_key)
    local sprite, tooltip, quality
    -- looking for "//" seperator in buffer key
    local start_idx, stop_idx = string.find(buffer_key, "//", 1, true)
    if start_idx then
        -- item key "name//quality"
        local name = string.sub(buffer_key, 1, start_idx - 1)
        quality = string.sub(buffer_key, stop_idx + 1)
        sprite = "item/" .. name
        -- vanilla items can only have localization as entities
        tooltip = {"?", {"item-name." .. name}, {"entity-name." .. name}}
    elseif buffer_key == "electric_energy" then
        -- energy key
        sprite = "virtual-signal/signal-lightning"
        tooltip = {"description.energy"}
    else
        -- fluid key "name"
        sprite = "fluid/" .. buffer_key
        tooltip = {"fluid-name." .. buffer_key}
    end
    return sprite, tooltip, quality
end

---Updates one row of compilation io table
---@param io_table LuaGuiElement 
---@param elems LuaGuiElement[]
---@param used_elems integer
---@param buffer_key BufferKeyString
---@param amount number io amount
---@param time number compilation time (can be zero)
---@return integer used_elems new value
local function fill_compilation_io_row(
    io_table,
    elems,
    used_elems,
    buffer_key,
    amount,
    time
)
    local sprite, tooltip, quality = get_sprite_button_data(buffer_key)
    local total_caption = CommonGui.large_number_to_string(amount)
    local per_tick = (
        (time ~= 0) and
        CommonGui.large_number_to_string(amount / time) or
        "—"
    )
    local per_second = (
        (time ~= 0) and
        CommonGui.large_number_to_string(amount / time * 60) or
        "—"
    )
    local per_minute = (
        (time ~= 0) and
        CommonGui.large_number_to_string(amount / time * 3600) or
        "—"
    )

    local elems_length = #elems
    if elems_length > used_elems then
        -- There are enough elements: updating existing
        local sprite_btn = elems[used_elems + 1]
        sprite_btn.sprite = sprite
        sprite_btn.tooltip = tooltip
        sprite_btn.quality = quality
        elems[used_elems + 2].caption = total_caption
        elems[used_elems + 3].caption = per_tick
        elems[used_elems + 4].caption = per_second
        elems[used_elems + 5].caption = per_minute
    else
        -- There are not enough elements: creating new ones
        local frame = io_table.add{
            type = "frame",
            style = "deep_frame_in_shallow_frame",
        }
        elems[elems_length + 1] = frame.add{
            type = "sprite-button",
            sprite = sprite,
            tooltip = tooltip,
            quality = quality
        }
        -- Total amount label
        elems[elems_length + 2] = io_table.add{
            type = "label",
            caption = total_caption,
        }
        -- Per tick label
        elems[elems_length + 3] = io_table.add{
            type = "label",
            caption = per_tick
        }
        -- Per second label
        elems[elems_length + 4] = io_table.add{
            type = "label",
            caption = per_second
        }
        -- Per minute label
        elems[elems_length + 5] = io_table.add{
            type = "label",
            caption = per_minute
        }
    end
    return used_elems + 5
end

---Clears all unwanted rows from compilation io table
---@param elems LuaGuiElement[]
---@param used_elems integer number of elements already updated
local function clear_io_table_unwanded_rows(elems, used_elems)
    for i = #elems, used_elems + 1, -5 do
        -- per minute label
        elems[i].destroy()
        elems[i] = nil
        -- per second label
        elems[i - 1].destroy()
        elems[i - 1] = nil
        -- per tick label
        elems[i - 2].destroy()
        elems[i - 2] = nil
        -- total label
        elems[i - 3].destroy()
        elems[i - 3] = nil
        -- sprite button (inside deep frame)
        elems[i - 4].parent.destroy()
        elems[i - 4] = nil
    end
end

---Updates one given io table
---@param vsurface_table table<BufferKeyString, number>
---@param io_table LuaGuiElement|nil "table" to be updated
---@param elems LuaGuiElement[]
---@param comp_time any
local function update_compilation_io_table(
    vsurface_table,
    io_table,
    elems,
    comp_time
)
    if not io_table or not io_table.valid then return end
    local used_elems = 0
    for key, amount in pairs(vsurface_table) do
        used_elems = fill_compilation_io_row(
            io_table,
            elems,
            used_elems,
            key,
            amount,
            comp_time
        )
    end
    clear_io_table_unwanded_rows(elems, used_elems)
end

---Updates compilation input and output sections
---@param gui_data ControlCenterData
local function update_compilation_io_sections(gui_data)
    local surface_name = gui_data.selected_vsurface
    local elements = gui_data.elements
    local input, output = VSurfaceManager.get_vsurface_io_tables(surface_name)
    local comp_time = VSurfaceManager.get_compilation_progress(surface_name)

    -- Updating compilation input table
    update_compilation_io_table(
        input,
        elements.comp_input_table,
        elements.comp_input_elems,
        comp_time
    )

    -- Updating compilation output table
    update_compilation_io_table(
        output,
        elements.comp_output_table,
        elements.comp_output_elems,
        comp_time
    )
end

---Adds header to compilation io table
---@param io_table LuaGuiElement "table" to be filled
local function add_compilation_io_header(io_table)
    io_table.add{
        type = "label",
        caption = {"cc-surfaces.entry"},
        style = "bold_label",
    }
    io_table.add{
        type = "label",
        caption = {"cc-surfaces.total"},
        style = "bold_label",
    }
    io_table.add{
        type = "label",
        caption = {"cc-surfaces.per-tick"},
        style = "bold_label",
    }
    io_table.add{
        type = "label",
        caption = {"cc-surfaces.per-second"},
        style = "bold_label",
    }
    io_table.add{
        type = "label",
        caption = {"cc-surfaces.per-minute"},
        style = "bold_label",
    }
end

---Adds compilation input and output sections
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_compilation_io_sections(parent, gui_data)
    local elements = gui_data.elements

    --Compilation input section
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.compilation-inputs"}
    )
    local io_table = section.add{
        type = "table",
        column_count = 5,
        style = "compilation_io_table",
    }
    add_compilation_io_header(io_table)
    elements.comp_input_table = io_table
    elements.comp_input_elems = {}

    --Compilation output section
    section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.compilation-outputs"}
    )
    io_table = section.add{
        type = "table",
        column_count = 5,
        style = "compilation_io_table",
    }
    add_compilation_io_header(io_table)
    elements.comp_output_table = io_table
    elements.comp_output_elems = {}

    update_compilation_io_sections(gui_data)
end

-------------------------- VALIDATION REPORT SECTION --------------------------

---Updates one row in validation report table
---@param report_table LuaGuiElement "table" element to be updated
---@param elems table<integer, LuaGuiElement|LuaStyle>
---@param used_elems integer
---@param validation_entry ValidationEntry
---@return integer used_elems new value
local function fill_validation_report_row(
    report_table,
    elems,
    used_elems,
    buffer_key,
    validation_entry
)
    local sprite, tooltip, quality = get_sprite_button_data(buffer_key)
    local in_sum = validation_entry.input + validation_entry.produced
    local in_caption = CommonGui.large_number_to_string(in_sum)
    local out_sum = validation_entry.output + validation_entry.consumed
    local out_caption = CommonGui.large_number_to_string(out_sum)
    local dev_color = (
        validation_entry.acceptable and CommonGui.green or CommonGui.red
    )
    local dev_caption = {
        "cc-surfaces.dev-value",
        CommonGui.number_to_string(validation_entry.deviation_rel * 100, 3),
        CommonGui.large_number_to_string(validation_entry.deviation_abs),
    }

    local elems_length = #elems
    if elems_length > used_elems then
        -- There are enough elements: updating existing
        local sprite_btn = elems[used_elems + 1]
        sprite_btn.sprite = sprite
        sprite_btn.tooltip = tooltip
        sprite_btn.quality = quality
        elems[used_elems + 2].caption = in_caption
        elems[used_elems + 3].caption = out_caption
        elems[used_elems + 4].caption = dev_caption
        elems[used_elems + 5].font_color = dev_color
    else
        -- There are not enough elements: creating new ones
        local frame = report_table.add{
            type = "frame",
            style = "deep_frame_in_shallow_frame",
        }
        elems[elems_length + 1] = frame.add{
            type = "sprite-button",
            sprite = sprite,
            tooltip = tooltip,
            quality = quality,
        }
        -- Input sum label
        elems[elems_length + 2] = report_table.add{
            type = "label",
            caption = in_caption
        }
        -- Output sum label
        elems[elems_length + 3] = report_table.add{
            type = "label",
            caption = out_caption
        }
        -- Deviation label and style
        local dev_label = report_table.add{
            type = "label",
            caption = dev_caption
        }
        local style = dev_label.style
        style.font_color = dev_color
        elems[elems_length + 4] = dev_label
        ---@diagnostic disable-next-line: assign-type-mismatch
        elems[elems_length + 5] = style
    end
    return used_elems + 5
end


---Updates section used to display compilation validation report
---@param gui_data ControlCenterData
local function update_validation_report_section(gui_data)
    local elements = gui_data.elements
    local report_table = elements.val_report_table
    if not report_table or not report_table.valid then return end
    ---@type table<integer, LuaGuiElement|LuaStyle>
    local elems = elements.val_report_elems

    local used_elems = 0
    local report = VSurfaceManager.get_validation_report(
        gui_data.selected_vsurface
    )
    for key, entry in pairs(report) do
        used_elems = fill_validation_report_row(
            report_table,
            elems,
            used_elems,
            key,
            entry
        )
    end
    -- destoying any unwanted rows in case "table" got smaller
    for i = #elems, used_elems + 1, -5 do
        -- deviation label style
        elems[i] = nil
        -- deviation label
        elems[i - 1].destroy()
        elems[i - 1] = nil
        -- output sum label
        elems[i - 2].destroy()
        elems[i - 2] = nil
        -- input sum label
        elems[i - 3].destroy()
        elems[i - 3] = nil
        -- sprite button (destroying parent flow)
        elems[i - 4].parent.destroy()
        elems[i - 4] = nil
    end
end

---Adds section used to display compilation validation report
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_validation_report_section(parent, gui_data)
    local elements = gui_data.elements
    local section = CommonGui.create_info_element_base(
        parent,
        {"cc-surfaces.validation-report"}
    )
    local report_table = section.add{
        type = "table",
        column_count = 4,
        style = "validation_report_table"
    }
    -- table header
    report_table.add{
        type = "label",
        caption = {"cc-surfaces.entry"},
        style = "bold_label"
    }
    report_table.add{
        type = "label",
        caption = {"cc-surfaces.input-sum"},
        style = "bold_label"
    }
    report_table.add{
        type = "label",
        caption = {"cc-surfaces.output-sum"},
        style = "bold_label"
    }
    report_table.add{
        type = "label",
        caption = {"cc-surfaces.deviation"},
        style = "bold_label"
    }
    elements.val_report_table = report_table
    elements.val_report_elems = {}
    update_validation_report_section(gui_data)
end

-------------------------------------------------------------------------------
------------------------ GUI CONSTRUCTION AND UPDATES -------------------------
-------------------------------------------------------------------------------

---Constructs left side of surface mode interface
---@param gui_data ControlCenterData
function CCSurfaces.construct_left_side(gui_data)
    local left_frame = gui_data.elements.left_frame
    add_new_surface_button(left_frame, gui_data)
    add_rename_surface_button(left_frame, gui_data)
    add_idle_surface_selection_widget(left_frame, gui_data)
    add_surface_delete_button(left_frame, gui_data)
    add_compilation_start_button(left_frame, gui_data)
    local spacer = left_frame.add{type = "flow"}
    spacer.style.vertically_stretchable = true
    add_compiling_surface_selection_widget(left_frame, gui_data)
    add_compilation_stop_button(left_frame, gui_data)
end

---Maps submodes to functions used to construct corresponding element
local submode_gui_constructors = {
    [surface_submodes.new_surface] = add_new_vsurface_configuration_section,
    [surface_submodes.rename_surface] = add_vsurface_rename_section,
    [surface_submodes.delete_surface] = add_confirm_vsurface_delete_section,
    [surface_submodes.start_compilation] = add_confirm_compilation_start_section,
    [surface_submodes.stop_compilation] = add_confirm_compilation_stop_section,
}

---Constructs right side of surface mode interface
---@param gui_data ControlCenterData
function CCSurfaces.construct_right_side(gui_data)
    local right_frame = gui_data.elements.right_frame

    -- Computation section and tcc info are always displayed
    add_tcc_entity_info(right_frame, gui_data)
    add_computation_display_section(right_frame, gui_data)

    ---Displaying vsurface information if it's selected
    if gui_data.selected_vsurface then
        add_vsurface_info_section(right_frame, gui_data)
        add_compilation_info_section(right_frame, gui_data)
        add_compilation_io_sections(right_frame, gui_data)
        add_validation_report_section(right_frame, gui_data)
    end

    ---If sumbode is selected, displaying corresponding section
    local submode = gui_data.surface_submode
    if submode then
        local constructor = submode_gui_constructors[submode]
        if constructor then
            constructor(right_frame, gui_data)
            right_frame.scroll_to_bottom()
        end
    end
end

---Updates all elements in the left frame, rebuilds the right frame
---@param gui_data ControlCenterData
local function update_left_rebuild_right(gui_data)
    update_new_surface_button(gui_data)
    update_rename_surface_button(gui_data)
    update_idle_surface_selector(gui_data)
    update_surface_delete_button(gui_data)
    update_compilation_start_button(gui_data)
    update_compiling_surface_selector(gui_data)
    update_compilation_stop_button(gui_data)
    gui_data.elements.right_frame.clear()
    CCSurfaces.construct_right_side(gui_data)
end

---Maps submodes to functions used to update corresponding sections
local submode_updates = {
    [surface_submodes.new_surface] = update_new_vsurface_confirm_button,
    [surface_submodes.rename_surface] = update_vsurface_rename_section,
    [surface_submodes.start_compilation] = update_confirm_compilation_start_section,
}

---Time based updater for the window in surfaces mode
---@param gui_data ControlCenterData
---@param update_cycle integer
function CCSurfaces.on_tick_updater(gui_data, update_cycle)
    -- Validating that selected vsurface actually exists
    local selected = gui_data.selected_vsurface
    if selected and not VSurfaceManager.does_vsurface_exist(selected) then
        gui_data.selected_vsurface = nil
        gui_data.surface_submode = nil
        update_left_rebuild_right(gui_data)
        return
    end

    -- updating sections related to selected surface
    if gui_data.selected_vsurface then
        update_compilation_info_section(gui_data)
        if update_cycle % 30 == 0 then
            update_vsurface_info_section(gui_data)
            update_compilation_io_sections(gui_data)
        end
        if update_cycle % 300 == 0 then
            update_validation_report_section(gui_data)
        end
    end

    if update_cycle % 30 == 0 then
        update_tcc_entity_info(gui_data)
        update_computation_display_section(gui_data)
        -- Updating surface submode section
        local submode = gui_data.surface_submode
        if submode then
            local handler = submode_updates[submode]
            if handler then
                handler(gui_data)
            end
        end
    end
end

-------------------------------------------------------------------------------
---------------------------- GUI STATE MANAGEMENT -----------------------------
-------------------------------------------------------------------------------

---Used to set surface submode to provided value. If provided value
---matches with current submode, it's cleared instead.
---@param gui_data ControlCenterData
---@param new_submode string|nil submode value to set
local function toggle_surface_submode(gui_data, new_submode)
    if gui_data.surface_submode == new_submode then
        gui_data.surface_submode = nil
    else
        gui_data.surface_submode = new_submode
        -- new_surface submode is mutually exclusive with vsurface selection
        if new_submode == surface_submodes.new_surface then
            gui_data.selected_vsurface = nil
            -- creating empty table for vsurface configuration data
            gui_data.vsurface_config = {}
        end
        if new_submode == surface_submodes.start_compilation then
            gui_data.new_template_name = nil
        end
    end
    update_left_rebuild_right(gui_data)
end

---Used to set selected vsurface to new value. If provided value
---matches with current selection, it is cleared instead.
---@param gui_data ControlCenterData
---@param new_selection string|nil
local function toggle_vsurface_selection(gui_data, new_selection)
    local old_selection = gui_data.selected_vsurface
    if old_selection == new_selection then
        gui_data.selected_vsurface = nil
    else
        gui_data.selected_vsurface = new_selection
    end
    -- when vsurface selection changes, submode is reset as well
    gui_data.surface_submode = nil
    update_left_rebuild_right(gui_data)
end

-------------------------------------------------------------------------------
-------------------- LEFT FRAME CONTROL ELEMENTS: HANDLERS --------------------
-------------------------------------------------------------------------------

----------------------------- NEW SURFACE BUTTON ------------------------------

---Handles "create new vsurface" button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_new_surface_button(event)
    toggle_surface_submode(
        storage.control_center[event.player_index],
        surface_submodes.new_surface
    )
end

---------------------------- RENAME SURFACE BUTTON ----------------------------

---Handles "rename vsurface" button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_rename_surface_btn(event)
    toggle_surface_submode(
        storage.control_center[event.player_index],
        surface_submodes.rename_surface
    )
end

---------------------------- IDLE SURFACE SELECTOR ----------------------------

---Handles idle surface textfield being changed
---@param event EventData.on_gui_text_changed
function CCSurfaces.handle_idle_surface_search(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.idle_surface_query = event.text
    update_idle_surface_selector(gui_data)
end

---Handles idle surface selector being changed
---@param event EventData.on_gui_selection_state_changed
function CCSurfaces.handle_idle_surface_selector(event)
    local selector = event.element
    local new_selection = selector.get_item(selector.selected_index)
    toggle_vsurface_selection(
        storage.control_center[event.player_index],
        ---@diagnostic disable-next-line
        new_selection
    )
end

---------------------------- DELETE SURFACE BUTTON ----------------------------

---Handles "delete selected vsurface" button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_surface_delete_button(event)
    toggle_surface_submode(
        storage.control_center[event.player_index],
        surface_submodes.delete_surface
    )
end

--------------------------- START COMPILATION BUTTON --------------------------

---Handles "start compilation" button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_compilation_start_button(event)
    toggle_surface_submode(
        storage.control_center[event.player_index],
        surface_submodes.start_compilation
    )
end

-------------------------- COMPILING SURFACE SELECTOR -------------------------

---Handles compiling surface textfield being changed
---@param event EventData.on_gui_text_changed
function CCSurfaces.handle_compiling_surface_search(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.compiling_surface_query = event.text
    update_compiling_surface_selector(gui_data)
end

---Handles compiling surface selector being changed
---@param event EventData.on_gui_selection_state_changed
function CCSurfaces.handle_compiling_surface_selector(event)
    local selector = event.element
    local new_selection = selector.get_item(selector.selected_index)
    toggle_vsurface_selection(
        storage.control_center[event.player_index],
        ---@diagnostic disable-next-line
        new_selection
    )
end

--------------------------- STOP COMPILATION BUTTON ---------------------------

---Handles "stop compilation" button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_compilation_stop_button(event)
    toggle_surface_submode(
        storage.control_center[event.player_index],
        surface_submodes.stop_compilation
    )
end

-------------------------------------------------------------------------------
------------------- RIGHT FRAME CONTROL ELEMENTS: HANDLERS --------------------
-------------------------------------------------------------------------------

------------------------------- TCC ENTITY INFO -------------------------------

---Handles "view TCC entity" button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_view_tcc_button(event)
    local player_index = event.player_index
    local surface_index, pos_x, pos_y = TCCManager.get_tcc_position()
    -- TCC not registed: return
    if not surface_index then return end
    -- TCC is registered: moving player camera to it
    ---@cast pos_x number
    ---@cast pos_y number
    CommonGui.move_player_camera(player_index, surface_index, pos_x, pos_y)
end

------------------------- NEW VSURFACE CONFIGURATION --------------------------

---Handles new vsurface name textfield being changed
---@param event EventData.on_gui_text_changed
function CCSurfaces.handle_new_vsurface_name_textfield(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.vsurface_config.name = event.text
    update_new_vsurface_configuration_section(gui_data)
end

---Handles new vsurface width textfield being changed
---@param event EventData.on_gui_text_changed
function CCSurfaces.handle_new_vsurface_width_changed(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.vsurface_config.width = tonumber(event.text)
    update_new_vsurface_configuration_section(gui_data)
end

---Handles new vsurface height textfield being changed
---@param event EventData.on_gui_text_changed
function CCSurfaces.handle_new_vsurface_height_changed(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.vsurface_config.height = tonumber(event.text)
    update_new_vsurface_configuration_section(gui_data)
end

---Handles new vsurface "generate as" selector being changed
---@param event EventData.on_gui_selection_state_changed
function CCSurfaces.handle_new_vsurface_generate_as_selector(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    local selector = event.element
    ---@type VSurfaceConfig assuming table was created on submode change
    local vsurface_config = gui_data.vsurface_config
    local old_selection = vsurface_config.generate_as
    local new_selection = selector.get_item(selector.selected_index)

    -- if selected item is clicked again, unselecting it
    if old_selection == new_selection then
        vsurface_config.generate_as = nil
        selector.selected_index = 0
    else
        ---@diagnostic disable-next-line
        vsurface_config.generate_as = new_selection
    end
    update_new_vsurface_configuration_section(gui_data)
end

---Handles new vsurface confirm button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_new_vsurface_confirm_button(event)
    local player_index = event.player_index
    ---@type ControlCenterData
    local gui_data = storage.control_center[player_index]
    -- attempting to create requested vsurface
    local status, reason = VSurfaceManager.create_vsurface(gui_data.vsurface_config)
    ---Vsurface was not created: displaying reason in chat
    if not status then CommonGui.print_message(player_index, reason) return end

    ---Vsurface was successfully created: doing cleanup
    -- selecting created surface
    gui_data.selected_vsurface = gui_data.vsurface_config.name
    gui_data.vsurface_config = nil
    gui_data.surface_submode = nil
    update_left_rebuild_right(gui_data)
end

-------------------------- RENAME SELECTED VSURFACE ---------------------------

---Handles new vsurface name (rename) being changed
---@param event EventData.on_gui_text_changed
function CCSurfaces.handle_vsurface_rename_textfield(event)
    local gui_data = storage.control_center[event.player_index]
    gui_data.vsurface_rename_name = event.text
    update_vsurface_rename_section(gui_data)
end

---Handles confirm vsurface rename button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_vsurface_rename_confirm(event)
    local gui_data = storage.control_center[event.player_index]
    local old_name = gui_data.selected_vsurface
    local new_name = gui_data.vsurface_rename_name
    local status = VSurfaceManager.rename_vsurface(old_name, new_name)
    -- rename failed: updating rename section
    if not status then
        update_vsurface_rename_section(gui_data)
        return
    end
    -- rename successful: updating gui state
    gui_data.vsurface_rename_name = nil
    gui_data.selected_vsurface = new_name
    gui_data.surface_submode = nil
    update_left_rebuild_right(gui_data)
end

--------------------------- SELECTED VSURFACE INFO ----------------------------

---Handles view vsurface button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_view_vsurface_btn(event)
    local player_index = event.player_index
    local gui_data = storage.control_center[player_index]
    local surface_index, pos_x, pos_y = VSurfaceManager.get_vsurface_position(
        gui_data.selected_vsurface
    )
    if not surface_index then return end
    ---@cast pos_x number
    ---@cast pos_y number
    CommonGui.move_player_camera(player_index, surface_index, pos_x, pos_y)
end

-------------------------- DELETE SELECTED VSURFACE ---------------------------

---Handles confirm surface deletion button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_confirm_surface_deletion_btn(event)
    local player_index = event.player_index
    ---@type ControlCenterData
    local gui_data = storage.control_center[player_index]
    -- attempting to delete selected vsurface
    local status, reason = VSurfaceManager.delete_vsurface_by_name(
        gui_data.selected_vsurface
    )
    ---Vsurface was not deleted: displaying reason in chat
    if not status then CommonGui.print_message(player_index, reason) return end

    ---Vsurface successfully deleted: doing cleanup
    gui_data.selected_vsurface = nil
    gui_data.surface_submode = nil
    update_left_rebuild_right(gui_data)
end

------------------------------ START COMPILATION ------------------------------

---Handles new template name being changed
---@param event EventData.on_gui_text_changed
function CCSurfaces.handle_new_template_name_textfield(event)
    ---@type ControlCenterData
    local gui_data = storage.control_center[event.player_index]
    gui_data.new_template_name = event.text
    update_confirm_compilation_start_section(gui_data)
end

---Handles confirm compilation button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_confirm_compilation_button(event)
    local player_index = event.player_index
    ---@type ControlCenterData
    local gui_data = storage.control_center[player_index]
    -- attempting to start the compilation of selected vsurface
    local surface_name = gui_data.selected_vsurface
    local template_name = gui_data.new_template_name
    local status, reason = VSurfaceManager.start_compilation(
        surface_name,
        template_name
    )
    ---Compilation was not started: displaying reason in chat
    if not status then CommonGui.print_message(player_index, reason) return end

    ---Compilation successfully started: doing cleanup
    gui_data.new_template_name = nil
    gui_data.surface_submode = nil
    update_left_rebuild_right(gui_data)
end

------------------------------ STOP COMPILATION -------------------------------

---Handles confirm compilation stop button being pressed
---@param event EventData.on_gui_click
function CCSurfaces.handle_confirm_compilation_stop_button(event)
    local player_index = event.player_index
    ---@type ControlCenterData
    local gui_data = storage.control_center[player_index]
    -- attempting to stop the compilation of selected vsurface
    local status, reason = VSurfaceManager.stop_compilation(
        gui_data.selected_vsurface
    )
    ---Compilation was not stopped: displaying reason in chat
    if not status then CommonGui.print_message(player_index, reason) return end

    ---Compilation was stopped successfully: doing cleanup
    gui_data.surface_submode = nil
    update_left_rebuild_right(gui_data)
end

return CCSurfaces