-- Most entities added by this mod have custom guis.

--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = storage.entity_gui[player_index]. table keys:
-- entity LuaEntity: opened entity object
-- registry_data table: entity data from entity registry
-- template_search_query sting: search query in template selector widget
-- elements.main_window LuaGuiElement: reference to main entity gui window
-- elements.udlink_io_label LuaGuiElement: reference to udlink io label
-- elements.udlink_io_checkbox LuaGuiElement: reference to udlink io checkbox
-- elements.template_search LuaGuiElement: reference to template searchfield
-- elements.template_selector LuaGuiElement: reference to template selector
-- elements.template_selector_label LuaGuiElement: reference to template selector label
-- elements.udlink_choose_item_button LuaGuiElement: reference to udlink choose item button
-- elements.udlink_choose_fluid_button LuaGuiElement: reference to udlink choose fluid button
-- elements.udlink_choose_item_label LuaGuiElement: refenrence to udlink choose item label
-- elements.udlink_choose_fluid_label LuaGuiElement: refenrence to udlink choose fluid label
-- elements.datafield LuaGuiElement: reference to datafield on the right side of interface

local entity_registry = require("scripts.entity-registry")
local names = require("scripts.gui.names")
local common = require("scripts.gui.common")
local dashboard_backend = require("scripts.template-dashboard-backend")

local Helper = {}

-- Gets name of a given entity of ghost-entity
-- Assuming entity is valid
-- @returns string: name of given entity of ghost-entity
-- @returns bool: true if entity is ghost
local function get_entity_name(entity)
    local entity_name = entity.name
    local is_ghost = false
    if entity_name == "entity-ghost" then
        entity_name = entity.ghost_name
        is_ghost = true
    end
    return entity_name, is_ghost
end

-- key (string): entity name, value (localized string): caption
local udlink_checkbox_visible = {
    [names.prefix .. "item-uplink"] = {"gui-label.uplink-checkbox"},
    [names.prefix .. "item-downlink"] = {"gui-label.downlink-checkbox"},
    [names.prefix .. "fluid-uplink"] = {"gui-label.uplink-checkbox"},
    [names.prefix .. "fluid-downlink"] = {"gui-label.downlink-checkbox"},
    [names.prefix .. "energy-uplink"] = {"gui-label.uplink-checkbox"},
    [names.prefix .. "energy-downlink"] = {"gui-label.downlink-checkbox"},
}
-- Updates vsurface IO checkbox with its label above
-- Assuming entity is valid
local function update_udlink_io_checkbox(gui_data)
    local entity = gui_data.entity
    local entity_name, is_ghost = get_entity_name(entity)
    local label = gui_data.elements.udlink_io_label
    local checkbox = gui_data.elements.udlink_io_checkbox
    -- checking if checkbox should be visible
    if not udlink_checkbox_visible[entity_name] then
        label.visible = false
        checkbox.visible = false
        return
    end
    -- setting label and button state
    local reg_data = gui_data.registry_data
    label.caption = udlink_checkbox_visible[entity_name]
    if reg_data and reg_data.vsurface_io then
        checkbox.state = true
    end
    -- disabling checkbox if entity is a ghost or not on a vsurface
    if is_ghost or not storage.v_surfaces[entity.surface_index] then
        label.enabled = false
        checkbox.enabled = false
    end
end

-- Updates template selector based on search query and selected template
local function update_template_selector(gui_data)
    local selector = gui_data.elements.template_selector
    local query = gui_data.template_search_query
    local reg_data = gui_data.registry_data
    if not reg_data then return end
    -- if vsurface_io checked, display no template options
    local options
    if not reg_data.vsurface_io then
        options = dashboard_backend.get_all_templates()
    end
    local selected = reg_data.selected_template
    common.arrange_selector(selector, options, query, selected)
end

-- key (string): entity name, value (localized string): caption
local template_selector_visible = {
    [names.prefix .. "item-uplink"] = {"gui-label.select-template"},
    [names.prefix .. "item-downlink"] = {"gui-label.select-template"},
    [names.prefix .. "fluid-uplink"] = {"gui-label.select-template"},
    [names.prefix .. "fluid-downlink"] = {"gui-label.select-template"},
    [names.prefix .. "energy-uplink"] = {"gui-label.select-template"},
    [names.prefix .. "energy-downlink"] = {"gui-label.select-template"},
}
-- Updates template selector element along with searchfield and
-- label above. Assuming entity is valid
local function update_template_selection_widget(gui_data)
    local entity = gui_data.entity
    local entity_name, is_ghost = get_entity_name(entity)
    local label = gui_data.elements.template_selector_label
    local search = gui_data.elements.template_search
    local selector = gui_data.elements.template_selector
    -- checking if selection widget should be visible
    if not template_selector_visible[entity_name] then
        label.visible = false
        search.visible = false
        selector.visible = false
        return
    end
    -- setting searchbox text and label caption
    search.text = gui_data.template_search_query or ""
    label.caption = template_selector_visible[entity_name]
    -- checking if selection widget should be enabled
    local reg_data = gui_data.registry_data
    if is_ghost or (reg_data and reg_data.vsurface_io) then
        label.enabled = false
        search.enabled = false
    else
        label.enabled = true
        search.enabled = true
    end
    update_template_selector(gui_data)
end

-- key (string): entity name, value (localized string): caption
local choose_item_button_visible = {
    [names.prefix .. "item-uplink"] = {"gui-label.item-uplink-selection"},
    [names.prefix .. "item-downlink"] = {"gui-label.item-downlink-selection"},
}
-- Updates choose item button with its label, assuming entity is valid
local function update_udlink_choose_item_button(gui_data)
    local entity = gui_data.entity
    local entity_name, is_ghost = get_entity_name(entity)
    local label = gui_data.elements.udlink_choose_item_label
    local button = gui_data.elements.udlink_choose_item_button
    -- checking if choose item button should be visible
    if not choose_item_button_visible[entity_name] then
        label.visible = false
        button.visible = false
        return
    end
    -- checking if choose item button should be enabled
    if is_ghost then
        label.enabled = false
        button.enabled = false
        return
    end
    -- setting label caption and selected item
    label.caption = choose_item_button_visible[entity_name]
    local reg_data = gui_data.registry_data
    if reg_data and reg_data.selected_item then
        local item = reg_data.selected_item
        button.elem_value = {
            name = item.name,
            quality = item.quality,
        }
    end
end

-- key (string): entity name, value (table): label caption and elem_type
local choose_fluid_button_visible = {
    [names.prefix .. "fluid-uplink"] = {"gui-label.fluid-uplink-selection"},
    [names.prefix .. "fluid-downlink"] = {"gui-label.fluid-downlink-selection"},
}
-- Updates choose fluid button with its label, assuming entity is valid
local function update_udlink_choose_fluid_button(gui_data)
    local entity = gui_data.entity
    local entity_name, is_ghost = get_entity_name(entity)
    local label = gui_data.elements.udlink_choose_fluid_label
    local button = gui_data.elements.udlink_choose_fluid_button
    -- checking if choose fluid button should be visible
    if not choose_fluid_button_visible[entity_name] then
        label.visible = false
        button.visible = false
        return
    end
    -- checking if choose fluid button should be enabled
    if is_ghost then
        label.enabled = false
        button.enabled = false
        return
    end
    -- setting label caption and selected fluid
    label.caption = choose_fluid_button_visible[entity_name]
    local reg_data = gui_data.registry_data
    if reg_data and reg_data.selected_fluid then
        local fluid = reg_data.selected_fluid
        button.elem_value = fluid.name
    end
end

local function update_datafield(gui_data)
    -- TODO: display venv data here
end

-- Creates custom entity gui from scratch, it's assumed that 
-- custom entity gui window is not opened when this is called
-- @param player LuaPlayer: assumed to be valid
-- @param entity LuaEntity: assumed to be valid
local function create_entity_gui(player, entity)
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
    local io_label = row.add{type="label"}
    gui_data.elements.udlink_io_label = io_label
    local io_button = row.add{
        type="checkbox",
        name=names.prefix .. names.udlink_io_checkbox,
        state = false,
    }
    gui_data.elements.udlink_io_checkbox = io_button
    update_udlink_io_checkbox(gui_data)

    -- template selection widget
    local search, selector, label = common.selection_widget(
        left_frame,
        names.prefix .. names.entity_template_search,
        names.prefix .. names.entity_template_selector
    )
    gui_data.elements.template_search = search
    gui_data.elements.template_selector = selector
    gui_data.elements.template_selector_label = label
    update_template_selection_widget(gui_data)

    -- choose elem buttons
    local row = left_frame.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local item_label = row.add{type="label"}
    local fluid_label = row.add{type="label"}
    local item_button = row.add{
        type="choose-elem-button",
        name=names.prefix .. names.udlink_choose_item_button,
        elem_type = "item-with-quality",
    }
    local fluid_button = row.add{
        type="choose-elem-button",
        name=names.prefix .. names.udlink_choose_fluid_button,
        elem_type = "fluid",
    }
    gui_data.elements.udlink_choose_item_button = item_button
    gui_data.elements.udlink_choose_item_label = item_label
    gui_data.elements.udlink_choose_fluid_button = fluid_button
    gui_data.elements.udlink_choose_fluid_label = fluid_label
    update_udlink_choose_item_button(gui_data)
    update_udlink_choose_fluid_button(gui_data)

    -- right side of interface basically the same as in template dashboard
    local right_frame = main_flow.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical"
    }
    right_frame.style.width = 444
    local datafield = right_frame.add{type = "scroll-pane"}
    datafield.style.vertically_stretchable = true
    gui_data.elements.datafield = datafield
    update_datafield(gui_data)
end

-- Standart check performed before processing all user inputs into 
-- ebntity gui that can affect entity and/or entity registry data
-- Checks that gui_data exists and entity is still valid
-- @returns bool: true if everything is ok
local function check_entity_validity(gui_data)
    if not gui_data then return false end
    local entity = gui_data.entity
    if not entity or not entity.valid then return false end
    return true
end

-- Closes whatever is opened for a given player
local function close_opened_window(player_index)
    local player = game.get_player(player_index)
    if not player or not player.valid then return end
    player.opened = nil
end

-- Clears entity inventory (item, fluids and energy)
local function clear_entity_inventory(entity)
    local item_inventory = entity.get_inventory(defines.inventory.chest)
    if item_inventory then item_inventory.clear() end
    entity.clear_fluid_inside()
    if entity.energy > 0 then entity.energy = 0 end
end

-- Handles uplink/downlink IO checkbox being pressed
-- Used when on_gui_checked_state_changed event is triggered
function Helper.process_udlink_io_checkbox(event)
    local gui_data = storage.entity_gui[event.player_index]
    -- checking that entity is valid and we have its registry data
    local valid = check_entity_validity(gui_data)
    if not valid or not gui_data.registry_data then
        close_opened_window(event.player_index)
        return
    end
    -- savind checkbox state to registry
    local reg_data = gui_data.registry_data
    reg_data.vsurface_io = event.element.state
    -- whenever this changes we also want to clear selected template
    reg_data.selected_template = nil
    gui_data.template_search_query = nil
    update_template_selection_widget(gui_data)
    -- whenever this changer we also want to clear entity inventory
    clear_entity_inventory(gui_data.entity)
end

-- Handles template name search query being changed
-- Used when on_gui_text_changed event is triggered
function Helper.process_template_searchfield(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.template_search_query = event.element.text
    update_template_selector(gui_data)
end

-- Handles template selector being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_template_selector(event)
    local gui_data = storage.entity_gui[event.player_index]
    -- checking that entity is valid and we have its registry data
    local valid = check_entity_validity(gui_data)
    if not valid or not gui_data.registry_data then
        close_opened_window(event.player_index)
        return
    end
    local reg_data = gui_data.registry_data
    local element = event.element
    local old_selection = reg_data.selected_template
    local new_selection = element.items[element.selected_index]
    -- if selected item is clicked again, we want to unselect it
    if old_selection == new_selection then
        reg_data.selected_template = nil
        update_template_selector(gui_data)
    else
        reg_data.selected_template = new_selection
    end
end

-- Handles item choose elem button being changed
-- Used when on_gui_elem_changed event is triggered
function Helper.process_item_selection_button(event)
    local gui_data = storage.entity_gui[event.player_index]
    -- checking that entity is valid and we have its registry data
    local valid = check_entity_validity(gui_data)
    if not valid or not gui_data.registry_data then
        close_opened_window(event.player_index)
        return
    end
    -- we want to clear entity inventory if this is clicked
    clear_entity_inventory(gui_data.entity)
    -- saving selection to entity registry
    local reg_data = gui_data.registry_data
    local item = event.element.elem_value
    if item then
        reg_data.selected_item = {name = item.name, quality = item.quality}
    else
        reg_data.selected_item = nil
    end
end

-- Handles fluid choose elem button being changed
-- Used when on_gui_elem_changed event is triggered
function Helper.process_fluid_selection_button(event)
    local gui_data = storage.entity_gui[event.player_index]
    -- checking that entity is valid and we have its registry data
    local valid = check_entity_validity(gui_data)
    if not valid or not gui_data.registry_data then
        close_opened_window(event.player_index)
        return
    end
    -- we want to clear entity inventory if this is clicked
    clear_entity_inventory(gui_data.entity)
    -- saving selection to entity registry
    local reg_data = gui_data.registry_data
    local fluid_name = event.element.elem_value
    if fluid_name then
        reg_data.selected_fluid = {name = fluid_name}
    else
        reg_data.selected_fluid = nil
    end
end

local custom_gui_entities = {
    [names.prefix .. "item-uplink"] = true,
    [names.prefix .. "item-downlink"] = true,
    [names.prefix .. "fluid-uplink"] = true,
    [names.prefix .. "fluid-downlink"] = true,
    [names.prefix .. "energy-uplink"] = true,
    [names.prefix .. "energy-downlink"] = true,
}
-- Handles entity gui being opened. If entity from the table above is
-- opened, closes it's vanilla gui and opens a custom one.
script.on_event(defines.events.on_gui_opened, function(event)
    -- checking opened gui type
    if event.gui_type ~= defines.gui_type.entity then return end
    -- checking entity validity
    local entity = event.entity
    if not entity or not entity.valid then return end
    -- getting entity name (handling ghosts)
    local entity_name = get_entity_name(entity)
    -- checking if we need to open a custom gui
    if not custom_gui_entities[entity_name] then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    create_entity_gui(player, entity)
end)

-- Closes the custom entity gui when player.opened changes.
-- Used when on_gui_closed event is triggered
function Helper.process_entity_gui_closed(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.elements.main_window.destroy()
    storage.entity_gui[event.player_index] = nil
end

-- After player changes surface with entity gui opened
-- player.opened can be assigned nil with window still opened
-- So if window should be opened, we set player.opened to it.
function Helper.process_player_changed_surface(event)
    local gui_data = storage.entity_gui[event.player_index]
    if not gui_data then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = gui_data.elements.main_window
end

return Helper