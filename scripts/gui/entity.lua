--[[
Entities added by this mod have custom GUIs that allow player to affect
entity configuration in the entity-processor. It also displays useful
entity-related information (status, current flow, etc.)

Technically entity GUI is handled as follows: when player clicks an entity
from this mod, its "vanilla" GUI is closed and this is opened instead.
For convenience, internal name of this window is the same among all entities,
so technically it's always the same window. However displayed elements
depend on entity name. Both "normal" entities and "ghosts" are supported.

When this window is opened, important data is stored in "gui_data" table.
It includes fields like "entity", "entity_name", etc. As well as references
to elements we want to have quick access to. Data is stored separately for
all players and is located at storage.entity_gui: table<integer, EntityGuiData>
--]]

---Elements that can be used for entity GUIs
---@class EntityGuiElements
---@field main_window LuaGuiElement root frame that contains all elements
---@field left_frame LuaGuiElement left side of interface (used for controls)
---@field right_frame LuaGuiElement right side of interface (used for info display)
---@field input_radiobtn LuaGuiElement|nil used for "io_mode" configuration
---@field output_radiobtn LuaGuiElement|nil used for "io_mode" configuration
---@field item_radiobtn LuaGuiElement|nil used for "operation_mode" configuration
---@field fluid_radiobtn LuaGuiElement|nil used for "operation_mode" configuration
---@field energy_radiobtn LuaGuiElement|nil used for "operation_mode" configuration
---@field item_selection LuaGuiElement|nil used for "selected_item" configuration
---@field fluid_selection LuaGuiElement|nil used for "selected_fluid" configuration
---@field fc_selector LuaGuiElement|nil used for "first_cluster" configuration
---@field sc_selector LuaGuiElement|nil used for "second_cluster" configuration
---@field override_checkbox LuaGuiElement|nil used for "override_capability" config
---@field override_textfield LuaGuiElement|nil used for "override_capability" config
---@field template_selector LuaGuiElement|nil used for "selected_template" config
---@field status_label LuaGuiElement|nil "label" used to display entity status
---@field entity_performance_bar LuaGuiElement|nil "progressbar" performance section
---@field entity_performance_style LuaStyle|nil style of progressbar above
---@field vm_requests_table LuaGuiElement|nil "table" mainframe requests section
---@field vm_requests_btns LuaGuiElement[]|nil "sprite-buttons" requests section
---@field vm_contents_table LuaGuiElement|nil "table" mainframe contents section
---@field vm_contents_btns LuaGuiElement[]|nil "sprite-buttons" contents section

---Contains data related to this window for one player
---@class EntityGuiData
---@field opened boolean|nil true if window is currently open
---@field player LuaPlayer for which window is opened
---@field elements EntityGuiElements
---@field entity LuaEntity entity that was opened to create this gui
---@field unit_number integer unique entity identifier
---@field entity_name string name of this entity or ghost-entity
---@field is_ghost boolean true if opened entity is a ghost
---@field surface_index integer entity.surface_index
---@field fc_query string|nil first cluster search query
---@field sc_query string|nil second cluster search query
---@field template_query string|nil template search query


local EntityProcessor = require("scripts.world.entity-processor")
local EntityInfo = require("scripts.world.e-processor-modules.entity-info")
local ClusterProcessor = require("scripts.simulation.cluster-processor")
local ControlCenter = require("scripts.gui.control-center")
local TCCManager = require("scripts.simulation.tcc-manager")
local CommonGui = require("scripts.gui.common")
local GuiUpdater = require("scripts.gui.updater")


local PREFIX = "FV-"
local EntityGui = {}

-------------------------------------------------------------------------------
----------------- LEFT FRAME ELEMENTS (ENTITY CONFIGURATION) ------------------
-------------------------------------------------------------------------------

---@enum
local io_modes = {input = "input", output = "output"}
---@enum
local operation_modes = {item = "item", fluid = "fluid", energy = "energy"}

----------------------------------- IO MODE -----------------------------------

---Updates "io_mode" configurator according to entity gui
---@param gui_data EntityGuiData table with window-related data
local function update_io_mode_configurator(gui_data)
    local elements = gui_data.elements
    local input_btn = elements.input_radiobtn
    if not input_btn or not input_btn.valid then return end
    local output_btn = elements.output_radiobtn
    if not output_btn or not output_btn.valid then return end
    local io_mode = EntityProcessor.get_io_mode(gui_data.entity)
    input_btn.state = (io_mode == io_modes.input)
    output_btn.state = (io_mode == io_modes.output)
end

---Adds 2 radiobuttons used to configure "io_mode" for entity
---@param parent LuaGuiElement elements will be added here
---@param gui_data EntityGuiData table with window-related data
---@param subtitle LocalisedString caption above radiobuttons
---@param input_caption LocalisedString caption near "input" button
---@param output_caption LocalisedString caption near "output" button
local function add_io_mode_configurator(
    parent,
    gui_data,
    subtitle,
    input_caption,
    output_caption
)
    local v_flow = parent.add{type = "flow", direction = "vertical"}
    v_flow.add{type = "label", caption = subtitle}

    -- Input button
    local row = v_flow.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local button = row.add{
        type = "radiobutton",
        name = PREFIX .. "entity-input-radiobtn",
        state = false
    }
    row.add{type = "label", caption = input_caption}
    gui_data.elements.input_radiobtn = button

    -- Output button
    row = v_flow.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    button = row.add{
        type = "radiobutton",
        name = PREFIX .. "entity-output-radiobtn",
        state = false
    }
    row.add{type = "label", caption = output_caption}
    gui_data.elements.output_radiobtn = button

    update_io_mode_configurator(gui_data)
end

---Handles input/output radiobutton being pressed
---@param player_index integer unique player identifier
---@param io_mode "input"|"output" chosen io mode
local function handle_io_radiobtn(player_index, io_mode)
    local gui_data = storage.entity_gui[player_index]
    EntityProcessor.set_io_mode(gui_data.entity, io_mode)
    update_io_mode_configurator(gui_data)
end

---Handles input radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.handle_input_radiobtn(event)
    handle_io_radiobtn(event.player_index, io_modes.input)
end

---Handles output radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.handle_output_radiobtn(event)
    handle_io_radiobtn(event.player_index, io_modes.output)
end

-------------------------------- SELECTED ITEM --------------------------------

---Entities for which item/fluid selection should be enabled only
---when "operation_mode" is appropriate
local mode_sensitive_entities = {
    [PREFIX .. "inter-cluster-bridge-mk1"] = true,
    [PREFIX .. "inter-cluster-bridge-mk2"] = true,
    [PREFIX .. "inter-cluster-bridge-mk3"] = true,
    [PREFIX .. "cluster-overflow-controller-mk1"] = true,
    [PREFIX .. "cluster-overflow-controller-mk2"] = true,
    [PREFIX .. "cluster-overflow-controller-mk3"] = true,
    [PREFIX .. "cluster-storage-unit-mk1"] = true,
    [PREFIX .. "cluster-storage-unit-mk2"] = true,
    [PREFIX .. "cluster-storage-unit-mk3"] = true,
}

---Updates "selected_item" configurator according to gui data
---@param gui_data EntityGuiData table with window-related data
local function update_selected_item_configurator(gui_data)
    local button = gui_data.elements.item_selection
    if not button or not button.valid then return end

    -- setting elem value for button according to entity processor data
    local entity = gui_data.entity
    local name, quality = EntityProcessor.get_selected_item(entity)
    button.elem_value = (
        name and quality and {name = name, quality = quality} or nil
    )

    -- enabling/disabling the button if necessery
    local entity_name = gui_data.entity_name
    if mode_sensitive_entities[entity_name] then
        local operation_mode = EntityProcessor.get_operation_mode(entity)
        button.enabled = (operation_mode == operation_modes.item)
    end
end

---Adds "choose-elem-button" used to configure "selected_item"
---@param parent LuaGuiElement elements will be added here
---@param gui_data EntityGuiData table with window-related data
local function add_selected_item_configurator(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local button = row.add{
        type = "choose-elem-button",
        name = PREFIX .. "entity-item-selection",
        elem_type = "item-with-quality",
    }
    row.add{type="label", caption={"entity-gui.select-item"}}
    gui_data.elements.item_selection = button
    update_selected_item_configurator(gui_data)
end

---Handles "selected_item" configurator being changed
---@param event EventData.on_gui_elem_changed
function EntityGui.handle_item_selection(event)
    local gui_data = storage.entity_gui[event.player_index]
    local selection = event.element.elem_value
    local name = selection and selection.name
    local quality = selection and selection.quality
    ---@diagnostic disable-next-line
    EntityProcessor.set_selected_item(gui_data.entity, name, quality)
    update_selected_item_configurator(gui_data)
end

------------------------------- SELECTED FLUID --------------------------------

---Updates "selected_fluid" configurator according to gui data
---@param gui_data EntityGuiData
local function update_selected_fluid_configurator(gui_data)
    local button = gui_data.elements.fluid_selection
    if not button or not button.valid then return end

    -- setting elem value for button according to entity processor data
    local entity = gui_data.entity
    local fluid_name = EntityProcessor.get_selected_fluid(entity)
    button.elem_value = fluid_name or nil

    -- enabling/disabling the button if necessery
    local entity_name = gui_data.entity_name
    if mode_sensitive_entities[entity_name] then
        local operation_mode = EntityProcessor.get_operation_mode(entity)
        button.enabled = (operation_mode == operation_modes.fluid)
    end
end

---Adds "choose-elem-button" used to configure "selected_fluid"
---@param parent LuaGuiElement elements will be added here
---@param gui_data EntityGuiData table with window-related data
local function add_selected_fluid_configurator(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "horizontal"}
    flow.style.vertical_align = "center"
    local button = flow.add{
        type = "choose-elem-button",
        name = PREFIX .. "entity-fluid-selection",
        elem_type = "fluid",
    }
    flow.add{type = "label", caption = {"entity-gui.select-fluid"}}
    gui_data.elements.fluid_selection = button
    update_selected_fluid_configurator(gui_data)
end

---Handles "selected_fluid" configurator being changed
---@param event EventData.on_gui_elem_changed
function EntityGui.handle_fluid_selection(event)
    local gui_data = storage.entity_gui[event.player_index]

    -- saving selection to entity processor
    local fluid_name = event.element.elem_value
    ---@diagnostic disable-next-line: param-type-mismatch
    EntityProcessor.set_selected_fluid(gui_data.entity, fluid_name)
    update_selected_fluid_configurator(gui_data)
end

------------------------------- OPERATION MODE --------------------------------

---Updates "operation_mode" configurator according to gui data
---@param gui_data EntityGuiData table with window-related data
local function update_operation_mode_configurator(gui_data)
    local elements = gui_data.elements
    local item_btn = elements.item_radiobtn
    if not item_btn or not item_btn.valid then return end
    local fluid_btn = elements.fluid_radiobtn
    if not fluid_btn or not fluid_btn.valid then return end
    local energy_btn = elements.energy_radiobtn
    if not energy_btn or not energy_btn.valid then return end
    local operation_mode = EntityProcessor.get_operation_mode(gui_data.entity)
    item_btn.state = (operation_mode == operation_modes.item)
    fluid_btn.state = (operation_mode == operation_modes.fluid)
    energy_btn.state = (operation_mode == operation_modes.energy)
end

---Adds 3 radio buttons used to configure "operation_mode"
---@param parent LuaGuiElement elements will be added here
---@param gui_data EntityGuiData table with window-related data
local function add_operation_mode_configurator(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{type = "label", caption = {"entity-gui.select-operation-mode"}}

    -- Item mode radiobutton
    local row = flow.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local button = row.add{
        type = "radiobutton",
        name = PREFIX .. "entity-item-radiobtn",
        state = false
    }
    row.add{type = "label", caption = {"entity-gui.item"}}
    gui_data.elements.item_radiobtn = button

    -- Fluid mode radiobutton
    row = flow.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    button = row.add{
        type = "radiobutton",
        name = PREFIX .. "entity-fluid-radiobtn",
        state = false
    }
    row.add{type = "label", caption = {"entity-gui.fluid"}}
    gui_data.elements.fluid_radiobtn = button

    -- Energy mode radiobutton
    row = flow.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    button = row.add{
        type = "radiobutton",
        name = PREFIX .. "entity-energy-radiobtn",
        state = false
    }
    row.add{type = "label", caption = {"entity-gui.energy"}}
    gui_data.elements.energy_radiobtn = button

    update_operation_mode_configurator(gui_data)
end

---Handles one of operation mode radiobuttons being pressed
---@param player_index integer unique player identifier
---@param operation_mode "item"|"fluid"|"energy"
local function handle_operation_mode_radiobtn(player_index, operation_mode)
    local gui_data = storage.entity_gui[player_index]
    EntityProcessor.set_operation_mode(gui_data.entity, operation_mode)
    update_operation_mode_configurator(gui_data)
    update_selected_fluid_configurator(gui_data)
    update_selected_item_configurator(gui_data)
end

---Handles item radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.handle_item_radiobtn(event)
    handle_operation_mode_radiobtn(event.player_index, operation_modes.item)
end

---Handles fluid radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.handle_fluid_radiobtn(event)
    handle_operation_mode_radiobtn(event.player_index, operation_modes.fluid)
end

---Handles energy radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.handle_energy_radiobtn(event)
    handle_operation_mode_radiobtn(event.player_index, operation_modes.energy)
end

-------------------------------- FIRST CLUSTER --------------------------------

---For these any cluster can be selected regardless of surface
local access_interfaces = {
    [PREFIX .. "template-access-interface-mk1"] = true,
    [PREFIX .. "template-access-interface-mk2"] = true,
    [PREFIX .. "template-access-interface-mk3"] = true,
}

---Updates "first_cluster" configurator according to gui data
---@param gui_data EntityGuiData table with window-related data
local function update_first_cluster_configurator(gui_data)
    local selector = gui_data.elements.fc_selector
    if not selector or not selector.valid then return end

    -- Gathering displayed options
    local options
    if access_interfaces[gui_data.entity_name] then
        -- All clusters for access interfaces
        options = ClusterProcessor.get_all_clusters(gui_data.fc_query)
    else
        -- All clusters on the same surface as entity for other entities
        options = ClusterProcessor.get_surface_clusters(
            gui_data.surface_index,
            gui_data.fc_query
        )
    end

    -- Getting display name of selected cluster
    local selected_uuid = EntityProcessor.get_first_cluster(gui_data.entity)
    local selected_name = ClusterProcessor.get_cluster_name(selected_uuid)
    CommonGui.update_selector(selector, options, selected_name)
end

---Adds "list-box" used to configure "first_cluster". Also adds "textfield"
---for searching and caption above it.
---@param parent LuaGuiElement elements will be added here
---@param gui_data EntityGuiData table with window-related data
---@param subtitle LocalisedString caption at the top of "textfield" element
---@param height number|nil height of "list-box", defaults to 200
local function add_first_cluster_configurator(
    parent,
    gui_data,
    subtitle,
    height
)
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "entity-fc-search",
        PREFIX .. "entity-fc-selector",
        nil,
        subtitle,
        height
    )
    search.text = gui_data.fc_query or ""
    gui_data.elements.fc_selector = selector
    update_first_cluster_configurator(gui_data)
    CommonGui.scroll_to_selection(selector)
end

---Handles first cluster search query being changed
---@param event EventData.on_gui_text_changed
function EntityGui.handle_first_cluster_search(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.fc_query = event.element.text
    update_first_cluster_configurator(gui_data)
end

---Handles first cluster selection being changed
---@param event EventData.on_gui_selection_state_changed
function EntityGui.handle_first_cluster_selection(event)
    local gui_data = storage.entity_gui[event.player_index]
    local entity = gui_data.entity
    local old_uuid = EntityProcessor.get_first_cluster(entity)
    local selector = event.element
    local new_name = selector.get_item(selector.selected_index)
    ---@diagnostic disable-next-line: param-type-mismatch
    local new_uuid = ClusterProcessor.get_cluster_uuid(new_name)

    -- Clicking already selected item results in selection being cleared
    local selection
    if old_uuid == new_uuid then
        selection = nil
    else
        selection = new_uuid
    end
    EntityProcessor.set_first_cluster(entity, selection)
    update_first_cluster_configurator(gui_data)
end

------------------------------- SECOND CLUSTER --------------------------------

---Updates "second_cluster" configurator according to gui data
---@param gui_data EntityGuiData table with window-related data
local function update_second_cluster_configurator(gui_data)
    local selector = gui_data.elements.sc_selector
    if not selector or not selector.valid then return end
    -- Getting display names for all clusters on entity.surface
    local options = ClusterProcessor.get_surface_clusters(
        gui_data.surface_index,
        gui_data.sc_query
    )
    -- Getting display name of selected cluster
    local selected_uuid = EntityProcessor.get_second_cluster(gui_data.entity)
    local selected_name = ClusterProcessor.get_cluster_name(selected_uuid)
    CommonGui.update_selector(selector, options, selected_name)
end

---Adds "list-box" used to configure "second_cluster". Also adds "textfield"
---for searching and caption above it.
---@param parent LuaGuiElement elements will be added here
---@param gui_data EntityGuiData table with window-related data
---@param subtitle LocalisedString caption at the top of "textfield" element
---@param height number|nil height of "list-box", defaults to 200
local function add_second_cluster_configurator(
    parent,
    gui_data,
    subtitle,
    height
)
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "entity-sc-search",
        PREFIX .. "entity-sc-selector",
        nil,
        subtitle,
        height
    )
    search.text = gui_data.sc_query or ""
    gui_data.elements.sc_selector = selector
    update_second_cluster_configurator(gui_data)
    CommonGui.scroll_to_selection(selector)
end

---Handles second cluster search query being changed
---@param event EventData.on_gui_text_changed
function EntityGui.handle_second_cluster_search(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.sc_query = event.element.text
    update_second_cluster_configurator(gui_data)
end

---Handles second cluster selection being changed
---@param event EventData.on_gui_selection_state_changed
function EntityGui.handle_second_cluster_selection(event)
    local gui_data = storage.entity_gui[event.player_index]
    local entity = gui_data.entity
    local old_uuid = EntityProcessor.get_second_cluster(entity)
    local selector = event.element
    local new_name = selector.get_item(selector.selected_index)
    ---@diagnostic disable-next-line: param-type-mismatch
    local new_uuid = ClusterProcessor.get_cluster_uuid(new_name)

    -- Clicking already selected item results in selection being cleared
    local selection
    if old_uuid == new_uuid then
        selection = nil
    else
        selection = new_uuid
    end
    EntityProcessor.set_second_cluster(entity, selection)
    update_second_cluster_configurator(gui_data)
end

----------------------------- CAPABILITY OVERRIDE -----------------------------

---Updates "capability_override" configurator according to gui data
---@param gui_data EntityGuiData table with window-related data
local function update_capability_override_configurator(gui_data)
    local elements = gui_data.elements
    local textfield = elements.override_textfield
    if not textfield or not textfield.valid then return end
    local checkbox = elements.override_checkbox
    if not checkbox or not checkbox.valid then return end

    local state = checkbox.state
    -- enabling/disabling second row based on checkbox state
    for _, child in ipairs(textfield.parent.children) do
        child.enabled = state
    end

    -- Setting override value according to data from entity processor
    local override = EntityProcessor.get_capability_override(gui_data.entity)
    local override_percent = override and override * 100
    textfield.text = CommonGui.number_to_string(override_percent, 2)
end

---Adds "textfield" used to configure "capability_override" and
---a checkbox that enables it.
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData table with window-related data
---@param checkbox_caption LocalisedString caption to display by checkbox
---@param textfield_caption LocalisedString caption to display by textbox
local function add_capability_override_configurator(
    parent,
    gui_data,
    checkbox_caption,
    textfield_caption
)
    local flow = parent.add{type = "flow", direction = "vertical"}

    -- First row: label and checkbox that enables the second row
    local row = flow.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local override = EntityProcessor.get_capability_override(gui_data.entity)
    local checkbox = row.add{
        type = "checkbox",
        name = PREFIX .. "entity-override-checkbox",
        state = not not override
    }
    row.add{type = "label", caption = checkbox_caption}
    gui_data.elements.override_checkbox = checkbox

    -- Second row: override textfield and 2 labels
    row = flow.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    row.add{type = "label", caption = textfield_caption}
    local textfield = row.add{
        type = "textfield",
        name = PREFIX .. "entity-override-textfield",
        numeric = true,
        allow_decimal = true,
        allow_negative = false,
        lose_focus_on_confirm = true,
    }
    row.add{type = "label", caption = "%"}
    textfield.style.width = 75
    gui_data.elements.override_textfield = textfield
    update_capability_override_configurator(gui_data)
end

---Handles "capability_override" checkbox being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.handle_override_checkbox(event)
    local gui_data = storage.entity_gui[event.player_index]
    local state = event.element.state
    -- if checkbox was disabled, clearing capability override
    if not state then
        EntityProcessor.set_capability_override(gui_data.entity, nil)
    end
    update_capability_override_configurator(gui_data)
end

---Handles "capability_override" textfield being changed
---@param event EventData.on_gui_text_changed
function EntityGui.handle_override_textfield(event)
    local gui_data = storage.entity_gui[event.player_index]
    local textfield = event.element
    local input_text = textfield.text
    local value = tonumber(input_text)

    -- If provided value is greater than 100, setting it to 100
    if value and value > 100 then
        value = 100
        textfield.text = "100"
    end

    -- assuming that value cannot be a negative number
    local override_value = value and value / 100
    EntityProcessor.set_capability_override(gui_data.entity, override_value)
end

----------------------------- OVERFLOW THRESHOLD ------------------------------

---Adds "textfield", which is used to configure "overflow_threshold"
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData table with window-related data
local function add_overflow_threshold_configurator(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "horizontal"}
    flow.style.vertical_align = "center"
    flow.add{type = "label", caption = {"entity-gui.overflow-threshold"}}
    local textfield = flow.add{
        type = "textfield",
        name = PREFIX .. "entity-overflow-threshold",
        numeric = true,
        allow_decimal = true,
        allow_negative = false,
        lose_focus_on_confirm = true,
    }
    flow.add{type = "label", caption = "%"}
    textfield.style.width = 75

    -- setting threshold value to match data from entity processor
    local threshold = EntityProcessor.get_overflow_threshold(gui_data.entity)
    local percent_value = threshold and (threshold * 100)
    textfield.text = CommonGui.number_to_string(percent_value, 2)
end

---Handles "overflow_threshold" being changed
---@param event EventData.on_gui_text_changed
function EntityGui.handle_overflow_threshold(event)
    local gui_data = storage.entity_gui[event.player_index]
    local textfield = event.element
    local input_text = textfield.text
    local value = tonumber(input_text)

    -- if provided value is greater than 100, setting it to 100
    if value and value > 100 then
        value = 100
        textfield.text = "100"
    end

    -- assuming that value cannot be a negative number
    local threshold = value and value / 100
    EntityProcessor.set_overflow_threshold(gui_data.entity, threshold)
end

------------------------------ SELECTED TEMPLATE ------------------------------

---Updates "selected_template" configurator according to gui data
---@param gui_data EntityGuiData table with window-related data
local function update_selected_template_configurator(gui_data)
    local selector = gui_data.elements.template_selector
    if not selector or not selector.valid then return end
    -- Getting display names of all templates
    local options = TCCManager.get_template_names(gui_data.template_query)
    -- Getting display name of selected template
    local uuid = EntityProcessor.get_selected_template(gui_data.entity)
    local selected_name = TCCManager.get_template_name(uuid)
    CommonGui.update_selector(selector, options, selected_name)
end

---Adds "list-box" used to configure "selected_template". Also adds "textfield"
---for searching and caption above it.
---@param parent LuaGuiElement elements will be added here
---@param gui_data EntityGuiData table with window-related data
local function add_selected_template_configurator(parent, gui_data)
    local search, selector = CommonGui.add_selection_widget(
        parent,
        PREFIX .. "entity-template-search",
        PREFIX .. "entity-template-selector",
        nil,
        {"entity-gui.select-template"},
        150
    )
    search.text = gui_data.template_query or ""
    gui_data.elements.template_selector = selector
    update_selected_template_configurator(gui_data)
    CommonGui.scroll_to_selection(selector)
end

---Handles "selected_template" search query being changed
---@param event EventData.on_gui_text_changed
function EntityGui.handle_selected_template_search(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.template_query = event.element.text
    update_selected_template_configurator(gui_data)
end

---Handles "selected_template" being changed
---@param event EventData.on_gui_selection_state_changed
function EntityGui.handle_selected_template_selection(event)
    local gui_data = storage.entity_gui[event.player_index]
    local entity = gui_data.entity
    local old_uuid = EntityProcessor.get_selected_template(entity)
    local selector = event.element
    local new_name = selector.get_item(selector.selected_index)
    ---@diagnostic disable-next-line: param-type-mismatch
    local new_uuid = TCCManager.get_template_uuid(new_name)

    -- Clicking already selected item results in selection being cleared
    local selection
    if old_uuid == new_uuid then
        selection = nil
    else
        selection = new_uuid
    end
    EntityProcessor.set_selected_template(entity, selection)
    update_selected_template_configurator(gui_data)
end

----------------------------- TCC ENTITY BUTTONS ------------------------------

---Adds button used to show TCC proximity radius
---@param parent LuaGuiElement elements will be added here
local function add_proximity_radius_buttons(parent)
    local button = parent.add{
        type = "button",
        name = PREFIX .. "entity-proximity-chart",
        caption = {"entity-gui.render-proximity-chart"}
    }
    button.style.horizontally_stretchable = true
    button = parent.add{
        type = "button",
        name = PREFIX .. "entity-proximity-world",
        caption = {"entity-gui.render-proximity-world"}
    }
    button.style.horizontally_stretchable = true
    button = parent.add{
        type = "button",
        name = PREFIX .. "entity-open-cc",
        caption = {"entity-gui.open-cc"}
    }
    button.style.horizontally_stretchable = true
end

---Handles "render proximity (chart)" button being pressed
---@param event EventData.on_gui_click
function EntityGui.handle_proximity_chart_btn(event)
    TCCManager.toggle_proximity_render_chart()
end

---Handles "render proximity (world)" button being pressed
---@param event EventData.on_gui_click
function EntityGui.handle_proximity_world_btn(event)
    TCCManager.toggle_proximity_render_game()
end

---Handles "open CC GUI" button being pressed
---@param event EventData.on_gui_click
function EntityGui.handle_open_cc_btn(event)
    -- Opening control center GUI window
    ---@diagnostic disable-next-line: missing-fields
    ControlCenter.handle_hotkey{
        player_index = event.player_index
    }
end

-------------------------------------------------------------------------------
------------------ RIGHT FRAME ELEMENTS (ENTITY INFORMATION) ------------------
-------------------------------------------------------------------------------

--------------------------- STATUS DISPLAY SECTION ----------------------------

---Gets entity status caption
---@param gui_data EntityGuiData table with window-related data
---@return LocalisedString
local function get_entity_status(gui_data)
    local entity = gui_data.entity
    if not entity.valid then
        return {"entity-status.invalid"}
    end
    if gui_data.is_ghost then
        return {"entity-status.ghost"}
    end
    return EntityInfo.get_entity_status(gui_data.unit_number)
end

---Updates section used to display entity status
---@param gui_data EntityGuiData table with window-related data
local function update_status_section(gui_data)
    local label = gui_data.elements.status_label
    if not label or not label.valid then return end
    label.caption = get_entity_status(gui_data)
end

---Adds section used to display entity status
---@param parent LuaGuiElement section will be added gere
---@param gui_data EntityGuiData table with window-related data
local function add_status_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"entity-gui.entity-status"}
    )
    local label = section.add{type = "label"}
    label.style.single_line = false
    gui_data.elements.status_label = label
    update_status_section(gui_data)
end

------------------------- ENTITY PERFORMANCE SECTION --------------------------

---Updates section used to display entity performance (ls_flow/flow_limit)
---@param gui_data EntityGuiData table with window-related data
local function update_entity_performance_section(gui_data)
    local elements = gui_data.elements
    local bar = elements.entity_performance_bar
    if not bar or not bar.valid then return end
    ---@type LuaStyle
    local style = elements.entity_performance_style

    local curr, max = EntityInfo.get_entity_performance(gui_data.unit_number)
    local bar_caption = {
        "entity-gui.bar-text",
        CommonGui.large_number_to_string(curr),
        CommonGui.large_number_to_string(max)
    }

    local bar_value = (max ~= 0) and (curr / max) or 0
    local bar_color
    if bar_value < 0.75 then
        bar_color = CommonGui.green
    else
        bar_color = CommonGui.orange
    end

    bar.value = bar_value
    bar.caption = bar_caption
    style.color = bar_color
end

---Adds section used to display entity performance (ls_flow/flow_limit)
---@param parent LuaGuiElement section will be added gere
---@param gui_data EntityGuiData table with window-related data
local function add_entity_performance_section(parent, gui_data)
    local section = CommonGui.create_info_element_base(
        parent,
        {"entity-gui.entity-performance"}
    )
    local elements = gui_data.elements
    local progressbar = section.add{
        type = "progressbar",
        style = "electric_statistics_progressbar",
    }
    local style = progressbar.style
    style.horizontally_stretchable = true
    elements.entity_performance_bar = progressbar
    ---@diagnostic disable-next-line: assign-type-mismatch
    elements.entity_performance_style = style
    update_entity_performance_section(gui_data)
end

----------------------- MAINFRAME CONTENTS AND REQUESTS -----------------------

---Collects sprite button data from mainframe requests or contents table
---@param mainframe_table table<BufferKeyString, ItemBuffer>
---@param buttons_data SpriteButtonData[] data will be added to this table
local function collect_sprite_button_data(mainframe_table, buttons_data)
    for _, entry in pairs(mainframe_table) do
        local count = entry.count
        if count > 0 then
            local name = entry.name
            buttons_data[#buttons_data + 1] = {
                sprite = "item/" .. name,
                -- items can have localization as entities
                tooltip = {
                    "?",
                    ---@diagnostic disable-next-line
                    {"item-name." .. name},
                    ---@diagnostic disable-next-line
                    {"entity-name." .. name}
                },
                count = count,
                quality = entry.quality
            }
        end
    end
end

---Adds 2 section used to display mainframe requests and contents
---@param gui_data EntityGuiData table with window-related data
local function update_mainframe_tables(gui_data)
    local elements = gui_data.elements
    local requests, contents = EntityInfo.get_vm_tables(gui_data.unit_number)

    -- Updating missing materials table
    local btn_table = elements.vm_requests_table
    if not btn_table or not btn_table.valid then return end
    ---@type LuaGuiElement[] assuming table exists and valid with btn_table
    local buttons = elements.vm_requests_btns
    local buttons_data = {}
    collect_sprite_button_data(requests, buttons_data)
    CommonGui.update_sprite_button_table(
        btn_table,
        buttons,
        buttons_data
    )

    -- Updating collected materials table
    btn_table = elements.vm_contents_table
    if not btn_table or not btn_table.valid then return end
    ---@type LuaGuiElement[] assuming table exists and valid with btn_table
    buttons = elements.vm_contents_btns
    buttons_data = {}
    collect_sprite_button_data(contents, buttons_data)
    CommonGui.update_sprite_button_table(
        btn_table,
        buttons,
        buttons_data
    )
end

---Adds 2 section used to display mainframe requests and contents
---@param parent LuaGuiElement section will be added gere
---@param gui_data EntityGuiData table with window-related data
local function add_mainframe_tables(parent, gui_data)
    local elements = gui_data.elements

    -- Requests section
    local section = CommonGui.create_info_element_base(
        parent,
        {"entity-gui.missing-materials"}
    )
    elements.vm_requests_table = CommonGui.add_sprite_button_table(section)
    elements.vm_requests_btns = {}

    -- Contents section
    section = CommonGui.create_info_element_base(
        parent,
        {"entity-gui.collected-materials"}
    )
    elements.vm_contents_table = CommonGui.add_sprite_button_table(section)
    elements.vm_contents_btns = {}

    update_mainframe_tables(gui_data)
end

-------------------------------------------------------------------------------
------------------------------ GUI CONSTRUCTION -------------------------------
-------------------------------------------------------------------------------

---Creates a base for entity GUI window. Also initializes EntityGuiData
---table in storage for given player. Assuming that this window is not
---opened when this function is called
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
---@return EntityGuiData
local function create_entity_gui_base(player, entity)
    -- Main window creation
    local entity_name = entity.name
    local is_ghost = entity_name == "entity-ghost"
    if is_ghost then
        entity_name = entity.ghost_name
    end
    local title = {"entity-name." .. entity_name}
    local main_window = CommonGui.create_base_window(
        player,
        PREFIX .. "entity-window",
        title
    )

    -- Horizontal flow for other frames
    local main_flow = main_window.add{
        type = "flow",
        direction="horizontal",
    }
    main_flow.style.height = 600

    -- Left half of interface: control elements
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
    local style = left_flow.style
    style.width = 200
    style.vertically_stretchable = true
    style.vertical_spacing = 12

    -- Right half of interface: info elements
    local right_frame = main_flow.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical"
    }
    local right_pane = right_frame.add{
        type = "scroll-pane",
        vertical_scroll_policy = "always",
    }
    style = right_pane.style
    style.width = 444
    style.vertically_stretchable = true

    -- Initializing "gui_data" in storage for given player
    local player_index = player.index
    local entity_gui = storage.entity_gui
    ---@diagnostic disable-next-line: missing-fields
    if not entity_gui[player_index] then entity_gui[player_index] = {} end
    local gui_data = entity_gui[player_index]
    gui_data.opened = true
    gui_data.elements = {
        main_window = main_window,
        left_frame = left_flow,
        right_frame = right_pane,
    }
    gui_data.entity = entity
    gui_data.unit_number = entity.unit_number
    gui_data.entity_name = entity_name
    gui_data.is_ghost = is_ghost
    gui_data.surface_index = entity.surface_index
    gui_data.player = player

    player.opened = main_window
    GuiUpdater.register_gui("entity", gui_data, player)
    return gui_data
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_inter_cluster_bridge_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_operation_mode_configurator(left_frame, gui_data)
    add_selected_item_configurator(left_frame, gui_data)
    add_selected_fluid_configurator(left_frame, gui_data)
    add_first_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-s-cluster"},
        90
    )
    add_second_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-d-cluster"},
        90
    )
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-flow-limit-override"},
        {"entity-gui.set-flow-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_energy_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_io_mode_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-transfer-direction"},
        {"entity-gui.world-to-cluster"},
        {"entity-gui.cluster-to-world"}
    )
    add_first_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-cluster"}
    )
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-flow-limit-override"},
        {"entity-gui.set-flow-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_fluid_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_io_mode_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-transfer-direction"},
        {"entity-gui.world-to-cluster"},
        {"entity-gui.cluster-to-world"}
    )
    add_selected_fluid_configurator(left_frame, gui_data)
    add_first_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-cluster"}
    )
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-flow-limit-override"},
        {"entity-gui.set-flow-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_item_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_io_mode_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-transfer-direction"},
        {"entity-gui.world-to-cluster"},
        {"entity-gui.cluster-to-world"}
    )
    add_selected_item_configurator(left_frame, gui_data)
    add_first_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-cluster"}
    )
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-flow-limit-override"},
        {"entity-gui.set-flow-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_overflow_controller_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_operation_mode_configurator(left_frame, gui_data)
    add_selected_item_configurator(left_frame, gui_data)
    add_selected_fluid_configurator(left_frame, gui_data)
    add_first_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-cluster"},
        150
    )
    add_overflow_threshold_configurator(left_frame, gui_data)
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-flow-limit-override"},
        {"entity-gui.set-flow-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_storage_unit_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_operation_mode_configurator(left_frame, gui_data)
    add_selected_item_configurator(left_frame, gui_data)
    add_selected_fluid_configurator(left_frame, gui_data)
    add_io_mode_configurator(
        left_frame,
        gui_data,
        {"entity-gui.add-capacity-to"},
        {"entity-gui.input"},
        {"entity-gui.output"}
    )
    add_first_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-cluster"},
        100
    )
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-capacity-override"},
        {"entity-gui.set-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_access_interface_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_io_mode_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-transfer-mode"},
        {"entity-gui.receive"},
        {"entity-gui.transmit"}
    )
    add_selected_template_configurator(left_frame, gui_data)
    add_first_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-cluster"},
        150
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_computation_array_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-computation-override"},
        {"entity-gui.set-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_control_center_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    add_proximity_radius_buttons(left_frame)

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_energy_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_io_mode_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-entity-mode"},
        {"entity-gui.energy-source"},
        {"entity-gui.energy-sink"}
    )
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-flow-limit-override"},
        {"entity-gui.set-flow-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_fluid_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_io_mode_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-entity-mode"},
        {"entity-gui.fluid-source"},
        {"entity-gui.fluid-sink"}
    )
    add_selected_fluid_configurator(left_frame, gui_data)
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-flow-limit-override"},
        {"entity-gui.set-flow-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_item_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_io_mode_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-entity-mode"},
        {"entity-gui.item-source"},
        {"entity-gui.item-sink"}
    )
    add_selected_item_configurator(left_frame, gui_data)
    add_capability_override_configurator(
        left_frame,
        gui_data,
        {"entity-gui.enable-flow-limit-override"},
        {"entity-gui.set-flow-limit-to"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_entity_performance_section(right_frame, gui_data)
end

---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_virtualization_mainframe_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)

    -- Configuration elements
    local left_frame = gui_data.elements.left_frame
    add_first_cluster_configurator(
        left_frame,
        gui_data,
        {"entity-gui.select-cluster"}
    )

    -- Information elements
    local right_frame = gui_data.elements.right_frame
    add_status_section(right_frame, gui_data)
    add_mainframe_tables(right_frame, gui_data)
end

-------------------------------------------------------------------------------
---------------------------- OPEN/CLOSE ENTITY GUI ----------------------------
-------------------------------------------------------------------------------

---Maps entity names to functions used to construct their GUIs
local entity_gui_router = {
    [PREFIX .. "inter-cluster-bridge-mk1"] = create_inter_cluster_bridge_gui,
    [PREFIX .. "inter-cluster-bridge-mk2"] = create_inter_cluster_bridge_gui,
    [PREFIX .. "inter-cluster-bridge-mk3"] = create_inter_cluster_bridge_gui,
    [PREFIX .. "cluster-energy-io-mk1"] = create_cluster_energy_io_gui,
    [PREFIX .. "cluster-energy-io-mk2"] = create_cluster_energy_io_gui,
    [PREFIX .. "cluster-energy-io-mk3"] = create_cluster_energy_io_gui,
    [PREFIX .. "cluster-fluid-io-mk1"] = create_cluster_fluid_io_gui,
    [PREFIX .. "cluster-fluid-io-mk2"] = create_cluster_fluid_io_gui,
    [PREFIX .. "cluster-fluid-io-mk3"] = create_cluster_fluid_io_gui,
    [PREFIX .. "cluster-item-io-mk1"] = create_cluster_item_io_gui,
    [PREFIX .. "cluster-item-io-mk2"] = create_cluster_item_io_gui,
    [PREFIX .. "cluster-item-io-mk3"] = create_cluster_item_io_gui,
    [PREFIX .. "cluster-overflow-controller-mk1"] = create_cluster_overflow_controller_gui,
    [PREFIX .. "cluster-overflow-controller-mk2"] = create_cluster_overflow_controller_gui,
    [PREFIX .. "cluster-overflow-controller-mk3"] = create_cluster_overflow_controller_gui,
    [PREFIX .. "cluster-storage-unit-mk1"] = create_cluster_storage_unit_gui,
    [PREFIX .. "cluster-storage-unit-mk2"] = create_cluster_storage_unit_gui,
    [PREFIX .. "cluster-storage-unit-mk3"] = create_cluster_storage_unit_gui,
    [PREFIX .. "template-access-interface-mk1"] = create_template_access_interface_gui,
    [PREFIX .. "template-access-interface-mk2"] = create_template_access_interface_gui,
    [PREFIX .. "template-access-interface-mk3"] = create_template_access_interface_gui,
    [PREFIX .. "template-computation-array-mk1"] = create_template_computation_array_gui,
    [PREFIX .. "template-computation-array-mk2"] = create_template_computation_array_gui,
    [PREFIX .. "template-computation-array-mk3"] = create_template_computation_array_gui,
    [PREFIX .. "template-control-center-mk1"] = create_template_control_center_gui,
    [PREFIX .. "template-control-center-mk2"] = create_template_control_center_gui,
    [PREFIX .. "template-control-center-mk3"] = create_template_control_center_gui,
    [PREFIX .. "template-energy-io-mk1"] = create_template_energy_io_gui,
    [PREFIX .. "template-energy-io-mk2"] = create_template_energy_io_gui,
    [PREFIX .. "template-energy-io-mk3"] = create_template_energy_io_gui,
    [PREFIX .. "template-fluid-io-mk1"] = create_template_fluid_io_gui,
    [PREFIX .. "template-fluid-io-mk2"] = create_template_fluid_io_gui,
    [PREFIX .. "template-fluid-io-mk3"] = create_template_fluid_io_gui,
    [PREFIX .. "template-item-io-mk1"] = create_template_item_io_gui,
    [PREFIX .. "template-item-io-mk2"] = create_template_item_io_gui,
    [PREFIX .. "template-item-io-mk3"] = create_template_item_io_gui,
    [PREFIX .. "virtualization-mainframe-mk1"] = create_virtualization_mainframe_gui,
    [PREFIX .. "virtualization-mainframe-mk2"] = create_virtualization_mainframe_gui,
    [PREFIX .. "virtualization-mainframe-mk3"] = create_virtualization_mainframe_gui,
}

---Handles gui being opened by the player. If entity from the table above is
---opened, closes it's vanilla gui and opens a custom one.
---@param event EventData.on_gui_opened
function EntityGui.handle_gui_opened(event)
    -- checking opened gui type
    if event.gui_type ~= defines.gui_type.entity then return end
    local entity = event.entity
    if not entity or not entity.valid then return end
    -- getting entity name (handling ghosts)
    local entity_name = entity.name
    if entity_name == "entity-ghost" then entity_name = entity.ghost_name end
    -- checking if we need to open a custom gui
    local handler = entity_gui_router[entity_name]
    if not handler then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    handler(player, entity)
end

---Closes the custom entity gui when player.opened changes from it to something else.
---@param event EventData.on_gui_closed
function EntityGui.handle_entity_gui_closed(event)
    GuiUpdater.close_window(event.player_index)
end

---Handles player being removed from the game (cleanup)
function EntityGui.on_pre_player_removed(event)
    storage.entity_gui[event.player_index] = nil
end

-------------------------------------------------------------------------------
------------------------------- ON-TICK UPDATER -------------------------------
-------------------------------------------------------------------------------

---Used for time-based GUI updates
---@param gui_data EntityGuiData
---@param update_cycle integer counts number of updates for this window
local function on_tick_updater(gui_data, update_cycle)
    -- Checking entity validity
    local entity = gui_data.entity
    if not entity.valid then
        -- closing window for invalid entity
        local player = gui_data.player
        if not player.valid then return end
        player.opened = nil
        return
    end

    if update_cycle % 10 == 0 then
        update_status_section(gui_data)
    end
    if update_cycle % 30 == 0 then
        update_entity_performance_section(gui_data)
    end
    if update_cycle % 60 == 0 then
        update_mainframe_tables(gui_data)
    end
end

GuiUpdater.add_schema("entity", on_tick_updater)

return EntityGui