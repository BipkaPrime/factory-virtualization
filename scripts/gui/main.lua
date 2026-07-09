local common = require("scripts.gui.common")
local surface_manager = require("scripts.gui.vsurface-manager")
local template_dashboard = require("scripts.gui.template-dashboard")
local entity_gui = require("scripts.gui.entity")

local Helper = {}

-- Picks a handler for event.element from router table.
-- Only useful when routing is done by element.name
local function gui_name_router(event, router)
    local element = event.element
    if not element then return end
    local handler = router[element.name]
    if not handler then return end
    handler(event)
end

-- After player changes surface with custom gui window opened
-- player.opened can be assigned nil with window still opened
-- So if window should be opened, we set player.opened to it.
function Helper.process_player_changed_surface(event)
    template_dashboard.process_player_changed_surface(event)
    surface_manager.process_player_changed_surface(event)
    entity_gui.process_player_changed_surface(event)
end

-- Time-based processing of custom gui windows
function Helper.process_opened_windows()
    surface_manager.update_opened_managers()
    entity_gui.update_entity_gui()
end

local on_gui_click_router = {
    [PREFIX .. "close-button"] = common.process_close_button,
    [PREFIX .. "sm-new-surface-btn"] = surface_manager.process_new_surface_button,
    [PREFIX .. "sm-new-surface-confirm"] = surface_manager.process_creation_confirm,
    [PREFIX .. "sm-start-compilation-btn"] = surface_manager.process_compile_button,
    [PREFIX .. "sm-delete-surface-btn"] = surface_manager.process_delete_surface_button,
}
script.on_event(defines.events.on_gui_click, function(event)
    gui_name_router(event, on_gui_click_router)
end)

local on_gui_closed_router = {
    [PREFIX .. "sm-window"] = surface_manager.process_surface_manager_gui_closed,
    [PREFIX .. "td-window"] = template_dashboard.process_template_dashboard_gui_closed,
    [PREFIX .. "entity-window"] = entity_gui.process_entity_gui_closed,
}
script.on_event(defines.events.on_gui_closed, function(event)
    gui_name_router(event, on_gui_closed_router)
end)

local on_lua_shortcut_router = {
    [PREFIX .. "sm-shortcut"] = surface_manager.process_surface_manager_shortcut,
    [PREFIX .. "td-shortcut"] = template_dashboard.process_dashboard_shortcut,
}
script.on_event(defines.events.on_lua_shortcut, function(event)
    local handler = on_lua_shortcut_router[event.prototype_name]
    if not handler then return end
    handler(event)
end)

local on_gui_text_changed_router = {
    [PREFIX .. "sm-vsurface-search"] = surface_manager.process_vsurface_searchfield,
    [PREFIX .. "sm-new-surface-name"] = surface_manager.process_new_surface_name_changed,
    [PREFIX .. "sm-template-name"] = surface_manager.process_template_name_textfield,
    [PREFIX .. "td-template-search"] = template_dashboard.process_template_search,
    [PREFIX .. "entity-template-search"] = entity_gui.process_template_searchfield,
}
script.on_event(defines.events.on_gui_text_changed, function(event)
    gui_name_router(event, on_gui_text_changed_router)
end)

local on_gui_selection_state_changed_router = {
    [PREFIX .. "sm-vsurface-selector"] = surface_manager.process_vsurface_selector,
    [PREFIX .. "sm-new-surface-type"] = surface_manager.process_new_surface_type,
    [PREFIX .. "sm-new-surface-size"] = surface_manager.process_new_surface_size,
    [PREFIX .. "td-template-selector"] = template_dashboard.process_template_selector,
    [PREFIX .. "entity-template-selector"] = entity_gui.process_template_selector,
}
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    gui_name_router(event, on_gui_selection_state_changed_router)
end)

local on_gui_elem_changed_router = {
    [PREFIX .. "choose-item-button"] = entity_gui.process_choose_item_button,
    [PREFIX .. "choose-fluid-button"] = entity_gui.process_choose_fluid_button,
}
script.on_event(defines.events.on_gui_elem_changed, function(event)
    gui_name_router(event, on_gui_elem_changed_router)
end)

local on_gui_checked_state_changed_router = {
    [PREFIX .. "input-radiobutton"] = entity_gui.process_input_chosen,
    [PREFIX .. "output-radiobutton"] = entity_gui.process_output_chosen,
}
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    gui_name_router(event, on_gui_checked_state_changed_router)
end)

return Helper