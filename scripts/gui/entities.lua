-- This file is for definitions of custom GUIs for entities and everything related to it

-- TODO: make better structure. For example GUI base is the same for all uplinks/downlinks
-- It can be wrapped in a separate function that will create and configure the main_frame

-- Prefix for gui element names to avoid conflicts with other mods
PREFIX = "FV_"

-- mapping of entity names to width and height of their windows
local window_size = {
    ["item-uplink"] = {height = 300, width = 300},
} 


local function entity_gui_base(player, entity_name)
    if player.gui.screen[PREFIX..entity_name] then
        player.gui.screen[PREFIX..entity_name].destroy()
    end

    -- main window
    local main_frame = player.gui.screen.add{
        type = "frame", 
        name = PREFIX..entity_name, 
        direction = "vertical",
        style = "frame"
    }
    main_frame.style.width = window_size[entity_name].width
    main_frame.style.height = window_size[entity_name].height
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
        name = PREFIX.."close_button",
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

local function properties_from_reg(entity)
    local reg = storage.entity_registry[entity.name]
    local index = reg.lookup[entity.unit_number]
    return reg.array[index]
end


local function freq_selection(content_frame, entity_properties)
    local row = content_frame.add{
        type = "flow",
        direction = "horizontal",
    }
    row.style.vertical_align = "center"
    row.style.bottom_margin = 12

    local label = row.add{
        type="label",
        caption="Select frequency",
    }

    local freq_selector = row.add{
        type="drop-down",
        items={
            "placeholder1",
            "placeholder2",
            "placeholder3",
        },
        name=PREFIX.."choose_freq_button"
    }
end

local function item_selection(content_frame, entity_properties)
    local row = content_frame.add{
        type = "flow",
        direction = "horizontal",
    }
    row.style.vertical_align = "center"

    local label = row.add{
        type="label",
        caption="Select an item to upload",
    }

    local selection_button = row.add{
        type="choose-elem-button",
        name=PREFIX.."choose_item_button",
        elem_type="item-with-quality",
    }
    local selected_item = entity_properties.selected_item
    if selected_item then
        -- Since selected item is item with quality we have to do it like this
        selection_button.elem_value = selected_item
    end

end

-- Opens item uplink gui for a given player
local function item_uplink_gui(player, entity)
    if not (entity and entity.valid) then return end
    main_frame = entity_gui_base(player, entity.name)

    local properties = properties_from_reg(entity)
    local content_frame = main_frame.content_frame

    freq_selection(content_frame, properties)
    item_selection(content_frame, properties)

    player.opened = main_frame
end


-- Table mapping entity names to functions used for opening their GUIs
Mapping = {
    ["item-uplink"] = item_uplink_gui,
}

return Mapping