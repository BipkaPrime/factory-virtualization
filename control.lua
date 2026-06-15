-- Import external modules from the scripts directory
local entity_registry = require("scripts.entity-registry")
local lab_surface_manager = require("scripts.lab-surface-manager")
local interface_manager = require("scripts.interface-manager")
require("scripts.gui.main")

-------------------------------------------------------------------------------
-- 1. INITIALIZATION & LIFECYCLE
-------------------------------------------------------------------------------

script.on_init(function()
    lab_surface_manager.storage_init()


    -- Initial scan of the world surfaces
    entity_registry.scan_and_populate_all()
end)

script.on_configuration_changed(function(data)
    -- Initial scan of the world surfaces
    entity_registry.scan_and_populate_all()
end)

-------------------------------------------------------------------------------
-- 2. Event-based handlers
-------------------------------------------------------------------------------

script.on_event(defines.events.on_built_entity, function(event)
    -- If it's a core tracked machine, register it
    entity_registry.process_built_entity(event)
end)


-------------------------------------------------------------------------------
-- 3. Tick-based handlers
-------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(event)
    interface_manager.process_interfaces(event)
end)

script.on_nth_tick(60, function(event)
    -- lab charting
    lab_surface_manager.process_designing_labs(event)
    lab_surface_manager.charting(event)
end)

-------------------------------------------------------------------------------
-- 4. DEBUG CONSOLE COMMANDS
-------------------------------------------------------------------------------

-- `/v-create [size]` -> Generates a new bounded lab surface and opens view
commands.add_command("v-create", "Creates a pristine virtual sandbox lab. Usage: /v-create [size]", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    
    -- Parse text argument from chat to get custom size, fallback to 64 if empty
    local size = event.parameter and tonumber(event.parameter) or 64
    
    local lab_surface = lab_surface_manager.create_new_lab(nil, size)
    lab_surface_manager.enter_lab_view(player, lab_surface.index)
    
    player.print("[Lab Surface Manager] Lab Created with size " .. size .. "x" .. size .. ". Designing state active.")
end)