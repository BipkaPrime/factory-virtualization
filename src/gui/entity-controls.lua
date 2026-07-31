local EntityProcessor = require("src.world.entity-processor")
local TemplateCompiler = require("src.simulation.template-compiler")
local ClusterProcessor = require("src.simulation.cluster-processor")
local CommonGui = require("src.gui.common")


local EntityControls = {}
local PREFIX = "FV-"


---Standart check performed before handling any user inputs. Checks that 
---entity for which gui is opened is still valid. If not, window is closed.
---@return boolean status true if entity is valid
function EntityControls.assert_entity_validity(player_index, gui_data)
    -- checking that entity is valid
    local entity = gui_data.entity
    if not entity.valid then
        local player = game.get_player(player_index)
        if not player then return false end
        player.opened = nil
        return false
    end
    return true
end

-------------------------------------------------------------------------------
-- INPUT/OUTPUT RADIOBUTTONS
-------------------------------------------------------------------------------

---Configures choose input/output radiobuttons
---@param gui_data EntityGuiData
local function configure_choose_io_buttons(gui_data)
    local input_button = gui_data.elements.input_radiobutton
    local output_button = gui_data.elements.output_radiobutton
    ---@cast input_button LuaGuiElement
    ---@cast output_button LuaGuiElement
    if not input_button.valid or not output_button.valid then return end
    local is_output = EntityProcessor.get_output_flag(gui_data.entity)
    input_button.state = not is_output
    output_button.state = not not is_output
end

---Adds 2 radiobuttons to choose IO mode of operation.
---@param parent LuaGuiElement buttons will be added here
---@param gui_data EntityGuiData
function EntityControls.create_choose_io_buttons(parent, gui_data)
    local main_flow = parent.add{type = "flow", direction = "vertical"}
    main_flow.add{type = "label", caption = {"gui-label.operation-mode"}}

    -- input radiobutton
    local row1 = main_flow.add{type = "flow", direction = "horizontal"}
    row1.style.vertical_align = "center"
    local button1 = row1.add{
        type = "radiobutton",
        name = PREFIX .. "input-radiobutton",
        state = false
    }
    row1.add{type = "label", caption = {"gui-label.input"}}
    gui_data.elements.input_radiobutton = button1

    -- output radiobutton
    local row2 = main_flow.add{type = "flow", direction = "horizontal"}
    row2.style.vertical_align = "center"
    local button2 = row2.add{
        type = "radiobutton",
        name = PREFIX .. "output-radiobutton",
        state = false
    }
    row2.add{type = "label", caption = {"gui-label.output"}}
    gui_data.elements.output_radiobutton = button2

    configure_choose_io_buttons(gui_data)
end

---Handles input/output radiobutton being pressed
---@param is_output boolean true if output button is pressed
local function process_io_radiobutton_pressed(player_index, is_output)
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end
    EntityProcessor.set_output_flag(gui_data.entity, is_output)
    configure_choose_io_buttons(gui_data)
end

---Handles input radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityControls.process_input_chosen(event)
    process_io_radiobutton_pressed(event.player_index, false)
end

---Handles output radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityControls.process_output_chosen(event)
    process_io_radiobutton_pressed(event.player_index, true)
end

-------------------------------------------------------------------------------
-- FIRST TEMPLATE SELECTOR
-------------------------------------------------------------------------------

---Contains names of all inter-cluster bridges
local cluster_bridges = {
    [PREFIX .. "inter-cluster-bridge-mk1"] = true,
    [PREFIX .. "inter-cluster-bridge-mk2"] = true,
    [PREFIX .. "inter-cluster-bridge-mk3"] = true,
}

---Configures first template selector
---@param gui_data EntityGuiData
local function configure_first_template_selector(gui_data)
    local selector = gui_data.elements.first_template_selector
    ---@cast selector LuaGuiElement
    if not selector.valid then return end
    local entity_name = gui_data.entity_name
    local entity = gui_data.entity

    -- displayed options are different if entity is an inter-cluster bridge
    local options
    if cluster_bridges[entity_name] then
        local surface_index = entity.surface_index
        options = ClusterProcessor.get_surface_clusters(surface_index)
    else
        options = TemplateCompiler.get_all_template_names()
    end
    local query = gui_data.first_template_query
    local selected = EntityProcessor.get_first_template(entity)
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures first template selector and searchbox above
---@param gui_data EntityGuiData
local function configure_first_template_selection_widget(gui_data)
    local search = gui_data.elements.first_template_search
    ---@cast search LuaGuiElement
    if not search.valid then return end
    search.text = gui_data.first_template_query or ""
    configure_first_template_selector(gui_data)
end

---Adds first template selection widget that consists of subtitle,
---searchbox and selector element
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData
---@param title LocalisedString title at the top of the widget
---@param height number|nil height of selector element. Defaults to 200
function EntityControls.create_first_template_selection_widget(parent, gui_data, title, height)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "first-template-search",
        PREFIX .. "first-template-selector",
        title,
        height
    )
    gui_data.elements.first_template_search = search
    gui_data.elements.first_template_selector = selector
    configure_first_template_selection_widget(gui_data)
end

---Handles first template search query being changed
---@param event EventData.on_gui_text_changed
function EntityControls.process_first_template_searchfield(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.template_search_query = event.element.text
    configure_first_template_selector(gui_data)
end

---Handles first template selection being changed
---@param event EventData.on_gui_selection_state_changed
function EntityControls.process_first_template_selector(event)
    local player_index = event.player_index
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    local entity = gui_data.entity
    local old_selection = EntityProcessor.get_first_template(entity)
    local element = event.element
    local new_selection = element.items[element.selected_index]

    -- if selected item is clicked again, we want to unselect it
    if old_selection == new_selection then
        EntityProcessor.set_first_template(entity, nil)
        configure_first_template_selector(gui_data)
    else
        ---@diagnostic disable-next-line
        EntityProcessor.set_first_template(entity, new_selection)
    end
end

-------------------------------------------------------------------------------
-- SECOND TEMPLATE SELECTOR
-------------------------------------------------------------------------------

---Configures second template selector
---@param gui_data EntityGuiData
local function configure_second_template_selector(gui_data)
    ---@type LuaGuiElement
    local selector = gui_data.elements.second_template_selector
    if not selector.valid then return end
    local entity = gui_data.entity
    local surface_index = entity.surface_index
    local options = ClusterProcessor.get_surface_clusters(surface_index)
    local query = gui_data.second_template_query
    local selected = EntityProcessor.get_second_template(entity)
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures second template selector and searchbox above
---@param gui_data EntityGuiData
local function configure_second_template_selection_widget(gui_data)
    ---@type LuaGuiElement
    local search = gui_data.elements.second_template_search
    if not search.valid then return end
    search.text = gui_data.second_template_query or ""
    configure_second_template_selector(gui_data)
end

---Adds second template selection widget that consists of subtitle,
---searchbox and selector element
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData
---@param title LocalisedString title at the top of the widget
---@param height number|nil height of selector element. Defaults to 200
function EntityControls.create_second_template_selection_widget(parent, gui_data, title, height)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "second-template-search",
        PREFIX .. "second-template-selector",
        title,
        height
    )
    gui_data.elements.second_template_search = search
    gui_data.elements.second_template_selector = selector
    configure_second_template_selection_widget(gui_data)
end

---Handles second template search query being changed
---@param event EventData.on_gui_text_changed
function EntityControls.process_second_template_searchfield(event)
    ---@type EntityGuiData
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.second_template_query = event.element.text
    configure_second_template_selector(gui_data)
end

---Handles second template selection being changed
---@param event EventData.on_gui_selection_state_changed
function EntityControls.process_second_template_selector(event)
    local player_index = event.player_index
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    local entity = gui_data.entity
    local old_selection = EntityProcessor.get_second_template(entity)
    local element = event.element
    local new_selection = element.items[element.selected_index]

    -- if selected item is clicked again, we want to unselect it
    if old_selection == new_selection then
        EntityProcessor.set_second_template(entity, nil)
        configure_second_template_selector(gui_data)
    else
        ---@diagnostic disable-next-line
        EntityProcessor.set_second_template(entity, new_selection)
    end
end

-------------------------------------------------------------------------------
-- ITEM SELECTION BUTTON
-------------------------------------------------------------------------------

---Contains names of entities for which item/fluid selection can be disabled
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

---Configures item selection button
---@param gui_data EntityGuiData
local function configure_choose_item_button(gui_data)
    ---@type LuaGuiElement
    local button = gui_data.elements.choose_item_button
    if not button.valid then return end

    -- setting selected item according to entity processor
    local entity = gui_data.entity
    local name, quality = EntityProcessor.get_selected_item(entity)
    button.elem_value = name and quality and {name = name, quality = quality} or nil

    -- checking if button should be enabled
    local entity_name = gui_data.entity_name
    if mode_sensitive_entities[entity_name] then
        local mode = EntityProcessor.get_mode(entity)
        button.enabled = (mode == "item")
    end
end

---Adds choose elem button with type "item-with-quality"
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData
function EntityControls.create_choose_item_button(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local button = row.add{
        type = "choose-elem-button",
        name = PREFIX .. "choose-item-button",
        elem_type = "item-with-quality",
    }
    row.add{type="label", caption={"gui-label.select-item"}}
    gui_data.elements.choose_item_button = button
    configure_choose_item_button(gui_data)
end

---Handles choose item button selection being changed
---@param event EventData.on_gui_elem_changed
function EntityControls.process_choose_item_button(event)
    local player_index = event.player_index
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    -- saving selection to entity processor
    local selection = event.element.elem_value
    local name = selection and selection.name
    local quality = selection and selection.quality
    ---@cast quality string|nil
    EntityProcessor.set_selected_item(gui_data.entity, name, quality)
end

-------------------------------------------------------------------------------
-- CHOOSE FLUID BUTTON
-------------------------------------------------------------------------------

---Configures choose fluid button
---@param gui_data EntityGuiData
local function configure_choose_fluid_button(gui_data)
    ---@type LuaGuiElement
    local button = gui_data.elements.choose_fluid_button
    if not button.valid then return end

    -- setting selected fluid according to entity processor
    local entity = gui_data.entity
    local fluid_name = EntityProcessor.get_selected_fluid(entity)
    button.elem_value = fluid_name or nil

    -- checking if button should be enabled
    local entity_name = gui_data.entity_name
    if mode_sensitive_entities[entity_name] then
        local mode = EntityProcessor.get_mode(entity)
        button.enabled = (mode == "fluid")
    end
end

---Adds choose elem button with type "fluid"
---@param parent LuaGuiElement button will be added here
---@param gui_data EntityGuiData
function EntityControls.create_choose_fluid_button(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local button = row.add{
        type = "choose-elem-button",
        name = PREFIX .. "choose-fluid-button",
        elem_type = "fluid",
    }
    row.add{type = "label", caption = {"gui-label.select-fluid"}}
    gui_data.elements.choose_fluid_button = button
    configure_choose_fluid_button(gui_data)
end

---Handles choose fluid button selection being changed
---@param event EventData.on_gui_elem_changed
function EntityControls.process_choose_fluid_button(event)
    local player_index = event.player_index
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    -- saving selected fluid to entity processor
    local fluid_name = event.element.elem_value
    ---@diagnostic disable-next-line: param-type-mismatch
    EntityProcessor.set_selected_fluid(gui_data.entity, fluid_name)
end

-------------------------------------------------------------------------------
-- MODE SELECTION RADIOBUTTONS
-------------------------------------------------------------------------------

---Configures 3 radio buttons used for mode selection of an entity
---@param gui_data EntityGuiData
local function configure_mode_selection_widget(gui_data)
    ---@type LuaGuiElement
    local item_button = gui_data.elements.item_mode_radiobutton
    ---@type LuaGuiElement
    local fluid_button = gui_data.elements.fluid_mode_radiobutton
    ---@type LuaGuiElement
    local energy_button = gui_data.elements.energy_mode_radiobutton
    if not item_button.valid or not fluid_button.valid or not energy_button.valid then return end

    local mode = EntityProcessor.get_mode(gui_data.entity)
    item_button.state = (mode == "item")
    fluid_button.state = (mode == "fluid")
    energy_button.state = (mode == "energy")
end

---Adds 3 radio buttons used for mode selection of an entity
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData
function EntityControls.create_mode_selection_widget(parent, gui_data)
    local main_flow = parent.add{type = "flow", direction = "vertical"}
    main_flow.add{type = "label", caption = {"gui-label.operation-mode"}}

    -- item mode radiobutton
    local row1 = main_flow.add{type = "flow", direction = "horizontal"}
    row1.style.vertical_align = "center"
    local button1 = row1.add{
        type = "radiobutton",
        name = PREFIX .. "item-mode-radiobutton",
        state = false
    }
    row1.add{type = "label", caption = {"gui-label.item"}}
    gui_data.elements.item_mode_radiobutton = button1

    -- fluid mode radiobutton
    local row2 = main_flow.add{type = "flow", direction = "horizontal"}
    row2.style.vertical_align = "center"
    local button2 = row2.add{
        type = "radiobutton",
        name = PREFIX .. "fluid-mode-radiobutton",
        state = false
    }
    row2.add{type = "label", caption = {"gui-label.fluid"}}
    gui_data.elements.fluid_mode_radiobutton = button2

    -- energy mode radiobutton
    local row3 = main_flow.add{type = "flow", direction = "horizontal"}
    row3.style.vertical_align = "center"
    local button3 = row3.add{
        type = "radiobutton",
        name = PREFIX .. "energy-mode-radiobutton",
        state = false
    }
    row3.add{type = "label", caption = {"gui-label.energy"}}
    gui_data.elements.energy_mode_radiobutton = button3

    configure_mode_selection_widget(gui_data)
end

---Handles any of operation mode radiobuttons being pressed
---@param player_index number unique player identifier
---@param mode "item"|"fluid"|"energy"
local function process_operation_mode_radiobutton(player_index, mode)
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    EntityProcessor.set_mode(gui_data.entity, mode)
    configure_mode_selection_widget(gui_data)
    configure_choose_fluid_button(gui_data)
    configure_choose_item_button(gui_data)
end

---Handles item mode radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityControls.process_item_mode_radiobutton(event)
    process_operation_mode_radiobutton(event.player_index, "item")
end

---Handles fluid mode radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityControls.process_fluid_mode_radiobutton(event)
    process_operation_mode_radiobutton(event.player_index, "fluid")
end

---Handles energy mode radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityControls.process_energy_mode_radiobutton(event)
    process_operation_mode_radiobutton(event.player_index, "energy")
end

-------------------------------------------------------------------------------
-- CAPABILITY OVERRIDE WIDGET
-------------------------------------------------------------------------------

---Configures capability override widget
---@param gui_data EntityGuiData table containing entity gui data
---@param checkbox_state boolean true if second row should be enabled
local function configure_capability_override_widget(gui_data, checkbox_state)
    ---@type LuaGuiElement
    local textfield = gui_data.elements.capability_override_textfield
    ---@type LuaGuiElement
    local checkbox = gui_data.elements.capability_override_checkbox
    if not textfield.valid or not checkbox.valid then return end

    checkbox.state = checkbox_state
    -- enabling/disabling second row based on checkbox state
    for _, child in ipairs(textfield.parent.children) do
        child.enabled = checkbox_state
    end

    -- setting textfield text based on override value
    local entity = gui_data.entity
    local override = EntityProcessor.get_capability_override(entity)
    local percent_value = override and override * 100
    textfield.text = CommonGui.number_to_string(percent_value, 2)
end

---Adds capability override widget, which gives player a way to underclock
---buildings. Artificially lowering flow limit, capacity limit, etc.
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData table containing entity gui data
---@param checkbox_caption LocalisedString caption to display by checkbox
---@param textbox_caption LocalisedString caption to display by textbox
function EntityControls.create_capability_override_widget(
    parent,
    gui_data,
    checkbox_caption,
    textbox_caption
)
    local flow = parent.add{type = "flow", direction = "vertical"}

    -- first row: label and checkbox that enables the second row
    local checkbox_flow = flow.add{type = "flow", direction = "horizontal"}
    checkbox_flow.style.vertical_align = "center"
    local checkbox = checkbox_flow.add{
        type = "checkbox",
        name = PREFIX .. "capability-override-checkbox",
        state = false,
    }
    checkbox_flow.add{type = "label", caption = checkbox_caption}
    gui_data.elements.capability_override_checkbox = checkbox

    -- second row: textfield and 2 labels
    local textfield_flow = flow.add{type = "flow", direction = "horizontal"}
    textfield_flow.style.vertical_align = "center"
    textfield_flow.add{
        type = "label",
        caption = textbox_caption
    }
    local textfield = textfield_flow.add{
        type = "textfield",
        name = PREFIX .. "capability-override-textfield",
        numeric = true,
        allow_decimal = true,
        allow_negative = false,
        lose_focus_on_confirm = true,
    }
    textfield_flow.add{type = "label", caption = "%"}
    textfield.style.width = 75
    gui_data.elements.capability_override_textfield = textfield

    local entity = gui_data.entity
    -- second row should be enabled if override is present in entity properties
    local checkbox_state = not not EntityProcessor.get_capability_override(entity)
    configure_capability_override_widget(gui_data, checkbox_state)
end

---Handles capability override checkbox being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityControls.process_capability_override_checkbox(event)
    local player_index = event.player_index
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    local state = event.element.state
    -- if checkbox was disabled, clearing capability override
    if not state then
        local entity = gui_data.entity
        EntityProcessor.set_capability_override(entity, nil)
    end
    configure_capability_override_widget(gui_data, state)
end

---Handles capability override textfield being changed
---@param event EventData.on_gui_text_changed
function EntityControls.process_capability_override_textfield(event)
    local player_index = event.player_index
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    local textfield = event.element
    local input_text = textfield.text
    local value = tonumber(input_text)

    -- if provided value is greater than 100%, set it to 100
    if value and value > 100 then
        value = 100
        textfield.text = "100"
    end

    -- assuming that value can not be a negative number
    local entity = gui_data.entity
    local override_value = value and value / 100
    EntityProcessor.set_capability_override(entity, override_value)
end

-------------------------------------------------------------------------------
-- OVERFLOW THRESHOLD
-------------------------------------------------------------------------------

---Adds overflow threshold widget, which is used to configure cluster overflow controller
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData table containing entity gui data
function EntityControls.create_overflow_threshold_widget(parent, gui_data)
    local flow = parent.add{type = "flow", direction = "horizontal"}
    flow.style.vertical_align = "center"
    flow.add{
        type = "label",
        caption = {"gui-label.overflow-threshold"},
    }
    local textfield = flow.add{
        type = "textfield",
        name = PREFIX .. "overflow-threshold-textfield",
        numeric = true,
        allow_decimal = true,
        allow_negative = false,
        lose_focus_on_confirm = true,
    }
    flow.add{type = "label", caption = "%"}
    textfield.style.width = 75

    -- setting threshold to match data from registry
    local entity = gui_data.entity
    local threshold = EntityProcessor.get_overflow_threshold(entity)
    local percent_value = threshold and (threshold * 100)
    textfield.text = CommonGui.number_to_string(percent_value, 2)
end

---Handles overflow threshold textfield being changed
---@param event EventData.on_gui_text_changed
function EntityControls.process_overflow_threshold_textfield(event)
    local player_index = event.player_index
    local gui_data = storage.entity_gui[player_index]
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    local textfield = event.element
    local input_text = textfield.text
    local value = tonumber(input_text)

    -- if provided value is greater than 100%, set it to 100
    if value and value > 100 then
        value = 100
        textfield.text = "100"
    end

    -- assuming that value can not be a negative number
    local entity = gui_data.entity
    local override_value = value and value / 100
    EntityProcessor.set_overflow_threshold(entity, override_value)
end

return EntityControls