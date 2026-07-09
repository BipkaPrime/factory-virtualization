PREFIX = "FV-"

require("scripts.copy-paste")
local chunk_processor = require("scripts.template-creation.chunk-processor")
local entity_processor = require("scripts.entity-processor")
local entity_params = require("scripts.entity-params")
local vcluster = require("scripts.vcluster")
local venv_processor = require "scripts.template-creation.venv-processor"
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

    -- Used to store all existing clusters in a flat array for processing.
    storage.cluster_list = {}

    -- Used to track all chunks on virtualization surfaces for charting and running
    -- services on them (like auto ghost reviving, instant deconstruction, etc.)
    storage.vsurface_chunks = {}

    -- Used to keeps track of entities added by this mod that require on tick processing
    storage.entity_registry = {array = {}, lookup = {}}

    -- Initializing params related to entities added by this mod
    entity_params.storage_init()

    -- Creating technical force for research templates and collecting technical research
    venv_processor.init_lab_force()

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

end)


entity_processor.subscribe_to_build_events()

-------------------------------------------------------------------------------
-- Time based handlers for processing entity registry members, virtualization
-- surface chunks, processing compiling sufaces, etc.
-------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(event)
    entity_processor.entity_processor(event)
    chunk_processor.chunk_processor(event)
    vcluster.process_clusters(event)
end)

script.on_nth_tick(60, function()
    venv_processor.process_compiling_surfaces()
    gui.process_opened_windows()
end)

script.on_event(defines.events.on_player_changed_surface, function(event)
    gui.process_player_changed_surface(event)
end)