-- This file contains definition for common gui elements

-- TODO: make search vidget for freq selection

local params = require("scripts.gui.params")
local utils = require("scripts.gui.utils")

local Helper = {}

-- Creates an "empty" gui window and returns it
-- @param player: LuaPlayer
-- @param window_name: string
function Helper.gui_base_window(player, window_name)
    -- if window with given name is already opened, we need to destroy it first
    if player.gui.screen[params.prefix .. window_name] then
        player.gui.screen[params.prefix .. window_name].destroy()
    end

    -- main window
    local main_frame = player.gui.screen.add{
        type = "frame",
        name = params.prefix .. window_name,
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
        caption = {"gui-title."..window_name},
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
-- 2. Other frequencies matching with search_query are included
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


return Helper