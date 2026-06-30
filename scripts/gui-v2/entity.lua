-- Most entities added by this mod have custom guis.

--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = storage.entity_gui[player_index]. table keys:
-- entity LuaEntity: opened entity object
-- registry_data table: entity data from entity registry
-- elements.main_window LuaGuiElement: reference to main entity gui window
-- elements.udlink_io_label LuaGuiElement: reference to udlink io label
-- elements.udlink_io_checkbox LuaGuiElement: reference to udlink io checkbox
-- elements.template_search LuaGuiElement: reference to template searchfield
-- elements.template_selector LuaGuiElement: reference to template selector


local entity_registry = require("scripts.entity-registry")
local names = require("scripts.gui-v2.names")
local common = require("scripts.gui-v2.common")

local Helper = {}

local function update_io_checkbox(gui_data)

end

local function update_template_selector(gui_data)

end


local function update_sprite_selection_btn(gui_data)

end

-- @param player LuaPlayer: assumed to be valid
-- @param entity LuaEntity: assumed to be valid
local function entity_gui_base(player, entity)
    -- creating base window and "opening" it
    local main_frame = common.gui_base_window(
        player,
        names.prefix .. names.entity_window,
        "ENTITY GUI"
    )
    player.opened = main_frame
    storage.entity_gui[player.index] = {entity = entity}
    local gui_data = storage.entity_gui[player.index]
    gui_data.elements = {main_window = main_frame}
    gui_data.registry_data = entity_registry.get_entity_data(entity.unit_number)

    -- invisible container for other frames
    local main_flow = main_frame.add{
        type="flow",
        direction="horizontal",
    }

    -- left half of interface
    local left_frame = main_flow.add{
        type="frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    left_frame.style.right_margin = 12

    -- uplink/downlink io checkbox
    local row = left_frame.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    row.style.bottom_margin = 12
    local io_label = row.add{type="label", caption="IO CHECKBOX"}
    gui_data.elements.udlink_io_label = io_label
    local io_button = row.add{
        type="checkbox",
        name=names.prefix .. names.udlink_io_checkbox,
    }
    gui_data.elements.udlink_io_checkbox = io_button
    update_io_checkbox(gui_data)

    -- template selection widget
    local search, selector = common.selection_widget(
        left_frame,
        names.prefix .. names.entity_template_search,
        names.prefix .. names.entity_template_selector,
        "SELECT TEMPLATE"
    )


end













-- Adds a checkbox button to a given element
-- @param element: LuaGuiElement, button will be added here
-- 
-- @param entity_properties: table from entity registry, describing it
-- @param button_caption: str, text to the left of button
function Helper.udlink_io_checkbox(element, entity_properties, button_caption)
  

    

    local button_state = entity_properties.checkbox_state
    if button_state == nil then button_state = false end

    

    -- button should only be enabled on lab surfaces
    local surface_idx = entity_properties.entity.surface.index
    if not storage.v_surfaces[surface_idx] then
        button.enabled = false
        caption.enabled = false
        
        -- in case button is somehow enabled on non-lab surface
        button.state = false
        entity_properties.checkbox_state = false
    end
end

-- Adds an item selection button to a given gui element
-- @param element: LuaGuiElement, button will be added here
-- @param entity_properties: table from entity registry, describing it
-- @param button_caption: str, text to the left of button
function Helper.udlink_item_selection(element, entity_properties, button_caption)
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