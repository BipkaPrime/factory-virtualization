local entity_registry = require("scripts.entity-registry")
local lab_chunks_registry = require("scripts.lab-chunks-registry")
local udlink_manager = require("scripts.udlink-manager")
local template_compiler = require("scripts.template-compiler")
local lab_force = require("scripts.lab-force")
local gui_common = require("scripts.gui.common-gui-elements")
local entity_gui_elements = require("scripts.gui.entity-gui-elements")
local entity_gui = require("scripts.gui.entity-gui")
local gui_names = require("scripts.gui.gui-names")
local dashboard = require("scripts.gui.template-dashboard")
require("scripts.lab-manager")



-- TODO: If entity is no longer valid, the interface will not close by itself.
-- TODO: udlinks ghosts are clickable. And when clicked vanilla gui pops up.
-- This is a big problem for energy udlinks since they are electric energy interfaces.
-- TODO: unlock tech for player force if lab force unlocked it. This way if player somehow (scripts, cheats, etc)
-- unlocks something while being with lab force, sync is not lost. Also need to prevent infinite loops!
-- TODO: add pollution to compilation
-- TODO: fix input science pack values for compilations with research
-- currently the problem is consumed packs are divided by the full length of 
-- benchmarking process. Because of this, values are much smaller than they should be.
-- The correct approach is to divide total number of research points produced by the
-- corresponding number of science packs consumed.
-- TODO: Make registry bulletproof. Currently it's possible to break it and crash the mod
-- It will happen if entity from registry is destroyed by script without raising an event
-- We can counter this by script.register_on_object_destroyed(entity)
-- and then catching on_object_destroyed event.
-- TODO: make function to check that surface compilation was valid. Like there are no chests full of trash etc.
-- TODO: sort items by count in dashboard sprite-button tables

-------------------------------------------------------------------------------
-- Initialization and lifecycle
-------------------------------------------------------------------------------

script.on_init(function()
    -- Used to track special virtualization surfaces added by this mod
    -- key: surface_id, value: true
    storage.lab_surfaces = {}
    
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

    -- Technological progress of lab force must always match progress of player force
    lab_force.sync_technologies()

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
end)


script.on_configuration_changed(function()
    -- Sync technologies just in case
    lab_force.sync_technologies()

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

-------------------------------------------------------------------------------
-- GUI ZONE
-------------------------------------------------------------------------------

script.on_event(defines.events.on_gui_opened, function(event)
    entity_gui.process_entity_gui_opened(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
    entity_gui.process_entity_gui_closed(event)
    dashboard.process_dashboard_gui_closed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
    gui_common.process_close_button(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    entity_gui_elements.process_udlink_item_selection(event)
    entity_gui_elements.process_udlink_fluid_selection(event)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    entity_gui_elements.process_udlink_io_checkbox(event)
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    entity_gui_elements.process_entity_freq_selector(event)
    dashboard.process_dashboard_template_selector(event)
    dashboard.process_dashboard_surface_selector(event)
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    entity_gui_elements.process_entity_freq_search(event)
    dashboard.process_dashboard_template_search(event)
    dashboard.process_dashboard_surface_search(event)
end)


local dashboard_shortcut_name = gui_names.prefix .. gui_names.template_dashboard
-- Toggles production template dashboard when shortcut bar element is clicked
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == dashboard_shortcut_name then
        local player = game.get_player(event.player_index)
        if not player then return end
        dashboard.toggle_template_dashboard(player)
    end
end)

-- Toggles production template dashboard when custom hotkey is pressed
script.on_event(gui_names.prefix .. gui_names.dashboard_hotkey, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    dashboard.toggle_template_dashboard(player)
end)