-- Common gui elements and operations

local PREFIX = "FV-"
local GuiCommon = {}

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
---Converts given number to human-readable format
---@param value number number to format
---@return string formated_value for example: "105 M", "5.1 G"
function GuiCommon.format_number(value)
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
---@param title string|LocalisedString text displayed on the top bar
---@return LuaGuiElement|nil created_window returns nil if nothing was created
function GuiCommon.create_base_window(player, window_name, title)
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
function GuiCommon.process_close_button(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = nil
end

---Creates a bordered frame with set width and label
---@param parent LuaGuiElement element will be added here
---@param label string|LocalisedString text to display at top of element
---@return LuaGuiElement flow
function GuiCommon.create_info_element_base(parent, label)
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

---Adds a bold label to a given element
---@param parent LuaGuiElement element will be added here
---@param caption string|LocalisedString label caption
function GuiCommon.add_bold_label(parent, caption)
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
---@param caption string|LocalisedString caption above searchfield
---@return LuaGuiElement searchfield, LuaGuiElement selector, LuaGuiElement label
function GuiCommon.create_selection_widget(parent, search_name, selector_name, caption)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.style.bottom_margin = 12
    local label = flow.add{type = "label", caption = caption}
    local searchfield = flow.add{type = "textfield", name = search_name}
    local selector = flow.add{type = "list-box", name = selector_name}
    selector.style.width = 200
    selector.style.height = 200
    return searchfield, selector, label
end

---Configures options that are diplayed by the given selector according to following rules
---1. If selected_option is not nil, it will always be at the front ignoring query
---2. Other options matching with query are included
---@param selector LuaGuiElement list-box that should be configured
---@param options string[]|nil list of options to display
---@param query string|nil search query that options should matched against
---@param selected_option string|nil option that should be selected 
function GuiCommon.arrange_selector(selector, options, query, selected_option)
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

-- used for comparison function below
local type_rank = {item = 1, fluid = 2}
local quality_rank = {
    normal = 1,
    uncommon = 2,
    rare = 3,
    epic = 4,
    legendary = 5,
}
---Comparison function that is used to sort sprite buttons by count.
---Table that is being sorted must contain following keys:
---count: float, name: prototype name, type: "item"/"fluid", quality (for items): "rare"/"epic", etc.
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

---Creates a sptire button table. Buttons are sorted by count with the function above.
---Number of buttons per row is hardcoded to 10 because it looks nice.
---@param parent LuaGuiElement table will be added here
---@param buttons table[] buttons that will be added.
---Each table describing button must contain following keys:
---type "item"/"fluid"; name str: prototype name; count number: displayed number;
---quality (if type == "item") string: "uncommon", "epic", etc.
function GuiCommon.create_sprite_button_table(parent, buttons)
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

return GuiCommon