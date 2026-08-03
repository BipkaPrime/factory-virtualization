---Common gui elements and operations

---Table that is used for creation of one sprite button element
---@class SpriteButtonData
---@field sprite string|nil
---@field tooltip LocalisedString|nil
---@field count number|nil
---@field quality string|nil


local PREFIX = "FV-"
local CommonGui = {}

CommonGui.ivory = {r = 1.0, g = 0.9, b = 0.78}
CommonGui.red = {r = 0.8, g = 0.2, b = 0.2}
CommonGui.yellow = {r = 0.85, g = 0.85, b = 0.4}
CommonGui.green = {r = 0.2, g = 0.8, b = 0.2}
CommonGui.grey = {r = 0.5, g = 0.5, b = 0.5}


---Rounds number to given precision and converts it to string
---@param value number|nil number that should be converted
---@param precision number|nil maximum decimal places. Defaults to 0
---@return string
function CommonGui.number_to_string(value, precision)
    if not value then return "" end
    local formatted = string.format("%." .. tostring(precision or 0) .. "f", value)
    return string.format("%g", tonumber(formatted))
end

-- used to convert large numbers to human-readable format
local number_prefixes = {
    {suffix = "", value = 1},
    {suffix = "k", value = 1e3},
    {suffix = "M", value = 1e6},
    {suffix = "G", value = 1e9},
    {suffix = "T", value = 1e12},
    {suffix = "P", value = 1e15},
    {suffix = "E", value = 1e18},
}
---Converts large number to human-readable format
---@param value number number to format
---@return string formated_value for example: "105 M", "5.1 G"
function CommonGui.format_number(value)
    local selected = number_prefixes[1]
    for _, prefix in ipairs(number_prefixes) do
        if value < prefix.value then
            break
        end
        selected = prefix
    end

    local scaled_value = value / selected.value
    local value_str
    if scaled_value < 100 then
        -- rounding to 1 decimal place
        local rounded = math.floor(scaled_value * 10 + 0.5) / 10
        if rounded % 1 == 0 then
            -- rounded is whole number
            value_str = string.format("%d", rounded)
        else
            value_str = string.format("%.1f", rounded)
        end
    else
        -- rounding to whole number
        value_str = string.format("%d", math.floor(scaled_value + 0.5))
    end

    return value_str .. " " .. selected.suffix
end

---Filters an array of strings based on a search query
---@param list string[]|nil array of strings to search through
---@param query string|nil search query
---@return string[] filtered array containing only matching strings
local function filter_strings(list, query)
    if not list or not next(list) then return {} end
    if not query or not query:match("%S") then return list end

    local cleaned_query = string.lower(query:match("^%s*(.-)%s*$"))
    local filtered = {}
    for _, text in ipairs(list) do
        if not text:match("%S") then goto continue end
        local cleaned_text = string.lower(text:match("^%s*(.-)%s*$"))
        if string.find(cleaned_text, cleaned_query, 1, true) then
            table.insert(filtered, text)
        end
        ::continue::
    end
    return filtered
end

---Creates base gui window consisting of main frame with a top bar.
---@param player LuaPlayer player for which window should be created. Assumed to be valid
---@param window_name string internal window name for element
---@param title LocalisedString text displayed on the top bar
---@return LuaGuiElement created_window
function CommonGui.create_base_window(player, window_name, title)
    local main_window = player.gui.screen.add{
        type = "frame",
        name = window_name,
        direction = "vertical",
        style = "frame"
    }
    main_window.auto_center = true
    -- window top panel
    local titlebar = main_window.add{
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
    titlebar.drag_target = main_window
    -- close button
    titlebar.add{
        type = "sprite-button",
        name = PREFIX .. "close-button",
        style = "frame_action_button",
        sprite = "utility/close",
    }
    return main_window
end

---Handles close button being pressed. Closes whatever is opened for
---a player who pressed the button.
---@param event EventData.on_gui_click
function CommonGui.process_close_button(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = nil
end

---Creates a bordered frame with set width and label
---@param parent LuaGuiElement element will be added here
---@param label LocalisedString text to display at top of element
---@return LuaGuiElement flow
function CommonGui.create_info_element_base(parent, label)
    local main_frame = parent.add{
        type = "frame",
        style = "bordered_frame"
    }
    main_frame.style.width = 424
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
    subtitle.style.font_color = CommonGui.ivory

    return main_flow
end

---Creates a bold label in given element
---@param parent LuaGuiElement element will be added here
---@param caption LocalisedString label caption
function CommonGui.create_bold_label(parent, caption)
    parent.add{
        type = "label",
        caption = caption,
        style = "bold_label"
    }
end

---Add a "selection widget" to a given element. Selection widget consists of
---"label", "textfield" for searching and "list-box" for selection.
---Added selector is empty. To add items use function below.
---@param parent LuaGuiElement widget will be added here
---@param search_name string internal name of searchbox element
---@param selector_name string internal name of selector element
---@param caption LocalisedString caption above searchfield
---@param height number|nil height of the selector. Defaults to 200
---@return LuaGuiElement searchfield, LuaGuiElement selector, LuaGuiElement label
function CommonGui.create_selection_widget(parent, search_name, selector_name, caption, height)
    local flow = parent.add{
        type = "flow",
        direction = "vertical",
    }
    local label = flow.add{type = "label", caption = caption}
    local searchfield = flow.add{
        type = "textfield",
        name = search_name,
        lose_focus_on_confirm = true,
    }
    local selector = flow.add{type = "list-box", name = selector_name}
    selector.style.width = 200
    selector.style.height = height or 200
    return searchfield, selector, label
end

---Configures options that are diplayed by the given selector according to following rules
---1. If selected_option is not nil, it will always be at the front ignoring query
---2. Other options matching with query are included
---@param selector LuaGuiElement list-box that should be configured
---@param options string[]|nil list of options to display
---@param query string|nil search query that options should matched against
---@param selected_option string|nil option that should be selected 
function CommonGui.configure_selector(selector, options, query, selected_option)
    local filtered_options = filter_strings(options, query)
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

-------------------------------------------------------------------------------
-- SPRITE BUTTONS
-------------------------------------------------------------------------------

---Assembles a table with sprite button data.
---@param key BufferKeyString
---@param count number|nil number that will be displayed
function CommonGui.assemble_sprite_button_data(key, count)
    ---@type SpriteButtonData
    local data = {}
    data.count = count
    if key:find("//", 1, true) then
        -- handling item key type: "name//quality"
        local name, quality = key:match("^(.+)//(.+)$")
        data.sprite = "item/" .. name
        ---@diagnostic disable-next-line
        data.tooltip = {"?", {"item-name." .. name}, {"entity-name." .. name}}
        data.quality = quality
    elseif key == "electric_energy" then
        -- hadling energy key type "electric_energy"
        data.sprite = "virtual-signal/signal-lightning"
        data.tooltip = {"description.electricity"}
    else
        -- handling fluid key type "name"
        data.sprite = "fluid/" .. key
        data.tooltip = {"fluid-name." .. key}
    end
    return data
end

---Adds one sprite button to provided element
---@param parent LuaGuiElement info element will be added here
---@param button_data SpriteButtonData
function CommonGui.create_sprite_button(parent, button_data)
    parent.add{
        type = "sprite-button",
        sprite = button_data.sprite,
        style = "slot_button",
        quality = button_data.quality,
        tooltip = button_data.tooltip,
        number = button_data.count,
    }
end

---Comparison function that is used to sort sprite buttons by count.
---@param a SpriteButtonData
---@param b SpriteButtonData
local function sprite_buttons_comparison(a, b)
    return (a.count or 0) > (b.count or 0)
end

---Creates a sprite button table. Buttons will be sorted by count.
---Number of buttons per row is hardcoded to 10 because it looks nice.
---@param parent LuaGuiElement table will be added here
---@param buttons SpriteButtonData[] button data
function CommonGui.create_sprite_button_table(parent, buttons)
    -- deep container element
    local container = parent.add{
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
        CommonGui.create_sprite_button(button_table, button)
    end
end

return CommonGui