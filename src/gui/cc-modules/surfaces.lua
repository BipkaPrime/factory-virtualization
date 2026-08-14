--[[
Helps in handling of control center GUI. Contains definitions, configurators
and handlers for GUI elements that are used in "surfaces" mode. As well as
all the logic required to operate the window in this mode.

Control center gui in "surfaces" mode can be used to manage virtualization surfaces.
Create, delete, start compilation, stop compilation, view information
--]]

---@class ControlCenterElements additional LuaGuiElements that can be used in "surfaces" mode
---@field new_surface_btn LuaGuiElement|nil button that is used to open vsurface creation interface
---@field delete_surface_btn LuaGuiElement|nil button that is used to delete selected idle vsurface
---@field idle_surface_search LuaGuiElement|nil textfield above idle surface selector
---@field idle_surface_selector LuaGuiElement|nil selector displaying idle vsurfaces
---@field compiling_surface_search LuaGuiElement|nil textfield above compiling surface selector
---@field compiling_surface_selector LuaGuiElement|nil selector displaying compiling vsurfaces
---@field start_compilation_btn LuaGuiElement|nil start compilation button on the left
---@field stop_compilation_btn LuaGuiElement|nil stop compilation button on the left
---@field computation_progressbar LuaGuiElement|nil displays demand/max computation
---@field new_vsurface_confirm_btn LuaGuiElement|nil button to confirm vsurface creation
---@field new_vsurface_confirm_status LuaGuiElement|nil status label above confirm vsurface creation btn
---@field new_vsurface_demand_idle LuaGuiElement|nil info label showing idle computation demand for new vsurface
---@field new_vsurface_demand_compiling LuaGuiElement|nil info label showing compiling computation demand for new vsurface
---@field new_vsurface_energy_drain LuaGuiElement|nil info label showing template energy drain for new vsurface
---@field confirm_compile_btn LuaGuiElement|nil button used to start compilation of a vsurface
---@field confirm_compile_label LuaGuiElement|nil label above confirm compilation button


---@class ControlCenterData additional fields that can be used in "surfaces" mode
---@field surface_submode string|nil used to handle mutually exclusive gui states
---@field selected_vsurface string|nil name of selected vsurface
---@field idle_surface_query string|nil last user input into idle surfaces textfield
---@field compiling_surface_query string|nil last user input into compiling surfaces textfield
---@field vsurface_config VSurfaceConfig|nil data required for creation of vsurface
---@field new_template_name string|nil name of new template


local CommonGui = require("src.gui.common")
local VSurfaceManager = require("src.world.vsurface-manager")
local ComputationManager = require("src.simulation.computation-manager")

local PREFIX = "FV-"
local CCSurfaces = {}

---All possible submodes of control center in "surfaces" mode.
---Used to handle mutually exclusive GUI states.
local surface_submodes = {
    new_surface = "new_surface",
    delete_selected = "delete_selected",
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
    button.toggled = (gui_data.surface_submode == surface_submodes.new_surface)
end

---Adds "create new vsurface" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_new_surface_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-new-surface-btn",
        caption = {"control-center.create-new-vsurface"},
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.new_surface_btn = button
    update_new_surface_button(gui_data)
end

---------------------------- IDLE SURFACE SELECTOR ----------------------------

---Updates idle vsurface selector
---@param gui_data ControlCenterData
local function update_idle_surface_selector(gui_data)
    local selector = gui_data.elements.idle_surface_selector
    if not selector or not selector.valid then return end
    local options = VSurfaceManager.get_idle_vsurfaces()
    local query = gui_data.idle_surface_query
    local selected = gui_data.selected_vsurface
    -- if selected vsurface is not idle, it's not displayed as selected
    if not VSurfaceManager.is_idle(selected) then
        selected = nil
    end
    CommonGui.configure_selector(selector, options, query, selected)
end

---Updates idle vsurface selector and searchfield above
---@param gui_data ControlCenterData
local function update_idle_surface_selection_widget(gui_data)
    local search = gui_data.elements.idle_surface_search
    if not search or not search.valid then return end
    search.text = gui_data.idle_surface_query or ""
    update_idle_surface_selector(gui_data)
end

---Adds selection widget for idle vsurfaces to given parent element. Widget consists of
---of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_idle_surface_selection_widget(parent, gui_data)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "cc-idle-surface-search",
        PREFIX .. "cc-idle-surface-selector",
        {"control-center.idle-vsurfaces"},
        140
    )
    local elements = gui_data.elements
    elements.idle_surface_search = search
    elements.idle_surface_selector = selector
    update_idle_surface_selection_widget(gui_data)
end

---------------------------- DELETE SURFACE BUTTON ----------------------------

---Updates "delete selected vsurface" button according to gui_data
---@param gui_data ControlCenterData 
local function update_surface_delete_button(gui_data)
    local button = gui_data.elements.delete_surface_btn
    if not button or not button.valid then return end
    -- button is enabled only when surface is selected and idle
    local surface_name = gui_data.selected_vsurface
    button.enabled = VSurfaceManager.is_idle(surface_name)
    -- button is toggled if gui in "delete_selected" submode
    button.toggled = (gui_data.surface_submode == surface_submodes.delete_selected)
end

---Adds "delete selected vsurface" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_surface_delete_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-delete-surface-btn",
        caption = {"control-center.delete-selected-vsurface"},
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
    button.toggled = (gui_data.surface_submode == surface_submodes.start_compilation)
end

---Adds "start compilation" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_compilation_start_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-start-compilation-btn",
        caption = {"control-center.start-compilation"},
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
    local options = VSurfaceManager.get_compiling_vsurfaces()
    local query = gui_data.compiling_surface_query
    local selected = gui_data.selected_vsurface
    -- if selected surface is not compiling, it's not displayed as selected
    if not VSurfaceManager.is_compiling(selected) then
        selected = nil
    end
    CommonGui.configure_selector(selector, options, query, selected)
end

---Updates compiling surface selector and searchfield above
---@param gui_data ControlCenterData
local function update_compiling_surface_selection_widget(gui_data)
    local search = gui_data.elements.compiling_surface_search
    if not search or not search.valid then return end
    search.text = gui_data.compiling_surface_query or ""
    update_compiling_surface_selector(gui_data)
end

---Adds selection widget for compiling vsurfaces to given parent element. Widget consists of
---of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_compiling_surface_selection_widget(parent, gui_data)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "cc-compiling-surface-search",
        PREFIX .. "cc-compiling-surface-selector",
        {"control-center.compiling-vsurfaces"},
        140
    )
    local elements = gui_data.elements
    elements.compiling_surface_search = search
    elements.compiling_surface_selector = selector
    update_compiling_surface_selection_widget(gui_data)
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
    button.toggled = (gui_data.surface_submode == surface_submodes.stop_compilation)
end

---Adds "stop compilation" button to given parent element
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_compilation_stop_button(parent, gui_data)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "cc-stop-compilation-btn",
        caption = {"control-center.stop-compilation"},
        style = "red_button",
    }
    button.style.horizontally_stretchable = true
    gui_data.elements.stop_compilation_btn = button
    update_compilation_stop_button(gui_data)
end

-------------------------------------------------------------------------------
---------------------------- RIGHT FRAME ELEMENTS -----------------------------
-------------------------------------------------------------------------------

----------------------------- COMPUTATION DISPLAY -----------------------------

---Updates section used to display current computation state
---@param gui_data ControlCenterData
local function update_computation_display_section(gui_data)
    local progressbar = gui_data.elements.computation_progressbar
    if not progressbar or not progressbar.valid then return end

    local demand = ComputationManager.get_current_demand()
    local max_available = ComputationManager.get_max_potential()

    -- assembling progressbar caption
    local demand_fmt = CommonGui.large_number_to_string(demand)
    local max_fmt = CommonGui.large_number_to_string(max_available)
    progressbar.caption = demand_fmt .. " / " .. max_fmt

    -- calculating progressbar value and color
    if max_available == 0 then
        if demand == 0 then
            progressbar.value = 0
        else
            progressbar.value = 1
        end
    else
        local value = math.min(demand / max_available, 1)
        progressbar.value = value
        if value <= 0.5 then
            progressbar.style.color = CommonGui.green
        elseif value <= 0.85 then
            progressbar.style.color = CommonGui.yellow
        else
            progressbar.style.color = CommonGui.red
        end
    end
end

---Adds information element displaying computation resource demand/max.
---@param parent LuaGuiElement element will be added here
---@param gui_data ControlCenterData
local function add_computation_display_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"control-center.computation-demand"}
    )
    local progressbar = section.add{
        type = "progressbar",
        style = "electric_statistics_progressbar",
    }
    gui_data.elements.computation_progressbar = progressbar
    progressbar.style.horizontally_stretchable = true
    update_computation_display_section(gui_data)
end

-------------------------- NEW SURFACE CONFIGURATION --------------------------

---Adds textfield for name of new vsurface and label above
---@param parent LuaGuiElement element will be added here
---@param gui_data ControlCenterData
local function add_new_vsurface_name_textfield(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{type = "label", caption = {"control-center.vsurface-name"}}
    local textfield = flow.add{
        type = "textfield",
        name = PREFIX .. "cc-new-vsurface-name",
        lose_focus_on_confirm = true,
    }
    textfield.style.width = 180
    ---Setting text to anything saved in vsurface config
    ---@type VSurfaceConfig assuming table was created on submode change
    local vsurface_config = gui_data.vsurface_config
    if vsurface_config.name then
        textfield.text = vsurface_config.name
    end
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
        {"control-center.width"},
        PREFIX .. "cc-new-vsurface-width"
    )
    local spacer = flow.add{type = "flow"}
    spacer.style.width = 30
    local height_textfield = add_vsurface_size_textfield(
        flow,
        {"control-center.height"},
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
local function update_new_surface_info_labels(gui_data)
    local elements = gui_data.elements
    ---@type VSurfaceConfig assuming it was created on submode change
    local vsurface_config = gui_data.vsurface_config

    ---Idle computation demand
    local idle_label = elements.new_vsurface_demand_idle
    if not idle_label or not idle_label.valid then return end
    local idle_demand = VSurfaceManager.get_idle_computation_demand(vsurface_config)
    local idle_fmt = CommonGui.large_number_to_string(idle_demand)
    ---@diagnostic disable-next-line
    idle_label.caption = {"", {"control-center.idle-computation-demand"}, ": ", idle_fmt}

    ---Compiling computation demand
    local compiling_label = elements.new_vsurface_demand_compiling
    if not compiling_label or not compiling_label.valid then return end
    local compiling_demand = VSurfaceManager.get_compiling_computation_demand(vsurface_config)
    local compiling_fmt = CommonGui.large_number_to_string(compiling_demand)
    ---@diagnostic disable-next-line
    compiling_label.caption = {"", {"control-center.compiling-computation-demand"}, ": ", compiling_fmt}

    ---Template energy drain
    local drain_label = elements.new_vsurface_energy_drain
    if not drain_label or not drain_label.valid then return end
    local energy_drain = VSurfaceManager.get_vsurface_energy_drain(vsurface_config)
    local drain_fmt = CommonGui.large_number_to_string(energy_drain)
    ---@diagnostic disable-next-line
    drain_label.caption = {"", {"control-center.template-energy-drain"}, ": ", drain_fmt, "J"}
end

---Adds new vsurface information labels used to display computation demands,
---template energy drain, etc.
---@param parent LuaGuiElement labels will be added here
---@param gui_data ControlCenterData
local function add_new_surface_info_labels(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    local elements = gui_data.elements
    local idle_label = flow.add{type = "label", style = "bold_label"}
    elements.new_vsurface_demand_idle = idle_label
    local compiling_label = flow.add{type = "label", style = "bold_label"}
    elements.new_vsurface_demand_compiling = compiling_label
    local drain_label = flow.add{type = "label", style = "bold_label"}
    elements.new_vsurface_energy_drain = drain_label
    update_new_surface_info_labels(gui_data)
end

---Adds "generate as" selector which allows to select planet to generate as
---@param parent LuaGuiElement element will be added here
---@param gui_data ControlCenterData
local function add_generate_as_selector(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{type = "label", caption = {"control-center.generate-as"}}
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
    CommonGui.configure_selector(selector, options, nil, selected_option)
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
        caption = {"control-center.confirm"},
        style = "confirm_button",
        tooltip = {"control-center.vsurface-confirm-tooltip"},
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
        {"control-center.new-vsurface-config"}
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
    add_new_surface_info_labels(section, gui_data)

    --Third row: confirm vsurface creation button and label
    add_new_vsurface_confirm_btn(section, gui_data)
end

---Used to update new vsurface configuration section.
---Can be used for time-based updates.
---@param gui_data ControlCenterData
local function update_new_vsurface_configuration_section(gui_data)
    update_new_vsurface_confirm_button(gui_data)
    update_new_surface_info_labels(gui_data)
end

--------------------------- SELECTED VSURFACE INFO ----------------------------

---Adds section displaying information about selected vsurface
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_vsurface_info_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"control-center.vsurface-info"}
    )

end

-------------------------- DELETE SELECTED VSURFACE ---------------------------

---Adds section used for confirmation of vsurface deletion.
---Contains a warning and a button to confirm deletion
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_confirm_vsurface_delete_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"control-center.confirm-vsurface-deletion"}
    )
    local warning = section.add{
        type = "label",
        caption = {
            "control-center.vsurface-deletion-warning",
            ---@diagnostic disable-next-line
            gui_data.selected_vsurface
        },
    }
    warning.style.single_line = false

    -- needed for horizontal alignment of delete button
    local flow = section.add{type = "flow", direction = "horizontal"}
    local flow_style = flow.style
    flow_style.width = 400
    flow_style.horizontal_align = "right"
    flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-vsurface-delete",
        caption = {"control-center.delete"},
        style = "red_confirm_button",
        tooltip = {"control-center.delete-tooltip"},
    }
end

------------------------------ START COMPILATION ------------------------------

---Adds a warning label to "start compilation" section
---@param parent LuaGuiElement
---@param gui_data ControlCenterData
local function add_confirm_compilation_start_warning(parent, gui_data)
    local surface_name = gui_data.selected_vsurface
    local delta_compute = VSurfaceManager.get_compiling_computation_increase(
        surface_name
    )
    local delta_fmt = CommonGui.large_number_to_string(delta_compute)
    local warning = parent.add{
        type = "label",
        ---@diagnostic disable-next-line
        caption = {"control-center.compilation-warning", surface_name, delta_fmt}
    }
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
        caption = {"control-center.template-name"},
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
        caption = {"control-center.start"},
        style = "confirm_button",
        tooltip = {"control-center.compile-start-tooltip"},
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
        {"control-center.confirm-compilation-start"}
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
        {"control-center.confirm-compilation-stop"}
    )

    ---Warning label
    local surface_name = gui_data.selected_vsurface
    local delta_compute = VSurfaceManager.get_compiling_computation_increase(
        surface_name
    )
    local delta_fmt = CommonGui.large_number_to_string(delta_compute)
    local warning = section.add{
        type = "label",
        caption = {
            "control-center.compilation-stop-warning",
            ---@diagnostic disable-next-line
            surface_name, delta_fmt,
        },
    }
    warning.style.single_line = false

    ---Confirmation button
    local flow = section.add{type = "flow", direction = "vertical"}
    local flow_style = flow.style
    flow_style.horizontally_stretchable = true
    flow_style.horizontal_align = "right"
    flow.add{
        type = "button",
        name = PREFIX .. "cc-confirm-compile-stop",
        caption = {"control-center.terminate"},
        style = "red_confirm_button",
        tooltip = {"control-center.compile-stop-tooltip"},
    }
end

-------------------------------------------------------------------------------
------------------------ GUI CONSTRUCTION AND UPDATES -------------------------
-------------------------------------------------------------------------------

---Constructs left side of surface mode interface
---@param gui_data ControlCenterData
function CCSurfaces.construct_left_side(gui_data)
    local left_frame = gui_data.elements.left_frame
    add_new_surface_button(left_frame, gui_data)
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
    [surface_submodes.delete_selected] = add_confirm_vsurface_delete_section,
    [surface_submodes.start_compilation] = add_confirm_compilation_start_section,
    [surface_submodes.stop_compilation] = add_confirm_compilation_stop_section,
}

---Constructs right side of surface mode interface
---@param gui_data ControlCenterData
function CCSurfaces.construct_right_side(gui_data)
    local right_frame = gui_data.elements.right_frame
    ---Computation section is always displayed
    add_computation_display_section(right_frame, gui_data)

    ---Displaying vsurface information if it's selected
    local selected_vsurface = gui_data.selected_vsurface
    if selected_vsurface then
        add_vsurface_info_section(right_frame, gui_data)
    end

    ---If sumbode is selected, displaying corresponding section
    local submode = gui_data.surface_submode
    if submode then
        local constructor = submode_gui_constructors[submode]
        if constructor then
            constructor(right_frame, gui_data)
        end
    end
end

---Used for time-based updates of elements that should be updated
---as frequently as possible. Ideally once every tick.
---@param gui_data ControlCenterData
function CCSurfaces.fast_interface_updater(gui_data)
    update_computation_display_section(gui_data)
    -- TODO:
end

---Used for time-based updates of elements that should
---not be updated frequently. About once per second.
---@param gui_data ControlCenterData
function CCSurfaces.slow_interface_updater(gui_data)
    -- TODO:
end

-------------------------------------------------------------------------------
---------------------------- GUI STATE MANAGEMENT -----------------------------
-------------------------------------------------------------------------------

---Updates all elements in the left frame, rebuilds the right frame
---@param gui_data ControlCenterData
local function update_left_rebuild_right(gui_data)
    update_new_surface_button(gui_data)
    update_idle_surface_selector(gui_data)
    update_surface_delete_button(gui_data)
    update_compilation_start_button(gui_data)
    update_compiling_surface_selector(gui_data)
    update_compilation_stop_button(gui_data)
    gui_data.elements.right_frame.clear()
    CCSurfaces.construct_right_side(gui_data)
end

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
        surface_submodes.delete_selected
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

---Prints given message for given player
---@param player_index integer unique player identifier
---@param message LocalisedString message to print
local function print_message(player_index, message)
    local player = game.get_player(player_index)
    if not player then return end
    player.print(message)
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
    ---@diagnostic disable-next-line
    if not status then print_message(player_index, reason) return end

    ---Vsurface was successfully created: doing cleanup
    -- selecting created surface
    gui_data.selected_vsurface = gui_data.vsurface_config.name
    gui_data.vsurface_config = nil
    gui_data.surface_submode = nil
    update_left_rebuild_right(gui_data)
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
    ---@diagnostic disable-next-line
    if not status then print_message(player_index, reason) return end

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
    ---@diagnostic disable-next-line
    if not status then print_message(player_index, reason) return end

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
    ---@diagnostic disable-next-line
    if not status then print_message(player_index, reason) return end

    ---Compilation was stopped successfully: doing cleanup
    gui_data.surface_submode = nil
    update_left_rebuild_right(gui_data)
end

return CCSurfaces