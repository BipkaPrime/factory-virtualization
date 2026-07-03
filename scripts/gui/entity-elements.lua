-- This file contains definitions for entity gui elements.

-- There are 3 functions that should be defined for each element.
-- First function to add element to gui, second function to configure it
-- according to "gui_data" (that contains reference to entity and its registry data),
-- third function is to handle player interfaction with the element.

-- All create element and update element functions assume that entity is valid.
-- Entity validity must be checked before calling them (in handlers and before gui creation)

--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = storage.entity_gui[player_index]. table keys:
-- entity LuaEntity: opened entity object
-- registry_data table: entity data from entity registry
-- template_search_query sting: search query in template selector widget
-- elements.main_window LuaGuiElement: reference to main entity gui window
-- elements.left_frame LuaGuiElement: reference to main container on the left side
-- elements.datafield LuaGuiElement: reference to datafield on the right side of interface
-- elements.udlink_io_label LuaGuiElement: reference to udlink io label
-- elements.udlink_io_checkbox LuaGuiElement: reference to udlink io checkbox
-- elements.template_search LuaGuiElement: reference to template searchfield
-- elements.template_selector LuaGuiElement: reference to template selector
-- elements.template_selector_label LuaGuiElement: reference to template selector label
-- elements.udlink_choose_item_button LuaGuiElement: reference to udlink choose item button
-- elements.udlink_choose_item_label LuaGuiElement: refenrence to udlink choose item label
-- elements.udlink_choose_fluid_button LuaGuiElement: reference to udlink choose fluid button
-- elements.udlink_choose_fluid_label LuaGuiElement: refenrence to udlink choose fluid label


local names = require("scripts.gui.names")
local dashboard_backend = require("scripts.template-dashboard-backend")
local common = require("scripts.gui.common")
local misc = require("scripts.misc")


local Helper = {}

-- Closes whatever is opened for a given player
local function close_opened_window(player_index)
    local player = game.get_player(player_index)
    if not player or not player.valid then return end
    player.opened = nil
end

-- Standart check performed before handling any user inputs into
-- entity gui that can affect entity and/or entity registry data
-- Checks that gui_data exists, entity is valid and we have its registry data
-- If any check fails, the window is closed (player.opened is set to nil)
-- @returns bool: true if everything is ok
local function assert_entity_validity(player_index, gui_data)
    -- checking that gui_data exists
    if not gui_data then
        close_opened_window(player_index)
        return false
    end
    -- checking that entity is valid
    local entity = gui_data.entity
    if not entity or not entity.valid then
        close_opened_window(player_index)
        return false
    end
    -- checking entity registry data
    if not gui_data.registry_data then
        close_opened_window(player_index)
        return false
    end
    return true
end

-- Configures only template selector. Used for handling search.
local function configure_template_selector(gui_data)
    local selector = gui_data.elements.template_selector
    local query = gui_data.template_search_query
    local reg_data = gui_data.registry_data
    -- if registry data is unavailable, don't show options
    if not reg_data then return end
    -- if vsurface_io checked, display no template options
    local options
    if not reg_data.vsurface_io then
        options = dashboard_backend.get_all_templates()
    end
    local selected = reg_data.selected_template
    common.arrange_selector(selector, options, query, selected)
end

-- Configures template selector as well as searchbox and label above 
local function configure_template_selection_widget(gui_data)
    local entity = gui_data.entity
    local _, is_ghost = misc.get_entity_name(entity)
    local label = gui_data.elements.template_selector_label
    local search = gui_data.elements.template_search
    -- setting searchbox text and label caption
    search.text = gui_data.template_search_query or ""
    label.caption = {"gui-label.select-template"}
    -- checking if selection widget should be enabled
    local reg_data = gui_data.registry_data
    if is_ghost or (reg_data and reg_data.vsurface_io) then
        label.enabled = false
        search.enabled = false
    else
        label.enabled = true
        search.enabled = true
    end
    configure_template_selector(gui_data)
end

-- Adds and configures template selection widget that consists of
-- title, searchbox and selector element
function Helper.add_template_selection_widget(parent, gui_data)
    local search, selector, label = common.selection_widget(
        parent,
        names.prefix .. names.entity_template_search,
        names.prefix .. names.entity_template_selector
    )
    gui_data.elements.template_search = search
    gui_data.elements.template_selector = selector
    gui_data.elements.template_selector_label = label
    configure_template_selection_widget(gui_data)
end

-- Handles template name search query being changed
-- Used when on_gui_text_changed event is triggered
function Helper.process_template_searchfield(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.template_search_query = event.element.text
    configure_template_selector(gui_data)
end

-- Handles template selector being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_template_selector(event)
    local gui_data = storage.entity_gui[event.player_index]
    -- making sure entity is valid and we have registry data
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    local reg_data = gui_data.registry_data
    local element = event.element
    local old_selection = reg_data.selected_template
    local new_selection = element.items[element.selected_index]
    -- if selected item is clicked again, we want to unselect it
    if old_selection == new_selection then
        reg_data.selected_template = nil
        configure_template_selector(gui_data)
    else
        reg_data.selected_template = new_selection
    end
end

-- key (string): entity name, value (localized string): caption
local udlink_io_caption = {
    [names.prefix .. "item-uplink"] = {"gui-label.uplink-checkbox"},
    [names.prefix .. "item-downlink"] = {"gui-label.downlink-checkbox"},
    [names.prefix .. "fluid-uplink"] = {"gui-label.uplink-checkbox"},
    [names.prefix .. "fluid-downlink"] = {"gui-label.downlink-checkbox"},
    [names.prefix .. "energy-uplink"] = {"gui-label.uplink-checkbox"},
    [names.prefix .. "energy-downlink"] = {"gui-label.downlink-checkbox"},
}
-- Configures "Vsurface IO" checkbox according to gui_data
local function configure_udlink_io_checkbox(gui_data)
    local entity = gui_data.entity
    local entity_name, is_ghost = misc.get_entity_name(entity)
    local label = gui_data.elements.udlink_io_label
    local checkbox = gui_data.elements.udlink_io_checkbox
    -- setting label and button state according to entity data
    local reg_data = gui_data.registry_data
    label.caption = udlink_io_caption[entity_name]
    if reg_data and reg_data.vsurface_io then
        checkbox.state = true
    end
    -- disabling checkbox if entity is a ghost or not on a vsurface
    if is_ghost or not storage.v_surfaces[entity.surface_index] then
        label.enabled = false
        checkbox.enabled = false
    end
end

-- Adds and configures "Vsurface IO" checkbox for uplink/downlink
function Helper.add_udlink_io_checkbox(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    row.style.bottom_margin = 12
    local io_label = row.add{type="label"}
    gui_data.elements.udlink_io_label = io_label
    local io_button = row.add{
        type="checkbox",
        name=names.prefix .. names.udlink_io_checkbox,
        state = false,
    }
    gui_data.elements.udlink_io_checkbox = io_button
    configure_udlink_io_checkbox(gui_data)
end

-- Clears entity inventory (item, fluids and energy) of a given
-- entity if it's located on a vsurface
local function clear_inventory_vsurface(entity)
    local surface_index = entity.surface_index
    if not storage.v_surfaces[surface_index] then return end
    local item_inventory = entity.get_inventory(defines.inventory.chest)
    if item_inventory then item_inventory.clear() end
    entity.clear_fluid_inside()
    if entity.energy > 0 then entity.energy = 0 end
end

-- Handles uplink/downlink IO checkbox being pressed
-- Used when on_gui_checked_state_changed event is triggered
function Helper.process_udlink_io_checkbox(event)
    local gui_data = storage.entity_gui[event.player_index]
    -- making sure entity is valid and we have registry data
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    -- savind checkbox state to registry
    local reg_data = gui_data.registry_data
    reg_data.vsurface_io = event.element.state
    -- whenever this changes we also want to clear selected template
    reg_data.selected_template = nil
    gui_data.template_search_query = nil
    configure_template_selection_widget(gui_data)
    -- whenever this changer we also want to clear entity inventory
    clear_inventory_vsurface(gui_data.entity)
end

-- key (string): entity name, value (localized string): caption
local choose_item_button_label = {
    [names.prefix .. "item-uplink"] = {"gui-label.item-uplink-selection"},
    [names.prefix .. "item-downlink"] = {"gui-label.item-downlink-selection"},
}
-- Updates choose item button with its label
local function configure_udlink_choose_item_button(gui_data)
    local entity = gui_data.entity
    local entity_name, is_ghost = misc.get_entity_name(entity)
    local label = gui_data.elements.udlink_choose_item_label
    local button = gui_data.elements.udlink_choose_item_button
    -- setting label caption
    label.caption = choose_item_button_label[entity_name]
    -- checking if choose item button should be enabled
    if is_ghost then
        label.enabled = false
        button.enabled = false
        return
    end
    -- setting chosen element according to registry data
    local reg_data = gui_data.registry_data
    if reg_data and reg_data.selected_item then
        local item = reg_data.selected_item
        button.elem_value = {
            name = item.name,
            quality = item.quality,
        }
    end
end

-- Adds choose elem button with type "item-with-quality" to udlinks
function Helper.add_udlink_choose_item_button(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local label = row.add{type="label"}
    local button = row.add{
        type="choose-elem-button",
        name=names.prefix .. names.udlink_choose_item_button,
        elem_type = "item-with-quality",
    }
    gui_data.elements.udlink_choose_item_button = button
    gui_data.elements.udlink_choose_item_label = label
    configure_udlink_choose_item_button(gui_data)
end

-- Handles udlink choose item button being changed 
-- Used when on_gui_elem_changed event is triggered
function Helper.process_udlink_choose_item_button(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    -- we want to clear entity inventory if this is clicked
    clear_inventory_vsurface(gui_data.entity)
    -- saving selection to entity registry
    local reg_data = gui_data.registry_data
    local item = event.element.elem_value
    if not item then reg_data.selected_item = nil return end
    reg_data.selected_item = {name = item.name, quality = item.quality}
end

-- key (string): entity name, value (table): label caption and elem_type
local choose_fluid_button_label = {
    [names.prefix .. "fluid-uplink"] = {"gui-label.fluid-uplink-selection"},
    [names.prefix .. "fluid-downlink"] = {"gui-label.fluid-downlink-selection"},
}
-- Updates choose fluid button with its label, assuming entity is valid
local function update_udlink_choose_fluid_button(gui_data)
    local entity = gui_data.entity
    local entity_name, is_ghost = misc.get_entity_name(entity)
    local label = gui_data.elements.udlink_choose_fluid_label
    local button = gui_data.elements.udlink_choose_fluid_button
    -- setting label caption
    label.caption = choose_fluid_button_label[entity_name]
    -- checking if choose fluid button should be enabled
    if is_ghost then
        label.enabled = false
        button.enabled = false
        return
    end
    -- setting selected fluid according to registry
    local reg_data = gui_data.registry_data
    if reg_data and reg_data.selected_fluid then
        local fluid = reg_data.selected_fluid
        button.elem_value = fluid.name
    end
end

-- Adds choose elem button with type "fluid" to udlinks
function Helper.add_udlink_choose_fluid_button(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local label = row.add{type="label"}
    local button = row.add{
        type="choose-elem-button",
        name=names.prefix .. names.udlink_choose_fluid_button,
        elem_type = "fluid",
    }
    gui_data.elements.udlink_choose_fluid_button = button
    gui_data.elements.udlink_choose_fluid_label = label
    update_udlink_choose_fluid_button(gui_data)
end

-- Handles udlink choose fluid button being changed
-- Used when on_gui_elem_changed event is triggered
function Helper.process_udlink_choose_fluid_button(event)
    local gui_data = storage.entity_gui[event.player_index]
    -- making sure entity is valid and we have registry data
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    -- we want to clear entity inventory if this is clicked
    clear_inventory_vsurface(gui_data.entity)
    -- saving selection to entity registry
    local reg_data = gui_data.registry_data
    local fluid_name = event.element.elem_value
    if not fluid_name then reg_data.selected_fluid = nil return end
    reg_data.selected_fluid = {name = fluid_name}
end

return Helper