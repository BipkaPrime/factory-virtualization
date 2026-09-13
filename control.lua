local EntityProcessor = require("scripts.world.entity-processor")
local ChunkProcessor = require("scripts.world.vsurface-chunk-processor")
local ClusterProcessor = require("scripts.simulation.cluster-processor")
local VSurfaceManager = require("scripts.world.vsurface-manager")
local CommonGui = require("scripts.gui.common")
local EntityGui = require("scripts.gui.entity")
local ControlCenter = require("scripts.gui.control-center")
local CCSurfaces = require("scripts.gui.cc-modules.surfaces")
local CCTemplates = require("scripts.gui.cc-modules.templates")
local CCClusters = require("scripts.gui.cc-modules.clusters")
local GuiUpdater = require("scripts.gui.updater")
local ProductionResearch = require("scripts.world.production-research")

local PREFIX = "FV-"

--TODO: add on_surface_deleted handler (for clusters and vsurfaces?)
--TODO: on player removed for GUI?
--TODO: update control center gui (hover events left side of interface).

-------------------------------------------------------------------------------
------------------------ INITIALIZATION AND LIFECYCLE -------------------------
-------------------------------------------------------------------------------

script.on_init(function()
    ProductionResearch.initialize_storage()
    -- world/entity-processor
    ---@type EntityRegistry
    storage.entity_registry = {
        active = {},
        stalled = {},
        pending = {},
        incorrect = {},
        lookup = {},
    }
    -- world/vsurface-chunk-processor
    ---@type ChunkData[]
    storage.vsurface_chunks = {}
    -- world/vsurface-manager
    ---@type VSurfaceStorage
    storage.vsurfaces = {
        array = {},
        lookup_by_index = {},
        lookup_by_name = {},
        compilation_queue = {},
        next_compilation = 1
    }
    -- simulation/cluster-processor
    ---@type ClusterStorage
    storage.clusters = {
        array = {},
        lookup = {},
        name_to_uuid = {},
        uuid_to_name = {}
    }
    -- simulation/tcc-manager
    ---@type TCCData
    storage.tcc = {allowed_surface = "aquilo"}
    ---@type ComputationStorage
    storage.computation = {max_available = 0, curr_demand = 0}
    ---@type TemplateStorage
    storage.templates = {
        template_lookup = {},
        name_to_uuid = {},
        uuid_to_name = {},
        transmit = {},
        transmit_inv = {},
        receive = {},
        receive_inv = {},
    }
    -- gui/control-center
    ---@type table<integer, ControlCenterData>
    storage.control_center = {}
    -- gui/entity-gui
    ---@type table<integer, EntityGuiData>
    storage.entity_gui = {}
    -- gui/updater
    ---@type GuiUpdater
    storage.gui_updater = {array = {}, lookup = {}, next_index = 1}
end)

script.on_configuration_changed(function(change_data)
    -- TODO: when migration is applied (any mod in the save)
    -- have to apply it to all data structures:
    -- entity processor: selected item, selected fluid,
    -- vsurfaces (compilation tables)
    -- clusters (internal buffers, members?)
    -- templates (io, constuction cost)

    -- TODO: close opened gui windows here and clear related structures?
    -- control_center, entity_gui, gui_updater
end)

script.on_event(defines.events.on_pre_player_removed, function(event)
    -- cleaning up gui-related data associated with deleted player
    ControlCenter.on_pre_player_removed(event)
    EntityGui.on_pre_player_removed(event)
end)

-------------------------------------------------------------------------------
-- TIME-BASED SCRIPTS
-------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(event)
    ClusterProcessor.on_tick(event)
    EntityProcessor.on_tick(event)
    ChunkProcessor.process_chunks(event)
    VSurfaceManager.on_tick_updater()
    GuiUpdater.on_tick()
end)

script.on_nth_tick(3600, ProductionResearch.check_progress)

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
-------------------------------- GUI HANDLERS ---------------------------------
-------------------------------------------------------------------------------

script.on_event(defines.events.on_gui_opened, function(event)
    EntityGui.handle_gui_opened(event)
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
    [PREFIX .. "cc-surface-mode"] = ControlCenter.handle_surface_mode_button,
    [PREFIX .. "cc-template-mode"] = ControlCenter.handle_template_mode_button,
    [PREFIX .. "cc-cluster-mode"] = ControlCenter.handle_cluster_mode_button,
    [PREFIX .. "cc-new-surface-btn"] = CCSurfaces.handle_new_surface_button,
    [PREFIX .. "cc-delete-surface-btn"] = CCSurfaces.handle_surface_delete_button,
    [PREFIX .. "cc-start-compilation-btn"] = CCSurfaces.handle_compilation_start_button,
    [PREFIX .. "cc-stop-compilation-btn"] = CCSurfaces.handle_compilation_stop_button,
    [PREFIX .. "cc-new-vsurface-confirm"] = CCSurfaces.handle_new_vsurface_confirm_button,
    [PREFIX .. "cc-confirm-vsurface-delete"] = CCSurfaces.handle_confirm_surface_deletion_btn,
    [PREFIX .. "cc-confirm-compile"] = CCSurfaces.handle_confirm_compilation_button,
    [PREFIX .. "cc-confirm-compile-stop"] = CCSurfaces.handle_confirm_compilation_stop_button,
    [PREFIX .. "cc-view-surface-btn"] = CCSurfaces.handle_view_vsurface_btn,
    [PREFIX .. "cc-rename-template"] = CCTemplates.handle_rename_template_button,
    [PREFIX .. "cc-delete-template"] = CCTemplates.handle_delete_template_button,
    [PREFIX .. "cc-confirm-template-rename"] = CCTemplates.handle_template_rename_confirm_btn,
    [PREFIX .. "cc-confirm-template-deletion"] = CCTemplates.handle_template_deletion_confirm_btn,
    [PREFIX .. "cc-new-cluster-btn"] = CCClusters.handle_new_cluster_btn,
    [PREFIX .. "cc-rename-cluster"] = CCClusters.handle_rename_cluster_btn,
    [PREFIX .. "cc-clear-template-btn"] = CCClusters.handle_clear_template_btn,
    [PREFIX .. "cc-delete-cluster-btn"] = CCClusters.handle_delete_cluster_btn,
    [PREFIX .. "cc-select-current-surface-btn"] = CCClusters.handle_select_current_surface_btn,
    [PREFIX .. "cc-new-cluster-confirm"] = CCClusters.handle_confirm_cluster_creation_btn,
    [PREFIX .. "cc-confirm-template-clear"] = CCClusters.handle_confirm_template_clear_btn,
    [PREFIX .. "cc-confirm-cluster-delete"] = CCClusters.handle_confirm_cluster_delete_btn,
    [PREFIX .. "cc-confirm-cluster-rename"] = CCClusters.handle_confirm_cluster_rename,
    [PREFIX .. "cc-view-problems"] = CCClusters.handle_view_problems_btn,
    [PREFIX .. "entity-proximity-chart"] = EntityGui.handle_proximity_chart_btn,
    [PREFIX .. "entity-proximity-world"] = EntityGui.handle_proximity_world_btn,
    [PREFIX .. "cc-view-tcc"] = CCSurfaces.handle_view_tcc_button,
    [PREFIX .. "entity-open-cc"] = EntityGui.handle_open_cc_btn,
    [PREFIX .. "cc-view-cluster"] = CCClusters.handle_view_cluster_btn,
    [PREFIX .. "cc-rename-surface-btn"] = CCSurfaces.handle_rename_surface_btn,
    [PREFIX .. "cc-confirm-vsurface-rename"] = CCSurfaces.handle_vsurface_rename_confirm,
    [PREFIX .. "cc-vsurface-update"] = CCSurfaces.handle_vsurface_updates_btn,
    [PREFIX .. "cc-template-update"] = CCTemplates.handle_template_updates_btn,
    [PREFIX .. "cc-cluster-update"] = CCClusters.handle_cluster_updates_btn,
}
script.on_event(defines.events.on_gui_click, function(event)
    element_name_router(event, on_gui_click_router)
end)

local on_gui_closed_router = {
    [PREFIX .. "entity-window"] = EntityGui.handle_entity_gui_closed,
    [PREFIX .. "control-center-window"] = ControlCenter.handle_window_closed,
}
script.on_event(defines.events.on_gui_closed, function(event)
    element_name_router(event, on_gui_closed_router)
end)

local on_gui_text_changed_router = {
    [PREFIX .. "cc-idle-surface-search"] = CCSurfaces.handle_idle_surface_search,
    [PREFIX .. "cc-compiling-surface-search"] = CCSurfaces.handle_compiling_surface_search,
    [PREFIX .. "cc-new-vsurface-name"] = CCSurfaces.handle_new_vsurface_name_textfield,
    [PREFIX .. "cc-new-vsurface-width"] = CCSurfaces.handle_new_vsurface_width_changed,
    [PREFIX .. "cc-new-vsurface-height"] = CCSurfaces.handle_new_vsurface_height_changed,
    [PREFIX .. "cc-new-template-name"] = CCSurfaces.handle_new_template_name_textfield,
    [PREFIX .. "cc-inactive-template-search"] = CCTemplates.handle_inactive_template_search,
    [PREFIX .. "cc-active-template-search"] = CCTemplates.handle_active_template_search,
    [PREFIX .. "cc-template-rename-textfield"] = CCTemplates.handle_template_rename_textfield,
    [PREFIX .. "cc-suboptimal-cluster-search"] = CCClusters.handle_suboptimal_cluster_search,
    [PREFIX .. "cc-optimal-cluster-search"] = CCClusters.handle_optimal_cluster_search,
    [PREFIX .. "cc-new-cluster-name"] = CCClusters.handle_new_cluster_name,
    [PREFIX .. "cc-cluster-rename-textfield"] = CCClusters.handle_cluster_rename_textfield,
    [PREFIX .. "entity-fc-search"] = EntityGui.handle_first_cluster_search,
    [PREFIX .. "entity-sc-search"] = EntityGui.handle_second_cluster_search,
    [PREFIX .. "entity-override-textfield"] = EntityGui.handle_override_textfield,
    [PREFIX .. "entity-overflow-threshold"] = EntityGui.handle_overflow_threshold,
    [PREFIX .. "entity-template-search"] = EntityGui.handle_selected_template_search,
    [PREFIX .. "cc-vsurface-rename-textfield"] = CCSurfaces.handle_vsurface_rename_textfield,
}
script.on_event(defines.events.on_gui_text_changed, function(event)
    element_name_router(event, on_gui_text_changed_router)
end)

local on_gui_selection_state_changed_router = {
    [PREFIX .. "cc-idle-surface-selector"] = CCSurfaces.handle_surface_selection_change,
    [PREFIX .. "cc-compiling-surface-selector"] = CCSurfaces.handle_surface_selection_change,
    [PREFIX .. "cc-generate-as-selector"] = CCSurfaces.handle_new_vsurface_generate_as_selector,
    [PREFIX .. "cc-inactive-template-selector"] = CCTemplates.handle_template_selection_change,
    [PREFIX .. "cc-active-template-selector"] = CCTemplates.handle_template_selection_change,
    [PREFIX .. "cc-suboptimal-cluster-selector"] = CCClusters.handle_cluster_selection_change,
    [PREFIX .. "cc-optimal-cluster-selector"] = CCClusters.handle_cluster_selection_change,
    [PREFIX .. "cc-new-cluster-selector"] = CCClusters.handle_new_cluster_surface_selection,
    [PREFIX .. "entity-fc-selector"] = EntityGui.handle_first_cluster_selection,
    [PREFIX .. "entity-sc-selector"] = EntityGui.handle_second_cluster_selection,
    [PREFIX .. "entity-template-selector"] = EntityGui.handle_selected_template_selection,
}
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    element_name_router(event, on_gui_selection_state_changed_router)
end)

local on_gui_elem_changed_router = {
   [PREFIX .. "entity-item-selection"] = EntityGui.handle_item_selection,
   [PREFIX .. "entity-fluid-selection"] = EntityGui.handle_fluid_selection,
}
script.on_event(defines.events.on_gui_elem_changed, function(event)
    element_name_router(event, on_gui_elem_changed_router)
end)

local on_gui_checked_state_changed_router = {
    [PREFIX .. "entity-input-radiobtn"] = EntityGui.handle_input_radiobtn,
    [PREFIX .. "entity-output-radiobtn"] = EntityGui.handle_output_radiobtn,
    [PREFIX .. "entity-item-radiobtn"] = EntityGui.handle_item_radiobtn,
    [PREFIX .. "entity-fluid-radiobtn"] = EntityGui.handle_fluid_radiobtn,
    [PREFIX .. "entity-energy-radiobtn"] = EntityGui.handle_energy_radiobtn,
    [PREFIX .. "entity-override-checkbox"] = EntityGui.handle_override_checkbox,
}
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    element_name_router(event, on_gui_checked_state_changed_router)
end)

script.on_event(PREFIX .. "control-center-hotkey", ControlCenter.handle_hotkey)