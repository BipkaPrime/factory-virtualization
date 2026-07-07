-- This file contains definition for common gui elements

local names = require("scripts.gui.names")

local Helper = {}

-- Creates base gui window consisting of main frame with a top bar.
-- @param player: LuaPlayer
-- @param window_name: string
-- @param title: localized string
function Helper.gui_base_window(player, window_name, title)
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
    titlebar.add{
        type = "label",
        style = "frame_title",
        caption = title,
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
        name = names.prefix .. names.close_button,
        style = "frame_action_button",
        sprite = "utility/close",
    }
    return main_frame
end

-- Handles window close button being pressed. Element is assumed to be valid.
-- Also assuming the element is in fact the "close button".
-- Used when on_gui_click event is triggered
function Helper.process_close_button(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    player.opened = nil
end

-- Base gui element for all info elements
-- Basically a bordered frame with set width and label
-- @returns LuaGuiElement: reference to main flow 
function Helper.info_element_base(parent, label)
    local main_frame = parent.add{
        type = "frame",
        style = "bordered_frame"
    }
    main_frame.style.minimal_width = 424
    local main_flow = main_frame.add{
        type = "flow",
        direction = "vertical",
    }
    -- Label at the top of this section
    local subtitle = main_flow.add{
        type = "label",
        caption = label,
        style = "bold_label",
    }
    subtitle.style.font_color = {255, 230, 199}

    return main_flow
end

-- Adds bold label to a given element
function Helper.add_bold_label(parent, caption)
    parent.add{
        type = "label",
        caption = caption,
        style = "bold_label"
    }
end

-- Add a selectrion widget to a given gui element, consisting of subtitle "label",
-- "textfield" for searching and "list-box" for selection.
-- Added widget is empty. To add items use function below
-- @param element LuaGuiElement: widget will be added here
-- @param searchfield_name string: name of searchbox element
-- @param selector_name string: name of selector element
-- @param subtitle localized string: subtitle above the widget
function Helper.selection_widget(element, searchfield_name, selector_name, subtitle)
    local flow = element.add{type = "flow", direction = "vertical"}
    flow.style.bottom_margin = 12
    local label = flow.add{type = "label", caption = subtitle}
    local searchfield = flow.add{type = "textfield", name = searchfield_name}
    local selector = flow.add{type = "list-box", name = selector_name}
    selector.style.width = 200
    selector.style.height = 200
    return searchfield, selector, label
end

-- Filters an array of strings based on a search query
-- @param list table: array of strings to search through
-- @param query string: search query
-- @return table: filtered array containing only matching strings
local function filter_strings(list, query)
    -- if list in nil or empty, return empty list
    if not list or not next(list) then return {} end
    -- if query is nil, return full list
    if not query or query == "" then return list end
    -- trimming the query
    local cleaned_query = string.lower(query:match("^%s*(.-)%s*$"))
    if cleaned_query == "" then return list end

    local filtered = {}
    for _, text in ipairs(list) do
        local trimmed_text = text:match("^%s*(.-)%s*$")
        if trimmed_text then
            local cleaned_text = string.lower(trimmed_text)
            if string.find(cleaned_text, cleaned_query, 1, true) then
                table.insert(filtered, text)
            end
        end
    end
    return filtered
end

-- Configures options that are diplayed by the given selector according to following rules
-- 1. If selected_option is not nil, it will always be at the front ignoring search_query
-- 2. Other options matching with search_query are included
function Helper.arrange_selector(selector, options, search_query, selected_option)
    local filtered_options = filter_strings(options, search_query)
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
    else
        selector.selected_index = 0
    end
end

-- Comparison function that is used to sort sprite buttons by count.
-- Table being sorted must contain following keys:
-- count: float, name: prototype name, type: "item"/"fluid", quality (for items): "rare"/"epic", etc.
local type_rank = {item = 1, fluid = 2}
local quality_rank = {
    normal = 1,
    uncommon = 2,
    rare = 3,
    epic = 4,
    legendary = 5,
}
local function sprite_buttons_comparison(a, b)
    -- priority 1: higher count first
    if a.count ~= b.count then
        return a.count > b.count
    end

    -- priority 2: items first
    if a.type ~= b.type then
        return type_rank[a.type] < type_rank[b.type]
    end

    -- priority 3: name (alphabetical)
    if a.name ~= b.name then
        return a.name < b.name
    end

    -- priority 4: higher quality first
    return (quality_rank[a.quality] or 0) > (quality_rank[b.quality] or 0)
end

-- Creates a sptire button table. Buttons are sorted by count with above function.
-- Number of buttons per row is hardcoded to 10 because it's golden standart of factorio.
-- @param element LuaGuiElement: table will be added here
-- @param buttons array of tables: each table must contain following keys:
-- type: "item"/"fluid", name str: prototype name, count double: displayed number,
-- quality (if type == "item") string: "uncommon", "epic", etc.
function Helper.sprite_button_panel(element, buttons)
    -- deep container element
    local container = element.add{
        type = "scroll-pane",
        style = "deep_slots_scroll_pane",
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "never",
    }
    container.style.width = 400
    -- invisible element for button alignment
    local button_table = container.add{
        type = "table",
        column_count = 10,
        style = "slot_table"
    }
    -- sorting the buttons by count
    table.sort(buttons, sprite_buttons_comparison)
    -- adding the buttons
    for _, button in ipairs(buttons) do
        local slot_button = button_table.add{
            type = "sprite-button",
            sprite = button.type .. "/" .. button.name,
            number = button.count,
            style = "slot_button",
            quality = button.quality,
        }
        slot_button.elem_tooltip = {type = button.type, name = button.name}
    end
end

return Helper