-- This file is for managing all GUIs this mod adds

-- Important things to keep in mind about the mod when working with it:

-- 1. This mod replaces default GUIs with custom ones for some entities that are added by it.
-- 2. These custom GUIs will be used to manipulate the game state, more specifically storage table.
-- 3. This means that we need to be careful in order to avoid multiplayer desyncs.
-- 4. When player opens the GUI, we should not manipulate the game state.
-- 5. When player clicks something in our custom GUI, we have to manipulate the game state and
--    do it when on_gui_click event is triggered because it happens for all players
-- 6. If entity is no longer valid, the interface will not close by itself.


-- Some docs
-- LuaGui https://lua-api.factorio.com/latest/classes/LuaGui.html
-- LuaGuiElement https://lua-api.factorio.com/latest/classes/LuaGuiElement.html
-- LuaStyle https://lua-api.factorio.com/latest/classes/LuaStyle.html

-- Table mapping entity names to functions used for opening their GUIs
entity_gui = require("scripts.gui.entities")


script.on_event(defines.events.on_gui_opened, function(event)
    -- if gui_type is incorrect or entity is unrelated
    if event.gui_type ~= defines.gui_type.entity or entity_gui[event.entity.name] == nil then return end

    local player = game.get_player(event.player_index)
    local handler = entity_gui[event.entity.name]
    handler(player, event.entity)
end)