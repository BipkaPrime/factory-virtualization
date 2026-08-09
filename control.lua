local EntityProcessor = require("src.world.entity-processor")
local ChunkProcessor = require("src.world.vsurface-chunk-processor")
local ClusterProcessor = require("src.simulation.cluster-processor")
local VEnvProcessor = require("src.simulation.venv-processor")
local CommonGui = require("src.gui.common")
local EntityGui = require("src.gui.entity")
local EntityControls = require("src.gui.entity-controls")
local ControlCenter = require("src.gui.control-center")
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
    storage.vsurfaces = {array = {}, lookup = {}}
    -- simulation/cluster-processor
    storage.clusters = {array = {}, lookup = {}}
    -- simulation/computation-manager
    storage.computation = {maximum_available = 0, required = 0}
    -- simulation/template-compiler
    storage.templates = {}
    -- simulation/venv-processor
    storage.venvs = {}
    -- gui/control-center
    storage.control_center = {}
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
    [PREFIX .. "control-center-shortcut"] = ControlCenter.handle_shortcut,
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
}
script.on_event(defines.events.on_gui_click, function(event)
    element_name_router(event, on_gui_click_router)
end)

local on_gui_closed_router = {
    [PREFIX .. "entity-window"] = EntityGui.process_entity_gui_closed,
    [PREFIX .. "control-center-window"] = ControlCenter.handle_window_closed,
}
script.on_event(defines.events.on_gui_closed, function(event)
    element_name_router(event, on_gui_closed_router)
end)

local on_gui_text_changed_router = {
    [PREFIX .. "first-template-search"] = EntityControls.process_first_template_searchfield,
    [PREFIX .. "second-template-search"] = EntityControls.process_second_template_searchfield,
    [PREFIX .. "capability-override-textfield"] = EntityControls.process_capability_override_textfield,
    [PREFIX .. "overflow-threshold-textfield"] = EntityControls.process_overflow_threshold_textfield,
}
script.on_event(defines.events.on_gui_text_changed, function(event)
    element_name_router(event, on_gui_text_changed_router)
end)

local on_gui_selection_state_changed_router = {
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

script.on_event(PREFIX .. "control-center-hotkey", ControlCenter.handle_hotkey)

-------------------------------------------------------------------------------
-- DEBUG COMMANDS
-------------------------------------------------------------------------------

commands.add_command("save_template_data", "Saves all compiled template data to json", function()
    helpers.write_file("compiled_templates.json", serpent.block(storage.templates), false)
    game.print("Template data saved to compiled_templates.json")
end)

commands.add_command("set_computation_demand", "", function(event)
    local d = tonumber(event.parameter) or 0
    storage.computation.required = storage.computation.maximum_available * d
    game.print("Demand set to " .. d .. " (Required: " .. storage.computation.required .. ")")
end)