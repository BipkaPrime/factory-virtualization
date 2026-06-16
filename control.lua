-- Import external modules from the scripts directory
local entity_registry = require("scripts.entity-registry")
local lab_chunks_registry = require("scripts.lab-chunks-registry")
local interface_manager = require("scripts.interface-manager")
local gui_manager = require("scripts.gui.main")
require("scripts.lab-manager")

-------------------------------------------------------------------------------
-- 1. INITIALIZATION & LIFECYCLE
-------------------------------------------------------------------------------

script.on_init(function()
    lab_chunks_registry.storage_init()
    entity_registry.storage_init()
    gui_manager.storage_init()
end)

script.on_configuration_changed(function(data)

end)

-------------------------------------------------------------------------------
-- 2. Event-based handlers
-------------------------------------------------------------------------------

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_revive
}

local function on_entity_built(event)
    entity_registry.register_entity(event)
end

for _, event in ipairs(build_events) do
    script.on_event(event, on_entity_built, entity_registry.event_filter)
end

local destroy_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_space_platform_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
}

local function on_entity_destroyed(event)
    entity_registry.unregister_entity(event)
end

for _, event in ipairs(destroy_events) do
    script.on_event(event, on_entity_destroyed, entity_registry.event_filter)
end

-------------------------------------------------------------------------------
-- 3. Tick-based handlers
-------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(event)
    interface_manager.process_interfaces(event)
    lab_chunks_registry.process_chunks(event)
end)