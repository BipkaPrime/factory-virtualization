-- This file contains definition for common gui elements

local gui_names = require("scripts.gui.gui-names")
local utils = require("scripts.gui.utils")

local Helper = {}

-- Creates an "empty" gui window and returns it
-- @param player: LuaPlayer
-- @param window_name: string
function Helper.gui_base_window(player, window_name)
    -- if window with given name is already opened, we need to destroy it first
    if player.gui.screen[window_name] then
        player.gui.screen[window_name].destroy()
    end

    -- main window
    local main_frame = player.gui.screen.add{
        type = "frame",
        name = window_name,
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
    local title = string.sub(window_name, #gui_names.prefix + 1)
    titlebar.add{
        type = "label",
        style = "frame_title",
        caption = {"gui-title." .. title},
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
        name = gui_names.prefix .. gui_names.close_button,
        style = "frame_action_button",
        sprite = "utility/close",
    }

    return main_frame
end

-- Used when on_gui_click event is triggered
function Helper.process_close_button(event)
    local element = event.element
    if not element or not element.valid then return end

    -- cheking gui element name to make sure it's the right button
    if element.name == gui_names.prefix .. gui_names.close_button then
        local player = game.get_player(event.player_index)
        if player then
            player.opened = nil
        end
    end
end

-- Add a selectrion widget to a given content_frame, consisting of subtitle "label",
-- "textfield" for user to type in and "list-box" for selection
-- IMPORTANT: created with no elements in selection. To add them use the next function.
-- @param content_frame LuaGuiElement: widget will be here
-- @param flow_name string: name of element containing all other elems of the widget
-- @param searchfield_name string: name of searchbox element
-- @param selector_name string: name of selector element
-- @param subtitle localized string: subtitle above the widget
function Helper.selection_widget(content_frame, flow_name, searchfield_name, selector_name, subtitle)
    local row = content_frame.add{
        type = "flow",
        direction = "vertical",
        name = flow_name,
    }

    row.add{
        type = "label",
        caption = subtitle,
    }

    row.add{
        type = "textfield",
        name = searchfield_name,
    }

    local selector = row.add{
        type = "list-box",
        name = selector_name,
    }
    selector.style.width = 200
    selector.style.height = 200

    return row
end

-- Configures options that are diplayed by the given selector according to following rules
-- 1. If selected_option is not nil, it will always be at the front ignoring search_query
-- 2. Other options matching with search_query are included
function Helper.arrange_selector(selector, options, search_query, selected_option)
    local filtered_options = utils.filter_strings(options, search_query)

    local displayed_items = {}
    -- adding selected option to the front
    if selected_option then table.insert(displayed_items, selected_option) end

    -- adding all other items mathing the query
    for _, item in ipairs(filtered_options) do
        if selected_option ~= item then
            table.insert(displayed_items, item)
        end
    end

    selector.items = displayed_items
    if selected_option then
        selector.selected_index = 1
    end
end


-- Creates empty grid panel for displaying sprite buttons
-- @param gui_element LuaGuiElement: panel will be added here
-- @param label localized string: text to be displayed above the panel
-- @return LuaGuiElement: element where you can actually add the buttons
function Helper.empty_grid_panel(gui_element, label)
    local main_frame = gui_element.add{
        type = "frame",
        style = "bordered_frame"
    }

    local main_flow = main_frame.add{
        type = "flow",
        direction = "vertical",
    }

    -- Label above the table
    local label_element = main_flow.add{
        type = "label",
        caption = label,
        style = "bold_label",
    }
    label_element.style.font_color = {255, 230, 199}

    -- deep container element
    local container = main_flow.add{
        type = "scroll-pane",
        style = "deep_slots_scroll_pane",
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "never",
    }

    local internal_table = container.add{
        type = "table",
        column_count = 10,
        style = "slot_table"
    }

    return internal_table
end

-- Inserts an item sprite into the given grid_panel
-- @param target_grid LuaGuiElement: "table"
-- @param name string: for instance, "iron-plate"
-- @param count number: displayed number of items
-- @param quality string: "uncommon", "rare", "epic", "legendary", etc.
function Helper.insert_item_icon(target_grid, name, count, quality)
    local slot_button = target_grid.add{
        type = "sprite-button",
        sprite = "item/" .. name,
        number = count,
        style = "slot_button",
        quality = quality
    }

    slot_button.elem_tooltip = {type = "item", name = name}
end





return Helper