-- contains all gui-related scripts

local common = require("scripts.gui-v2.common")
local names = require("scripts.gui-v2.names")
local surface_manager = require("scripts.gui-v2.surface-manager")


-- Picks a handler for event.element from router table.
-- Only useful when routing is done by element.name
local function gui_name_router(event, router)
    local element = event.element
    if not element then return end
    local handler = router[element.name]
    if not handler then return end
    handler(event)
end

local on_gui_click_router = {
    [names.prefix .. names.close_button] = common.process_close_button,
    [names.prefix .. names.sm_new_surface_btn] = surface_manager.process_new_surface_button,
    [names.prefix .. names.sm_new_surface_confirm_btn] = surface_manager.process_creation_confirm,
    [names.prefix .. names.sm_start_compilation_btn] = surface_manager.process_compile_button,
}
script.on_event(defines.events.on_gui_click, function(event)
    gui_name_router(event, on_gui_click_router)
end)

local on_gui_closed_router = {
    [names.prefix .. names.sm_window] = surface_manager.process_surface_manager_gui_closed,
}
script.on_event(defines.events.on_gui_closed, function(event)
    gui_name_router(event, on_gui_closed_router)
end)

local on_lua_shortcut_router = {
    [names.prefix .. names.sm_shortcut] = surface_manager.process_surface_manager_shortcut,
}
script.on_event(defines.events.on_lua_shortcut, function(event)
    local handler = on_lua_shortcut_router[event.prototype_name]
    if not handler then return end
    handler(event)
end)

local on_gui_text_changed_router = {
    [names.prefix .. names.sm_left_search] = surface_manager.process_left_searchfield,
    [names.prefix .. names.sm_new_surface_name_textfield] = surface_manager.process_new_surface_name_changed,
    [names.prefix .. names.sm_template_name_textfield] = surface_manager.process_template_name_textfield,
}
script.on_event(defines.events.on_gui_text_changed, function(event)
    gui_name_router(event, on_gui_text_changed_router)
end)

local on_gui_selection_state_changed_router = {
    [names.prefix .. names.sm_left_selector] = surface_manager.process_vsurface_selector,
    [names.prefix .. names.sm_new_surface_type] = surface_manager.process_new_surface_type,
    [names.prefix .. names.sm_new_surface_size] = surface_manager.process_new_surface_size,
}
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    gui_name_router(event, on_gui_selection_state_changed_router)
end)

--[[
script.on_event(defines.events.on_gui_opened, function(event)
    entity_gui.process_entity_gui_opened(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
    entity_gui.process_entity_gui_closed(event)
    dashboard.process_dashboard_gui_closed(event)
    surface_manager.process_surface_manager_gui_closed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
    gui_common.process_close_button(event)
    --surface_manager.process_new_surface_button(event)
    --surface_manager.process_creation_confirm(event)
    --surface_manager.process_compile_button(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    entity_gui_elements.process_udlink_item_selection(event)
    entity_gui_elements.process_udlink_fluid_selection(event)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    entity_gui_elements.process_udlink_io_checkbox(event)
end)





script.on_event(defines.events.on_lua_shortcut, function(event)
    dashboard.process_dashboard_shortcut(event)
    surface_manager.process_surface_manager_shortcut(event)
end)

script.on_event(gui_names.prefix .. gui_names.dashboard_hotkey, function(event)
    dashboard.process_dashboard_hotkey(event)
end)
--]]