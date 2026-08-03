local EntityProcessor = require("src.world.entity-processor")
local ChunkProcessor = require("src.world.vsurface-chunk-processor")
local ClusterProcessor = require("src.simulation.cluster-processor")
local VEnvProcessor = require("src.simulation.venv-processor")
local CommonGui = require("src.gui.common")
local EntityGui = require("src.gui.entity")
local EntityControls = require("src.gui.entity-controls")
local SurfaceManagerGui = require("src.gui.vsurface-manager")
local TemplateDashboard = require("src.gui.template-dashboard")
local GuiUpdater = require("src.gui.updater")

local PREFIX = "FV-"

-------------------------------------------------------------------------------
-- Initialization and lifecycle
-------------------------------------------------------------------------------

script.on_init(function()
    -- world/entity-processor
    storage.entity_registry = {initialized = {}, uninitialized = {}, lookup = {}}
    -- world/vsurface-chunk-processor
    storage.vsurface_chunks = {}
    -- world/vsurface-manager
    storage.vsurfaces = {}
    -- simulation/cluster-processor
    storage.vclusters = {array = {}, lookup = {}}
    -- simulation/template-compiler
    storage.templates = {}
    -- simulation/venv-processor
    storage.venvs = {}
    -- gui/template-dashboard
    storage.template_dashboard = {}
    -- gui/vsurface-manager
    storage.surface_manager = {}
    -- gui/entity-gui
    storage.entity_gui = {}
    -- gui/updater
    storage.opened_guis = {array = {}, next_index = 1}
end)

script.on_configuration_changed(function()

end)

-------------------------------------------------------------------------------
-- TIME-BASED SCRIPTS
-------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(event)
    ClusterProcessor.process_clusters(event)
    EntityProcessor.process_entities(event)
    ChunkProcessor.process_chunks(event)
    GuiUpdater.update()
end)

script.on_nth_tick(60, function()
    VEnvProcessor.process_compiling_surfaces()
end)

-------------------------------------------------------------------------------
-- ENTITY PROCESSOR TAGS AND REGISTRATION
-------------------------------------------------------------------------------

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_revive
}

---Handles entity buing built. Adds it to entity registry.
---@param event EventData.on_built_entity
local function on_entity_built(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    EntityProcessor.register_entity(entity, event.tags)
end

-- subsribing to all "build events"
for _, event in ipairs(build_events) do
    script.on_event(event, on_entity_built, EntityProcessor.build_filter)
end

script.on_event(defines.events.on_player_setup_blueprint, function(event)
    EntityProcessor.setup_blueprint_tags(event)
end)

-------------------------------------------------------------------------------
-- GUI HANDLERS
-------------------------------------------------------------------------------

script.on_event(defines.events.on_gui_opened, function(event)
    EntityGui.process_gui_opened(event)
end)

local on_lua_shortcut_router = {
    [PREFIX .. "sm-shortcut"] = SurfaceManagerGui.process_surface_manager_shortcut,
    [PREFIX .. "td-shortcut"] = TemplateDashboard.process_dashboard_shortcut,
}
script.on_event(defines.events.on_lua_shortcut, function(event)
    local handler = on_lua_shortcut_router[event.prototype_name]
    if not handler then return end
    handler(event)
end)

---Picks a handler for event.element from router table.
---Only useful when routing is done by element.name
---@param event EventData
---@param router table<string, function>
local function element_name_router(event, router)
    ---@diagnostic disable-next-line: undefined-field
    local element = event.element
    if not element or not element.valid then return end
    local handler = router[element.name]
    if not handler then return end
    handler(event)
end

local on_gui_click_router = {
    [PREFIX .. "close-button"] = CommonGui.process_close_button,
    [PREFIX .. "sm-new-surface-btn"] = SurfaceManagerGui.process_create_new_surface_btn,
    [PREFIX .. "sm-delete-surface-btn"] = SurfaceManagerGui.process_delete_surface_btn,
    [PREFIX .. "sm-new-surface-confirm"] = SurfaceManagerGui.process_new_surface_confirm_btn,
    [PREFIX .. "sm-start-compilation-btn"] = SurfaceManagerGui.process_start_compilation_btn,
}
script.on_event(defines.events.on_gui_click, function(event)
    element_name_router(event, on_gui_click_router)
end)

local on_gui_closed_router = {
    [PREFIX .. "sm-window"] = SurfaceManagerGui.process_surface_manager_gui_closed,
    [PREFIX .. "td-window"] = TemplateDashboard.process_template_dashboard_gui_closed,
    [PREFIX .. "entity-window"] = EntityGui.process_entity_gui_closed,
}
script.on_event(defines.events.on_gui_closed, function(event)
    element_name_router(event, on_gui_closed_router)
end)

local on_gui_text_changed_router = {
    [PREFIX .. "sm-vsurface-search"] = SurfaceManagerGui.process_vsurface_selection_search,
    [PREFIX .. "sm-new-surface-name"] = SurfaceManagerGui.process_new_surface_name_changed,
    [PREFIX .. "sm-new-surface-width"] = SurfaceManagerGui.process_new_surface_width_changed,
    [PREFIX .. "sm-new-surface-height"] = SurfaceManagerGui.process_new_surface_height_changed,
    [PREFIX .. "sm-template-name"] = SurfaceManagerGui.process_template_name_changed,
    [PREFIX .. "td-template-search"] = TemplateDashboard.process_template_search,
    [PREFIX .. "td-surface-search"] = TemplateDashboard.process_surface_search,
    [PREFIX .. "first-template-search"] = EntityControls.process_first_template_searchfield,
    [PREFIX .. "second-template-search"] = EntityControls.process_second_template_searchfield,
    [PREFIX .. "capability-override-textfield"] = EntityControls.process_capability_override_textfield,
    [PREFIX .. "overflow-threshold-textfield"] = EntityControls.process_overflow_threshold_textfield,
}
script.on_event(defines.events.on_gui_text_changed, function(event)
    element_name_router(event, on_gui_text_changed_router)
end)

local on_gui_selection_state_changed_router = {
    [PREFIX .. "sm-vsurface-selector"] = SurfaceManagerGui.process_vsurface_selection_changed,
    [PREFIX .. "sm-planet-selector"] = SurfaceManagerGui.process_planet_selector,
    [PREFIX .. "td-template-selector"] = TemplateDashboard.process_template_selector,
    [PREFIX .. "td-surface-selector"] = TemplateDashboard.process_surface_selector,
    [PREFIX .. "first-template-selector"] = EntityControls.process_first_template_selector,
    [PREFIX .. "second-template-selector"] = EntityControls.process_second_template_selector,
}
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    element_name_router(event, on_gui_selection_state_changed_router)
end)

local on_gui_elem_changed_router = {
    [PREFIX .. "choose-item-button"] = EntityControls.process_choose_item_button,
    [PREFIX .. "choose-fluid-button"] = EntityControls.process_choose_fluid_button,
}
script.on_event(defines.events.on_gui_elem_changed, function(event)
    element_name_router(event, on_gui_elem_changed_router)
end)

local on_gui_checked_state_changed_router = {
    [PREFIX .. "input-radiobutton"] = EntityControls.process_input_chosen,
    [PREFIX .. "output-radiobutton"] = EntityControls.process_output_chosen,
    [PREFIX .. "item-mode-radiobutton"] = EntityControls.process_item_mode_radiobutton,
    [PREFIX .. "fluid-mode-radiobutton"] = EntityControls.process_fluid_mode_radiobutton,
    [PREFIX .. "energy-mode-radiobutton"] = EntityControls.process_energy_mode_radiobutton,
    [PREFIX .. "capability-override-checkbox"] = EntityControls.process_capability_override_checkbox,
}
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    element_name_router(event, on_gui_checked_state_changed_router)
end)

script.on_event(PREFIX .. "sm-hotkey", SurfaceManagerGui.process_surface_manager_hotkey)
script.on_event(PREFIX .. "td-hotkey", TemplateDashboard.process_dashboard_hotkey)

-------------------------------------------------------------------------------
-- DEBUG COMMANDS
-------------------------------------------------------------------------------

commands.add_command("save_template_data", "Saves all compiled template data to json", function()
    helpers.write_file("compiled_templates.json", serpent.block(storage.templates), false)
    game.print("Template data saved to compiled_templates.json")
end)