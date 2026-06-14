-- Import external modules from the scripts directory
local entity_registry = require("scripts.entity-registry")
local compiler_manager = require("scripts.compiler-manager")
local interface_manager = require("scripts.interface-manager")

-------------------------------------------------------------------------------
-- 1. INITIALIZATION & LIFECYCLE
-------------------------------------------------------------------------------

script.on_init(function()
    -- Initial scan of the world surfaces
    entity_registry.scan_and_populate_all()
end)

script.on_configuration_changed(function(data)
    -- Initial scan of the world surfaces
    entity_registry.scan_and_populate_all()
end)

-------------------------------------------------------------------------------
-- 2. Event handlers
-------------------------------------------------------------------------------

script.on_event(defines.events.on_built_entity, function(event)
    -- If built inside a lab, revive ghost
    compiler_manager.process_built_entity(event)

    -- If it's a core tracked machine, register it
    entity_registry.process_built_entity(event)
end)

-- handlers for these events are not done yet
-- they are here so that I don't forget about them
local build_events = {
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
    defines.events.on_space_platform_built_entity
}

local removal_events = {
    defines.events.on_entity_died,
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.script_raised_destroy
}


-------------------------------------------------------------------------------
-- 3. TICK PROCESSING LOOP
-------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(event)
    interface_manager.process_interfaces(event)
    compiler_manager.chart_all_labs(event)
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
    
    local lab_surface = compiler_manager.create_lab_surface(nil, size)
    compiler_manager.enter_lab_view(player, lab_surface.index)
    
    player.print("[Compiler Master] Lab Created with size " .. size .. "x" .. size .. ". Designing state active.")
end)

-- `/v-test-lock` -> Simulates starting the benchmark (Natively locks building & modifications)
commands.add_command("v-test-lock", "Switches the current lab surface to compilation status", function(event)
    local player = game.get_player(event.player_index)
    if player and compiler_manager.is_lab_surface(player.surface.index) then
        compiler_manager.set_lab_status(player.surface.index, "compiling")
        player.print("[Compiler Master] STATUS LOCKED TO COMPILING. Built-in engine protections active.")
    end
end)

-- `/v-test-unlock` -> Simulates finishing/cancelling the benchmark (Restores editor controls)
commands.add_command("v-test-unlock", "Switches the current lab surface back to designing mode", function(event)
    local player = game.get_player(event.player_index)
    if player and compiler_manager.is_lab_surface(player.surface.index) then
        compiler_manager.set_lab_status(player.surface.index, "designing")
        player.print("[Compiler Master] STATUS RELEASED TO DESIGNING. Construction mode restored.")
    end
end)