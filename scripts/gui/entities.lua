-- This file is for definitions of custom GUIs for entities

local utils = require("scripts.gui.utils")
local params = require("scripts.gui.params")


local Helper = {}


-- Opens item uplink gui for a given player
-- Entity validity must be checked before calling this function
-- @param player: LuaPlayer
-- @param entity: LuaEntityObject
function Helper.item_uplink_gui(player, entity)
    local main_frame = utils.entity_gui_base(player, entity.name)
    local properties = utils.properties_from_reg(entity)
    local content_frame = main_frame.content_frame

    utils.udlink_io_checkbox(content_frame, properties, {"gui-label.uplink-checkbox"})
    -- frequency selection button
    utils.freq_selection(content_frame, properties)
    -- item selection button
    utils.udlink_item_selection(content_frame, properties, {"gui-label.item-uplink-selection"})
    

    player.opened = main_frame
end

-- Opens item downlink gui for a given player
-- Entity validity must be checked before calling this function
-- @param player: LuaPlayer
-- @param entity: LuaEntityObject
function Helper.item_downlink_gui(player, entity)
    local main_frame = utils.entity_gui_base(player, entity.name)
    local properties = utils.properties_from_reg(entity)
    local content_frame = main_frame.content_frame

    utils.udlink_io_checkbox(content_frame, properties, {"gui-label.downlink-checkbox"})
    -- frequency selection button
    utils.freq_selection(content_frame, properties)
    -- item selection button
    utils.udlink_item_selection(content_frame, properties, {"gui-label.item-downlink-selection"})
    
    player.opened = main_frame
end


-- Table mapping entity names to functions used for opening their GUIs
local entity_mapping = {
    ["item-uplink"] = Helper.item_uplink_gui,
    ["item-downlink"] = Helper.item_downlink_gui,
}

-- Used when on_gui_opened event is triggered
function Helper.process_entity_gui_opened(event)
    -- checking that gui type is correct
    if event.gui_type ~= defines.gui_type.entity then return end

    -- checking entity validity
    local entity = event.entity
    if not entity or not entity.valid then return end

    -- checking that custom entity gui needs to be opened
    if not entity_mapping[entity.name] then return end
    
    -- saving the entity to storage
    storage.last_opened_entity[event.player_index] = entity


    local player = game.get_player(event.player_index)
    local handler = entity_mapping[entity.name]
    handler(player, entity)
end

-- Used when on_gui_closed event is triggered
function Helper.process_entity_gui_closed(event)
    if not event.element then return end

    -- removing prefix from element name to get the entity name 
    local entity_name = string.sub(event.element.name, #params.prefix + 1)

    -- cheking that it's our custom window
    if not entity_mapping[entity_name] then return end

    -- now we need to find and destroy the element
    local player = game.get_player(event.player_index)
    player.gui.screen[params.prefix .. entity_name].destroy()

    -- cleaning up storage
    storage.last_opened_entity[event.player_index] = nil
end


return Helper