-- This file contains definition for entity gui elements

local gui_names = require("scripts.gui.gui-names")
local gui_common = require("scripts.gui.common-gui-elements")
local utils = require("scripts.gui.utils")

local Helper = {}

-- Creates an "empty" gui window for entity and returns it
-- @param player: LuaPlayer
-- @param entity_name: str
function Helper.entity_gui_base(player, entity_name)
    local main_frame = gui_common.gui_base_window(player, gui_names.prefix .. entity_name)

    -- large frame inside the main window
    main_frame.add{
        type="frame",
        name="content_frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    return main_frame
end

-- Adds an item selection button to a given content frame
-- @param content_frame: LuaGuiElement, button will be added here
-- @param entity_properties: table from entity registry, describing it
-- @param button_caption: str, text to the left of button
function Helper.udlink_item_selection(content_frame, entity_properties, button_caption)
    -- invisible object for horizontal alignment
    local row = content_frame.add{
        type = "flow",
        direction = "horizontal",
    }
    row.style.vertical_align = "center"

    -- caption text to the left of button
    row.add{
        type="label",
        caption=button_caption,
    }

    -- button itself
    local selection_button = row.add{
        type="choose-elem-button",
        name=gui_names.prefix .. gui_names.item_selection,
        elem_type="item-with-quality",
    }

    -- if something is already selected, we need to display that
    local selected_item = entity_properties.selected_item
    if selected_item then
        -- since selected item is potentially with quality we have to do it like this
        selection_button.elem_value = selected_item
    end
end

-- Used when on_gui_elem_changed event is triggered
function Helper.process_udlink_item_selection(event)
    local element = event.element
    if not element or not element.valid then return end

    -- checking the button name to make sure it's the right button
    if element.name ~= gui_names.prefix .. gui_names.item_selection then return end

    -- checking entity validity
    local entity = storage.last_opened_entity[event.player_index]
    if not entity or not entity.valid then return end

    -- clearing inventory
    local inventory = entity.get_inventory(defines.inventory.chest)
    inventory.clear()

    -- fetching entity properties from storage
    local properties = utils.properties_from_reg(entity)

    -- storing selected item 
    local selected_item = element.elem_value
    properties.selected_item = selected_item
end

-- Adds a fluid selection button to a given content frame
-- @param content_frame: LuaGuiElement, button will be added here
-- @param entity_properties: table from entity registry, describing it
-- @param button_caption: str, text to the left of button
function Helper.udlink_fluid_selection(content_frame, entity_properties, button_caption)
    -- invisible object for horizontal alignment
    local row = content_frame.add{
        type = "flow",
        direction = "horizontal",
    }
    row.style.vertical_align = "center"

    -- caption text to the left of button
    row.add{
        type="label",
        caption=button_caption,
    }

    -- button itself
    local selection_button = row.add{
        type="choose-elem-button",
        name=gui_names.prefix .. gui_names.fluid_selection,
        elem_type="fluid",
    }

    -- if something is already selected, we need to display that
    local selected_fluid = entity_properties.selected_fluid
    if selected_fluid then
        selection_button.elem_value = selected_fluid
    end
end

-- Used when on_gui_elem_changed event is triggered
function Helper.process_udlink_fluid_selection(event)
    local element = event.element
    if not element or not element.valid then return end

    -- checking the button name to make sure it's the right button
    if element.name ~= gui_names.prefix .. gui_names.fluid_selection then return end

    -- checking entity validity
    local entity = storage.last_opened_entity[event.player_index]
    if not entity or not entity.valid then return end

    -- clearing stored fluid 
    entity.clear_fluid_inside()

    -- fetching entity properties from storage
    local properties = utils.properties_from_reg(entity)

    -- storing selected fluid
    properties.selected_fluid = element.elem_value
end

-- Adds an item checkbox button to a given content frame
-- @param content_frame: LuaGuiElement, button will be added here
-- @param entity_properties: table from entity registry, describing it
-- @param button_caption: str, text to the left of button
function Helper.udlink_io_checkbox(content_frame, entity_properties, button_caption)
    -- invisible object for horizontal alignment
    local row = content_frame.add{
        type = "flow",
        direction = "horizontal",
    }
    row.style.vertical_align = "center"
    row.style.bottom_margin = 12

    -- caption text to the left of button
    local caption = row.add{
        type="label",
        caption=button_caption,
    }

    local button_state = entity_properties.checkbox_state
    if button_state == nil then button_state = false end

    -- button itself
    local button = row.add{
        type="checkbox",
        name=gui_names.prefix .. gui_names.udlink_checkbox,
        state=button_state,
    }

    -- button should only be enabled on lab surfaces
    local surface_idx = entity_properties.entity.surface.index
    if not storage.lab_surfaces[surface_idx] then
        button.enabled = false
        caption.enabled = false
        
        -- in case button is somehow enabled on non-lab surface
        button.state = false
        entity_properties.checkbox_state = false
    end
end

-- Used when on_gui_checked_state_changed event is triggered
function Helper.process_udlink_io_checkbox(event)
    local element = event.element
    if not element or not element.valid then return end

    -- checking the button name to make sure it's the right button
    if element.name ~= gui_names.prefix .. gui_names.udlink_checkbox then return end

    -- checking entity validity
    local entity = storage.last_opened_entity[event.player_index]
    if not entity or not entity.valid then return end

    -- clearing inventory
    if entity.name == "item-uplink" or entity.name == "item-downlink" then
        local inventory = entity.get_inventory(defines.inventory.chest)
        inventory.clear()
    elseif entity.name == "fluid-uplink" or entity.name == "fluid-downlink" then
        entity.clear_fluid_inside()
    end

    -- fetching entity properties from storage
    local properties = utils.properties_from_reg(entity)

    -- storing button state
    local button_state = element.state
    properties.checkbox_state = button_state

    -- enable/disable selector widget based on button state
    local selection_flow = element.parent.parent[gui_names["prefix"] .. gui_names["entity_freq_selector_flow"]]
    local selector = selection_flow[gui_names["prefix"] .. gui_names["entity_freq_selector"]]
    -- enabling/disabling the search field
    utils.set_element_state(selection_flow, not button_state)
    -- arranging selector items based on button state
    if button_state then
        gui_common.arrange_selector(selector, {})
        -- clearing the search field
        local search_field = selection_flow[gui_names["prefix"] .. gui_names["entity_freq_searchfield"]]
        search_field.text = ""
        -- clearing the selected_frequency
        properties.selected_frequency = nil
    else
        local frequencies = utils.get_all_freq()
        -- if button is disabled, that means there is no selected frequency
        gui_common.arrange_selector(selector, frequencies)
    end
end

-- Adds frequency selection widget to entity gui
-- @param content_frame LuaGuiElement: widget will be added here
-- @param entity_properties: table from entity registry
function Helper.entity_freq_selector(content_frame, entity_properties)
    -- adding frequency selector
    local selection_flow = gui_common.selection_widget(
        content_frame,
        gui_names["prefix"] .. gui_names["entity_freq_selector_flow"],
        gui_names["prefix"] .. gui_names["entity_freq_searchfield"],
        gui_names["prefix"] .. gui_names["entity_freq_selector"],
        {"gui-label.frequency-selection"}
    )
    selection_flow.style.bottom_margin = 12

    if entity_properties.checkbox_state then
        -- disabling selector if udlink is lab surface IO
        utils.set_element_state(selection_flow, false)
    else
        -- arranging selector options if selector is enabled
        local selector = selection_flow[gui_names["prefix"] .. gui_names["entity_freq_selector"]]
        local frequencies = utils.get_all_freq()
        local selected_option = entity_properties.selected_frequency
        gui_common.arrange_selector(selector, frequencies, nil, selected_option)
    end
end

-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_entity_freq_selector(event)
    local element = event.element

    -- checking the button name to make sure it's the right button
    if element.name ~= gui_names.prefix .. gui_names.entity_freq_selector then return end

    -- checking entity validity
    local entity = storage.last_opened_entity[event.player_index]
    if not entity or not entity.valid then return end

    -- fetching entity properties from storage
    local properties = utils.properties_from_reg(entity)

    -- saving selected frequency in storage
    local selector_options = element.items
    local idx = element.selected_index
    properties.selected_frequency = selector_options[idx]
end

-- Used when on_gui_text_changed event is triggered
function Helper.process_entity_freq_search(event)
    local element = event.element

    -- checking the button name to make sure it's the right button
    if element.name ~= gui_names.prefix .. gui_names.entity_freq_searchfield then return end

    -- checking entity validity
    local entity = storage.last_opened_entity[event.player_index]
    if not entity or not entity.valid then return end

    -- fetching entity properties from storage
    local properties = utils.properties_from_reg(entity)

    -- modifing selector options based on search query
    local selector = element.parent[gui_names.prefix .. gui_names.entity_freq_selector]
    local frequencies = utils.get_all_freq()
    local query = element.text
    local selected_option = properties.selected_frequency
    gui_common.arrange_selector(selector, frequencies, query, selected_option)
end


return Helper