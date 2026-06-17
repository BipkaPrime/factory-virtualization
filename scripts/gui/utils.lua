-- File for utility gui functions. Like creating empty entity window,
-- getting entity data from storage, defining buttons, etc.

local params = require("scripts.gui.params")

local Helper = {}


-- Returns table describing entity from entity registry
-- Entity validity must be checked before calling this function
-- @param entity: LuaEntityObject
function Helper.properties_from_reg(entity)
    local reg = storage.entity_registry[entity.name]
    local index = reg.lookup[entity.unit_number]
    return reg.array[index]
end

-- Creates an "empty" gui window for entity and returns it
-- @param player: LuaPlayer
-- @param entity_name: str
function Helper.entity_gui_base(player, entity_name)
    -- if window for given entity is already opened, we need to destroy it first
    if player.gui.screen[params.prefix .. entity_name] then
        player.gui.screen[params.prefix .. entity_name].destroy()
    end

    -- main window
    local main_frame = player.gui.screen.add{
        type = "frame", 
        name = params.prefix .. entity_name, 
        direction = "vertical",
        style = "frame"
    }
    main_frame.auto_center = true
    
    -- window top panel
    local titlebar = main_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    -- window title
    titlebar.add{
        type = "label",
        style = "frame_title",
        caption = {"item-name."..entity_name},
        ignored_by_interaction = true
    }
    titlebar.style.horizontal_spacing = 8
    titlebar.style.vertical_align = "center"

    -- drag bar
    local drag_bar = titlebar.add{
        type = "empty-widget",
        style = "draggable_space_header"
    }
    drag_bar.style.horizontally_stretchable = true
    drag_bar.style.height = 24
    drag_bar.ignored_by_interaction = true
    titlebar.drag_target = main_frame

    -- close button
    titlebar.add{
        type = "sprite-button",
        name = params.prefix .. params.close_button,
        style = "frame_action_button",
        sprite = "utility/close",
    }

    -- large frame inside the main window
    local content_frame = main_frame.add{
        type="frame",
        name="content_frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    return main_frame
end

-- Used when on_gui_click event is triggered
function Helper.process_close_button(event)
    local element = event.element
    if not element or not element.valid then return end

    -- cheking gui element name to make sure it's the right button
    if element.name == params.prefix .. params.close_button then
        local player = game.get_player(event.player_index)
        if player then
            player.opened = nil
        end
    end
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
        name=params.prefix .. params.item_selection,
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
    if element.name ~= params.prefix .. params.item_selection then return end

    -- checking entity validity
    local entity = storage.last_opened_entity[event.player_index]
    if not entity or not entity.valid then return end

    -- clearing inventory
    local inventory = entity.get_inventory(defines.inventory.chest)
    inventory.clear()

    -- fetching entity properties from storage
    local properties = Helper.properties_from_reg(entity)

    -- storing selected item 
    local selected_item = element.elem_value
    properties.selected_item = selected_item
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
        name=params.prefix .. params.udlink_checkbox,
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
    if element.name ~= params.prefix .. params.udlink_checkbox then return end

    -- checking entity validity
    local entity = storage.last_opened_entity[event.player_index]
    if not entity or not entity.valid then return end

    -- clearing inventory
    local inventory = entity.get_inventory(defines.inventory.chest)
    inventory.clear()

    -- fetching entity properties from storage
    local properties = Helper.properties_from_reg(entity)

    -- storing button state
    local button_state = element.state
    properties.checkbox_state = button_state

    -- TODO: make a function that recursively enables/disables all children of a given element
    -- deactivating frequency selection if button is unchecked
    local freq_row = element.parent.parent[params.prefix .. params.freq_selection_flow]
    for _, child in ipairs(freq_row.children) do
        child.enabled = not button_state
    end
end


-- TODO: Frequency selectrion button
-- TODO: fix frequency selection button not disabled if gui opened again with checkbox checked
function Helper.freq_selection(content_frame, entity_properties)
    local row = content_frame.add{
        type = "flow",
        direction = "horizontal",
        name = params.prefix .. params.freq_selection_flow,
    }
    row.style.vertical_align = "center"
    row.style.bottom_margin = 12

    local label = row.add{
        type="label",
        caption={"gui-label.frequency-selection"},
    }

    local freq_selector = row.add{
        type="drop-down",
        items={
            "placeholder1",
            "placeholder2",
            "placeholder3",
        },
    }

    if entity_properties.checkbox_state then
        label.enabled = false
        freq_selector.enabled = false
    end

end

return Helper