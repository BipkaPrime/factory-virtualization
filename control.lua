-- Import external modules from the scripts directory
local entity_registry = require("scripts.entity-registry")
local lab_chunks_registry = require("scripts.lab-chunks-registry")
local interface_manager = require("scripts.interface-manager")
require("scripts.gui.main")
require("scripts.lab-manager")

-------------------------------------------------------------------------------
-- 1. INITIALIZATION & LIFECYCLE
-------------------------------------------------------------------------------

script.on_init(function()
    lab_chunks_registry.storage_init()
    entity_registry.storage_init()
end)

script.on_configuration_changed(function(data)

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
    lab_chunks_registry.process_chunks(event)
end)