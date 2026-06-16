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

Helper = {}

function Helper.storage_init()
    -- table containing entity object for the last opened interface for each player
    -- stores [player.index] = entity
    storage.last_opened_entity = storage.last_opened_entity or {}
end

-- used to open custom guis for mod entities
script.on_event(defines.events.on_gui_opened, function(event)
    -- if gui_type is incorrect or entity is unrelated
    if event.gui_type ~= defines.gui_type.entity or entity_gui[event.entity.name] == nil then return end

    storage.last_opened_entity[event.player_index] = event.entity

    local player = game.get_player(event.player_index)
    local handler = entity_gui[event.entity.name]
    handler(player, event.entity)
end)

-- on_gui_closes is fired when player.opened changes.
-- we need ta catch it to close our custom windows
script.on_event(defines.events.on_gui_closed, function(event)
    if not event.element then return end
    -- removing prefix from element name to get the entity name 
    local entity_name = string.sub(event.element.name, #PREFIX + 1)
    -- cheking that it's our custom window
    if entity_gui[entity_name] == nil then return end
    -- now we need to find and destroy the element
    local player = game.get_player(event.player_index)
    player.gui.screen[PREFIX..entity_name].destroy()
    storage.last_opened_entity[event.player_index] = nil
end)

-- currently is used for close button in custom interfaces
script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then return end

    -- close button
    if element.name == PREFIX.."close_button" then
        local player = game.get_player(event.player_index)
        if player then
            player.opened = nil
        end
    end
end)

-- currently used for item selection button
script.on_event(defines.events.on_gui_elem_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end

    -- item selection button
    if element.name == PREFIX.."choose_item_button" then
        local entity = storage.last_opened_entity[event.player_index]
        if entity and entity.valid then
            local selected_item = element.elem_value
            
            -- finding entity in registry and changing data
            local reg = storage.entity_registry[entity.name]
            local index = reg.lookup[entity.unit_number]
            local properties = reg.array[index]
            properties.selected_item = selected_item

            -- TODO
            game.print("Player changed item on entity at position: " .. tostring(entity.position))
        end
    end
end)

return Helper