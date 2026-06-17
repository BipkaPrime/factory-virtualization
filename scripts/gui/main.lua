-- This file is for managing all GUIs this mod adds

-- Important things to keep in mind about the mod when working with it:

-- 1. This mod replaces default GUIs with custom ones for some entities that are added by it.
-- 2. These custom GUIs will be used to manipulate the game state, more specifically storage table.
-- 3. This means that we need to be careful in order to avoid multiplayer desyncs.
-- 4. When player clicks something in our custom GUI, we have to manipulate the game state and
--    do it when on_gui_click event is triggered because it happens for all players

-- Some docs
-- LuaGui https://lua-api.factorio.com/latest/classes/LuaGui.html
-- LuaGuiElement https://lua-api.factorio.com/latest/classes/LuaGuiElement.html
-- LuaStyle https://lua-api.factorio.com/latest/classes/LuaStyle.html


-- TODO: If entity is no longer valid, the interface will not close by itself.


-- Table mapping entity names to functions used for opening their GUIs
local utils = require("scripts.gui.utils")
local entity_gui = require("scripts.gui.entities")


local Helper = {}

function Helper.storage_init()
    -- table containing entity object for the last opened interface for each player
    -- stores [player.index] = entity
    storage.last_opened_entity = storage.last_opened_entity or {}
end


script.on_event(defines.events.on_gui_opened, function(event)
    entity_gui.process_entity_gui_opened(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
    entity_gui.process_entity_gui_closed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
    utils.process_close_button(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    utils.process_udlink_item_selection(event)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    utils.process_udlink_io_checkbox(event)
end)

return Helper