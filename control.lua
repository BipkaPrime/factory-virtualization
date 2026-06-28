local entity_registry = require("scripts.entity-registry")
local lab_chunks_registry = require("scripts.lab-chunks-registry")
local udlink_manager = require("scripts.udlink-manager")
local template_compiler = require("scripts.template-compiler")
local lab_force = require("scripts.lab-force")
require("scripts.gui-v2.main")


-- TODO: If entity is no longer valid, its interface will not close by itself.
-- TODO: udlinks ghosts are clickable. And when clicked vanilla gui pops up.
-- This is a big problem for energy udlinks since they are electric energy interfaces.
-- TODO: unlock tech for player force if lab force unlocked it. This way if player somehow (scripts, cheats, etc)
-- unlocks something while being with lab force, sync is not lost. Also need to prevent infinite loops!
-- TODO: fix input science pack values for compilations with research
-- currently the problem is consumed packs are divided by the full length of 
-- benchmarking process. Because of this, values are much smaller than they should be.
-- The correct approach is to divide total number of research points produced by the
-- corresponding number of time the science pack was researching.
-- TODO: Make registry bulletproof. Currently it's possible to break it and crash the mod
-- It will happen if entity from registry is destroyed by script without raising an event
-- We can counter this by script.register_on_object_destroyed(entity)
-- and then catching on_object_destroyed event.

-- TODO: completely separate virtual surfaces that can produce research points from the rest. Create 2 different virtual surface types:
-- First type can not produce research points (labs won't work here). (compiler will fire a warning if there are labs on the surface)
-- Second type can ONLY produce research points, IO checkbox uplinks are prohibited. (compilation won't start with them)
-- TODO: make gui buttons routers (currently buttons press events are processed 1 by 1 by button names)

-------------------------------------------------------------------------------
-- Initialization and lifecycle
-------------------------------------------------------------------------------

script.on_init(function()
    -- Used to track special virtualization surfaces added by this mod
    -- key: surface_id, value: table describing surface
    storage.v_surfaces = {}

    -- Used to track compiled production templates added by this mod
    -- key: template name, value: compiled templates (table) 
    storage.compiled_templates = {}

    -- Used to compile virtualization surfaces into production templates 
    -- key: surface_id, value: virtual environment (table)
    storage.compiling_surfaces = {}

    -- Used to track all operational virtual environments on all surfaces
    -- key: template name, value: virtual environments for that template (table)
    -- key: surface_id, value: venv (table)
    storage.virtual_environments = {}

    -- Used to track all chunks on virtualization surfaces for charting and running
    -- services on them (like auto ghost reviving, instant deconstruction, etc.)
    storage.lab_chunks_registry = {
        designing_chunks = {array = {}, lookup = {}},
        compiling_chunks = {array = {}, lookup = {}}
    }

    -- Initializes entity registry that keeps track of entities added by this mod
    -- that require on tick processing
    entity_registry.storage_init()

    -- Initializing technical lab force that owns everything built on virtualization surfaces. 
    lab_force.init_lab_force()

    -- Copying all of the given changeable values (except charts) from player force to lab force.
    game.forces["lab-technical"].copy_from("player")

    -- Used to track all technical research added by this mod to benchmark science production
    -- on virualization surfaces. 1-indexed array, value: table containing 2 keys: tech_name, ingredient_name
    storage.technical_research = {}
    lab_force.collect_technical_research()

    -- Used to track last opened entity with cusom gui.
    -- key: player_index, value: LuaEntity
    storage.last_opened_entity = storage.last_opened_entity or {}

    -- Used to track all players who have template dashboard opened
    -- keys: player id, value = table (selected_template, selected_surface, etc.)
    storage.dashboard = {}

    -- Used to track all players who have surface manager opened
    -- keys: player id, value = table (selected_surface, etc.)
    storage.surface_manager = {}
end)


script.on_configuration_changed(function()
    -- Copying all of the given changeable values (except charts) from player force to lab force.
    game.forces["lab-technical"].copy_from("player")

    -- We need to recollect technical research because science packs could have been added/deleted
    storage.technical_research = {}
    lab_force.collect_technical_research()
end)

-------------------------------------------------------------------------------
-- Build/Destroy events handlers for entity registry
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
-- Technology researched/unresearched handlers for lab force sync with player
-------------------------------------------------------------------------------

script.on_event(defines.events.on_player_changed_surface, function(event)
    lab_force.process_surface_changed(event)
end)

script.on_event(defines.events.on_research_finished, function(event)
    lab_force.process_research_finished(event)
end)

script.on_event(defines.events.on_research_reversed, function(event)
    lab_force.process_research_reversed(event)
end)

-------------------------------------------------------------------------------
-- Time based handlers for processing entity registry members, virtualization
-- surface chunks and processing compiling sufaces
-------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(event)
    udlink_manager.process_udlinks(event)
    lab_chunks_registry.process_chunks(event)
end)

script.on_nth_tick(60, function()
    template_compiler.process_compiling_surfaces()
end)