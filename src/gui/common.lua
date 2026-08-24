---Common gui elements and operations

local PREFIX = "FV-"
local CommonGui = {}

CommonGui.ivory = {r = 1.0, g = 0.9, b = 0.78}
CommonGui.red = {r = 0.8, g = 0.2, b = 0.2}
CommonGui.yellow = {r = 0.85, g = 0.85, b = 0.4}
CommonGui.green = {r = 0.2, g = 0.8, b = 0.2}
CommonGui.grey = {r = 0.5, g = 0.5, b = 0.5}


---Prints given message for given player
---@param player_index integer unique player identifier
---@param message LocalisedString|nil message to print
function CommonGui.print_message(player_index, message)
    local player = game.get_player(player_index)
    if not player or not message then return end
    player.print(message)
end

-------------------------------------------------------------------------------
------------------------------ NUMBER FORMATING -------------------------------
-------------------------------------------------------------------------------

---Rounds number to given precision and converts it to string
---@param value number|nil number that should be converted
---@param precision number|nil maximum decimal places. Defaults to 0
---@return string
function CommonGui.number_to_string(value, precision)
    if not value then return "" end
    local formatted = string.format("%." .. tostring(precision or 0) .. "f", value)
    return string.format("%g", tonumber(formatted))
end

---Used to convert large numbers to human-readable format
local number_prefixes = {
    {suffix = "", value = 1},
    {suffix = " k", value = 1e3},
    {suffix = " M", value = 1e6},
    {suffix = " G", value = 1e9},
    {suffix = " T", value = 1e12},
    {suffix = " P", value = 1e15},
    {suffix = " E", value = 1e18},
}
---Converts large number to human-readable format
---@param value number number to format
---@return string formatted_value for example: "105 M", "5.1 G"
function CommonGui.large_number_to_string(value)
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

    return value_str .. selected.suffix
end

-------------------------------------------------------------------------------
------------------------------- BASE GUI WINDOW -------------------------------
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
------------------------------ INFO ELEMENT BASE ------------------------------
-------------------------------------------------------------------------------

---Creates a bordered frame with set width and label
---@param parent LuaGuiElement element will be added here
---@param label LocalisedString text to display at top of element
---@return LuaGuiElement created_element
function CommonGui.create_info_element_base(parent, label)
    local main_frame = parent.add{
        type = "frame",
        style = "bordered_frame",
        direction = "vertical"
    }
    main_frame.style.width = 424

    local subtitle = main_frame.add{
        type = "label",
        caption = label,
        style = "bold_label"
    }
    subtitle.style.font_color = CommonGui.ivory

    return main_frame
end

-------------------------------------------------------------------------------
------------------------------ SELECTION WIDGET -------------------------------
-------------------------------------------------------------------------------

---Add a "selection widget" to a given element. Selection widget consists of
---"label", "textfield" for searching and "list-box" for selection.
---Added selector is empty. To add items use function below.
---@param parent LuaGuiElement widget will be added here
---@param search_name string internal name of searchbox element
---@param selector_name string internal name of selector element
---@param caption LocalisedString caption above searchfield
---@param height number|nil height of the selector. Defaults to 200
---@return LuaGuiElement searchfield, LuaGuiElement selector
function CommonGui.add_selection_widget(parent, search_name, selector_name, caption, height)
    local flow = parent.add{
        type = "flow",
        direction = "vertical",
    }
    flow.add{type = "label", caption = caption}
    local searchfield = flow.add{
        type = "textfield",
        name = search_name,
        lose_focus_on_confirm = true,
    }
    local selector = flow.add{
        type = "list-box",
        name = selector_name,
        style = "list_box_in_shallow_frame",
    }
    selector.style.width = 200
    selector.style.height = height or 200
    return searchfield, selector
end

---Finds the first index of given value in an array
---@param array any[]
---@param val any
---@return integer|nil
function CommonGui.find_value(array, val)
    for i = 1, #array do
        if array[i] == val then
            return i
        end
    end
end

---Updates options that are diplayed by the given selector.
---@param selector LuaGuiElement list-box that should be updated
---@param options string[] list of options to display
---@param selected string|nil option that should be selected
function CommonGui.update_selector(selector, options, selected)
    selector.items = options
    -- looking for selected option in options
    local index = selected and CommonGui.find_value(options, selected) or 0
    selector.selected_index = index
end

---Scrolls given list-box to selected item
---@param selector LuaGuiElement list-box that should be scrolled
function CommonGui.scroll_to_selection(selector)
    local selected_index = selector.selected_index
    if selected_index ~= 0 then
        selector.scroll_to_item(selected_index, "top-third")
    end
end

-------------------------------------------------------------------------------
----------------------------- SPRITE BUTTON TABLE -----------------------------
-------------------------------------------------------------------------------

---Table that is used for creation of one sprite button element
---@class SpriteButtonData
---@field sprite string|nil
---@field tooltip LocalisedString|nil
---@field count number|nil
---@field quality string|nil

---Creates an element used to display an array of sprite buttons.
---Consists of scroll-pane and a table for button alignment.
---Number of buttons per row is hardcoded to 10 because it looks nice.
---@param parent LuaGuiElement table will be added here
---@return LuaGuiElement table_element created table where buttons can be added
function CommonGui.add_sprite_button_table(parent)
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
    return button_table
end

---Comparison function that is used to sort sprite buttons by count.
---@param a SpriteButtonData
---@param b SpriteButtonData
local function sprite_buttons_comparison(a, b)
    return (a.count or 0) > (b.count or 0)
end

---Updates sprite button tables using providing button data. Buttons are sorted by count.
---All LuaGuiElements passed to this function are assumed to be valid.
---@param btn_table LuaGuiElement parent element that contains all buttons (new buttons are added here)
---@param buttons LuaGuiElement[] table used to cache references to buttons. Can be modified by this function.
---@param buttons_data SpriteButtonData[] sprite button configuration data
function CommonGui.update_sprite_button_table(btn_table, buttons, buttons_data)
    table.sort(buttons_data, sprite_buttons_comparison)

    -- setting up first #button_data elements in btn_table
    local target_count = #buttons_data
    for i = 1, target_count do
        local btn_data = buttons_data[i]
        if not buttons[i] then
            -- button i does not exist, creating a new one
            buttons[i] = btn_table.add{
                type = "sprite-button",
                sprite = btn_data.sprite,
                style = "slot_button",
                quality = btn_data.quality,
                tooltip = btn_data.tooltip,
                number = btn_data.count,
            }
        else
            -- button i exists, changing its properties
            local button = buttons[i]
            button.sprite = btn_data.sprite
            button.quality = btn_data.quality
            button.tooltip = btn_data.tooltip
            button.number = btn_data.count
        end
    end

    -- clearing buttons table of any tailing elements
    for i = #buttons, target_count + 1, -1 do
        buttons[i].destroy()
        buttons[i] = nil
    end
end

return CommonGui