-- contains all gui-related scripts

local common = require("scripts.gui.common")
local names = require("scripts.gui.names")
local surface_manager = require("scripts.gui.vsurface-manager")
local template_dashboard = require("scripts.gui.template-dashboard")
local entity_gui = require("scripts.gui.entity")
local entity_controls = require("scripts.gui.entity-controls")

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
    entity_gui.update_entity_gui_datafield()
end

local on_gui_click_router = {
    [names.prefix .. names.close_button] = common.process_close_button,
    [names.prefix .. names.sm_new_surface_btn] = surface_manager.process_new_surface_button,
    [names.prefix .. names.sm_new_surface_confirm] = surface_manager.process_creation_confirm,
    [names.prefix .. names.sm_start_compilation_btn] = surface_manager.process_compile_button,
    [names.prefix .. names.sm_delete_surface_btn] = surface_manager.process_delete_surface_button,
}
script.on_event(defines.events.on_gui_click, function(event)
    gui_name_router(event, on_gui_click_router)
end)

local on_gui_closed_router = {
    [names.prefix .. names.sm_window] = surface_manager.process_surface_manager_gui_closed,
    [names.prefix .. names.td_window] = template_dashboard.process_template_dashboard_gui_closed,
    [names.prefix .. names.entity_window] = entity_gui.process_entity_gui_closed,
}
script.on_event(defines.events.on_gui_closed, function(event)
    gui_name_router(event, on_gui_closed_router)
end)

local on_lua_shortcut_router = {
    [names.prefix .. names.sm_shortcut] = surface_manager.process_surface_manager_shortcut,
    [names.prefix .. names.td_shortcut] = template_dashboard.process_dashboard_shortcut,
}
script.on_event(defines.events.on_lua_shortcut, function(event)
    local handler = on_lua_shortcut_router[event.prototype_name]
    if not handler then return end
    handler(event)
end)

local on_gui_text_changed_router = {
    [names.prefix .. names.sm_vsurface_search] = surface_manager.process_vsurface_searchfield,
    [names.prefix .. names.sm_new_surface_name] = surface_manager.process_new_surface_name_changed,
    [names.prefix .. names.sm_template_name] = surface_manager.process_template_name_textfield,
    [names.prefix .. names.td_template_search] = template_dashboard.process_template_search,
    [names.prefix .. names.entity_template_search] = entity_controls.process_template_searchfield,
}
script.on_event(defines.events.on_gui_text_changed, function(event)
    gui_name_router(event, on_gui_text_changed_router)
end)

local on_gui_selection_state_changed_router = {
    [names.prefix .. names.sm_vsurface_selector] = surface_manager.process_vsurface_selector,
    [names.prefix .. names.sm_new_surface_type] = surface_manager.process_new_surface_type,
    [names.prefix .. names.sm_new_surface_size] = surface_manager.process_new_surface_size,
    [names.prefix .. names.td_template_selector] = template_dashboard.process_template_selector,
    [names.prefix .. names.entity_template_selector] = entity_controls.process_template_selector,
}
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    gui_name_router(event, on_gui_selection_state_changed_router)
end)

local on_gui_checked_state_changed_router = {
    [names.prefix .. names.udlink_io_checkbox] = entity_controls.process_udlink_io_checkbox,
}
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    gui_name_router(event, on_gui_checked_state_changed_router)
end)

local on_gui_elem_changed_router = {
    [names.prefix .. names.udlink_choose_item_button] = entity_controls.process_udlink_choose_item_button,
    [names.prefix .. names.udlink_choose_fluid_button] = entity_controls.process_udlink_choose_fluid_button,
}
script.on_event(defines.events.on_gui_elem_changed, function(event)
    gui_name_router(event, on_gui_elem_changed_router)
end)

return Helper