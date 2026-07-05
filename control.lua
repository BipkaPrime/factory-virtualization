local chunk_registry = require("scripts.vsurface-chunk-registry")
local lab_force = require("scripts.lab-force")
local entity_registry = require("scripts.entity-registry.main")
local template_compiler = require("scripts.template-compiler")
local entity_params = require("scripts.entity_params")
local gui = require("scripts.gui.main")


-- TODO: If entity is no longer valid, its interface will not close by itself.
-- TODO: fix research compilation inaccuracies (probably by looking at consumed packs statistics)

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

    -- Used to track all operational virtualization clusters on all surfaces
    -- storage.vclusters[template_name][surface_id] = table (cluster data)
    storage.vclusters = {}

    -- Used to track all chunks on virtualization surfaces for charting and running
    -- services on them (like auto ghost reviving, instant deconstruction, etc.)
    storage.vsurface_chunks = {}

    -- Used to keeps track of entities added by this mod that require on tick processing
    storage.entity_registry = {array = {}, lookup = {}}

    -- Initializing params related to entities added by this mod
    entity_params.storage_init()

    -- Initializing technical lab force that owns everything built on virtualization surfaces. 
    lab_force.init_lab_force()

    ---------------------------------------------------------------------------------
    -- GUI ZONE
    ---------------------------------------------------------------------------------

    -- Used to store data of dashboard gui window for all players
    -- keys: player id, value = table (selected_template, selected_surface, etc.)
    storage.template_dashboard = {}

    -- Used to store data of surface manager gui window for all players
    -- keys: player id, value = table (selected_surface, etc.)
    storage.surface_manager = {}

    -- Used to track of last opened entity with cusom gui.
    -- key: player_index, value: table
    storage.entity_gui = {}
end)


script.on_configuration_changed(function()
    -- recollecting technical research
    lab_force.init_lab_force()
end)

-------------------------------------------------------------------------------
-- Technology researched/unresearched handlers
-------------------------------------------------------------------------------

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
    entity_registry.entity_processor(event)
    chunk_registry.chunk_processor(event)
end)

script.on_nth_tick(60, function()
    template_compiler.process_compiling_surfaces()
    gui.process_opened_windows()
end)


script.on_event(defines.events.on_player_changed_surface, function(event)
    lab_force.process_player_changed_surface(event)
    gui.process_player_changed_surface(event)
end)