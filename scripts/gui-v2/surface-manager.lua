-- V-surface manager is a gui window that allows players to manage virtualization
-- surfaces (create, destroy, start compilation, see information).

local compiler = require("scripts.template-compiler")
local backend = require("scripts.surface-manager-backend")
local common = require("scripts.gui-v2.common")
local names = require("scripts.gui-v2.names")
local utils = require("scripts.utils")

local Helper = {}

-- Creates a surface manager base that contains only elements that never change
-- It's assumed that surface manager is not opened when this is called.
local function surface_manager_base(player)
    -- creating base window and "opening" it
    local main_frame = common.gui_base_window(player, names.prefix .. names.sm_window)
    player.opened = main_frame
    storage.surface_manager[player.index] = storage.surface_manager[player.index] or {}
    local manager_data = storage.surface_manager[player.index]
    manager_data.opened = true
    manager_data.main_window = main_frame

    -- invisible container for other frames
    local main_content_frame = main_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    -- left frame of interface
    local left_content_frame = main_content_frame.add{
        type="frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    left_content_frame.style.right_margin = 12
    manager_data.left_frame = left_content_frame

    -- right half of interface
    local right_content_frame = main_content_frame.add{
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }
    right_content_frame.style.minimal_width = 350
    right_content_frame.style.vertically_stretchable = true
    manager_data.right_frame = right_content_frame
end

-- Updates all gui elements in the left frame
local function update_left_frame(player_index)
    local manager_data = storage.surface_manager[player_index]
    local left_frame = manager_data.left_frame
    left_frame.clear()

    -- vsurface selector widget
    local searchfield, selector = common.selection_widget(
        manager_data.left_frame,
        names.prefix .. names.sm_left_search,
        names.prefix .. names.sm_left_selector,
        {"gui-label.v-surface-selection"}
    )
    local query = manager_data.left_search_query
    searchfield.text = query or ""
    local selected_vsurface = manager_data.selected_vsurface
    local options = backend.get_all_vsurfaces()
    common.arrange_selector(selector, options, query, selected_vsurface)

    -- create new surface button
    local create_button = left_frame.add{
        type = "button",
        name = names.prefix .. names.sm_new_surface_btn,
        caption = {"gui-label.create-new-v-surface"},
    }
    create_button.style.horizontally_stretchable = true
    create_button.style.bottom_margin = 12
    create_button.enabled = not manager_data.new_surface_pressed

    -- delete current surface button
    local delete_button = left_frame.add{
        type = "button",
        name = names.prefix .. names.sm_delete_surface_btn,
        caption = {"gui-label.delete-selected-surface"},
        style = "red_button",
    }
    delete_button.style.horizontally_stretchable = true
    if manager_data.selected_vsurface then
        delete_button.enabled = true
    else
        delete_button.enabled = false
    end
end

-- Decides if new surface can be created
local function can_create_surface(player_index)
    local manager_data = storage.surface_manager[player_index]
    if not manager_data.new_surface_size then return false end
    if not manager_data.new_surface_type then return false end
    if not manager_data.new_surface_name then return false end
    -- also need to check if name is available
    local name = manager_data.new_surface_name
    if not backend.surface_name_available(name) then return false end
    return true
end

-- Decides if selected surface can be compiled
local function can_compile_surface(player_index)
    local manager_data = storage.surface_manager[player_index]
    -- cheking if template name available
    local template_name = manager_data.template_name
    if not utils.template_name_available(template_name) then return false end
    -- checking if surface is compiling
    local surface_name = manager_data.selected_vsurface
    if not surface_name then return false end
    local surface = game.get_surface(surface_name)
    if not surface then return false end
    local surface_data = storage.v_surfaces[surface.index]
    if not surface_data then return false end
    if surface_data.status ~= "designing" then return false end
    return true
end

-- changes text and color of given label to "name (not) available"
local function configure_name_available_label(label, is_available)
    if is_available then
        -- changing label to green "name available"
        label.caption = {"gui-label.name-available"}
        label.style.font_color = {r = 0.2, g = 0.8, b = 0.2}
    else
        -- changing label to red "name not available"
        label.caption = {"gui-label.name-not-available"}
        label.style.font_color = {r = 0.8, g = 0.2, b = 0.2}
    end
end

-- Builds gui that is used for creating a new surface
local function vsurface_creation_gui(player_index)
    local manager_data = storage.surface_manager[player_index]
    local right_frame = manager_data.right_frame
    -- caption above name textfield
    local name_label = right_frame.add{
        type = "label",
        name = names.prefix .. names.sm_new_surface_name_label,
        caption = {"gui-label.enter-surface-name"}
    }
    local surface_name = manager_data.new_surface_name
    if surface_name then
        local name_available = backend.surface_name_available(surface_name)
        configure_name_available_label(name_label, name_available)
    end

    -- textfield for new surface name
    local textfield = right_frame.add{
        type = "textfield",
        name = names.prefix .. names.sm_new_surface_name_textfield,
    }
    textfield.style.bottom_margin = 12
    textfield.text = surface_name or ""

    -- caption above type selection
    right_frame.add{
        type = "label",
        caption = {"gui-label.select-surface-type"},
    }

    -- surface type selection (production/science)
    local type_dropdown = right_frame.add{
        type = "drop-down",
        name = names.prefix .. names.sm_new_surface_type,
        items = {
            {"gui-label.production-type"},
            {"gui-label.science-type"},
        },
        selected_index = manager_data.new_surface_type
    }
    type_dropdown.style.bottom_margin = 12

    -- caption above size selection
    right_frame.add{
        type = "label",
        caption = {"gui-label.select-surface-size"},
    }

    -- surface size selection dropdown
    right_frame.add{
        type = "drop-down",
        name = names.prefix .. names.sm_new_surface_size,
        items = {
            "64 x 64",
            "128 x 128",
            "192 x 192",
            "256 x 256",
        },
        selected_index = manager_data.new_surface_size
    }

    -- template energy demand info textfield
    local size = (manager_data.new_surface_size or 0) * 64
    local drain = utils.template_area_to_power(size^2)
    local formated = utils.format_double(drain) .. "W"
    local drain_label = right_frame.add{
        type = "label",
        name = names.prefix .. names.sm_new_surface_drain,
        caption = {"", {"gui-label.template-energy-drain"}, ": ", formated},
    }
    drain_label.style.bottom_margin = 12

    -- spacer to put confirmation button at the bottom
    local spacer = right_frame.add{type = "flow"}
    spacer.style.vertically_stretchable = true

    -- needed to align confirmation button on the right
    local confirm_flow = right_frame.add{
        type = "flow",
        name = names.prefix .. names.sm_new_surface_confirm_flow,
        direction = "horizontal",
    }
    confirm_flow.style.horizontally_stretchable = true
    confirm_flow.style.horizontal_align = "right"

    local confirm_btn = confirm_flow.add{
        type = "button",
        name = names.prefix .. names.sm_new_surface_confirm_btn,
        caption = {"gui-label.confirm"},
        style = "confirm_button",
    }
    confirm_btn.tooltip = {"gui-label.confirm-tooltip"}
    local btn_state = can_create_surface(player_index)
    confirm_btn.enabled = btn_state
end

-- Builds gui that displays information about given vsurface
local function vsurface_info_gui(player_index)
    local manager_data = storage.surface_manager[player_index]
    local right_frame = manager_data.right_frame
    local surface_name = manager_data.selected_vsurface
    local surface = game.get_surface(surface_name)
    if not surface then return end
    local vsurface_data = storage.v_surfaces[surface.index]

    -- surface type info (production/science)
    local surface_type = vsurface_data.type
    if surface_type then
        local type_label = right_frame.add{
            type="label",
            style = "bold_label",
            caption = utils.vsurface_type_table[surface_type]
        }
        type_label.style.bottom_margin = 12
    end

    -- surface size and template power drain info
    local mapgen = surface.map_gen_settings
    local dimensions = tostring(mapgen.width) .. " x " .. tostring(mapgen.height)
    right_frame.add{
        type = "label",
        style = "bold_label",
        caption = {"", {"gui-label.dimensions"}, ": " .. dimensions}
    }
    local area = mapgen.width * mapgen.height
    local power_usage = utils.template_area_to_power(area)
    local formated = utils.format_double(power_usage) .. "W"
    local power_label = right_frame.add{
        type = "label",
        caption = {"", {"gui-label.template-energy-drain"}, ": ", formated},
    }
    power_label.style.bottom_margin = 12

    -- surface status (compiling/designing)
    local surface_status = vsurface_data.status
    local status_caption
    if surface_status == "compiling" then
        status_caption = {"gui-label.surface-compiling"}
    else
        status_caption = {"gui-label.surface-designing"}
    end
    local status_label = right_frame.add{
        type = "label",
        style = "bold_label",
        caption = status_caption,
    }
    status_label.style.bottom_margin = 12

    -- caption above template name textfield
    right_frame.add{
        type = "label",
        caption = {"gui-label.enter-template-name"},
    }

    -- textfield for template name
    local textfield = right_frame.add{
        type = "textfield",
        name = names.prefix .. names.sm_template_name_textfield,
    }
    local template_name = manager_data.template_name
    if template_name then
        textfield.text = template_name
    end

    -- status caption below template name template
    local label = right_frame.add{
        type = "label",
        name = names.prefix .. names.sm_template_name_label,
    }
    local name_available = utils.template_name_available(template_name)
    configure_name_available_label(label, name_available)

    -- spacer to put compilation button at the bottom
    local spacer = right_frame.add{type = "flow"}
    spacer.style.vertically_stretchable = true

    -- needed to align compilation button on the right
    local compile_flow = right_frame.add{
        type = "flow",
        name = names.prefix .. names.sm_start_compilation_flow,
        direction = "horizontal",
    }
    compile_flow.style.horizontally_stretchable = true
    compile_flow.style.horizontal_align = "right"

    local compile_btn = compile_flow.add{
        type = "button",
        name = names.prefix .. names.sm_start_compilation_btn,
        caption = {"gui-label.start-compilation"},
        style = "confirm_button",
    }
    compile_btn.tooltip = {"gui-label.compile-tooltip"}
    compile_btn.enabled = can_compile_surface(player_index)
end

-- Updates all gui elements in the right frame
local function update_right_frame(player_index)
    local manager_data = storage.surface_manager[player_index]
    local right_frame = manager_data.right_frame
    right_frame.clear()

    if manager_data.new_surface_pressed then
        vsurface_creation_gui(player_index)
    elseif manager_data.selected_vsurface then
        vsurface_info_gui(player_index)
    end
end

local function toggle_surface_manager(player)
    local manager_data = storage.surface_manager[player.index]
    -- closing the window if it was opened
    if manager_data and manager_data.opened then
        player.opened = nil
        return
    end

    surface_manager_base(player)
    update_left_frame(player.index)
    update_right_frame(player.index)
end

-- Handles "create new v-surface" button being pressed
-- Assuming that event routing was already done
-- Used when on_gui_click event is triggered
function Helper.process_new_surface_button(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.new_surface_pressed = true
    manager_data.left_search_query = nil
    manager_data.selected_vsurface = nil
    update_left_frame(event.player_index)
    update_right_frame(event.player_index)
end

-- Arranges v-surface selector in left frame according to search query
-- Assuming that event routing was already done
-- Used when on_gui_text_changed event is triggered
function Helper.process_left_searchfield(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.left_search_query = event.text
    -- only updating selector
    local selector = event.element.parent[names.prefix .. names.sm_left_selector]
    local options = backend.get_all_vsurfaces()
    local chosen_option = storage.surface_manager[event.player_index].selected_vsurface
    common.arrange_selector(selector, options, event.text, chosen_option)
end

-- Handles vsurface selector being changed
-- Assuming that event routing was already done
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_vsurface_selector(event)
    local element = event.element
    local manager_data = storage.surface_manager[event.player_index]
    local selected_name = element.items[element.selected_index]
    local current_name = manager_data.selected_vsurface
    -- if selected item is clicked again, we want to unselect it
    if selected_name == current_name then
        manager_data.selected_vsurface = nil
    else
        manager_data.selected_vsurface = selected_name
        manager_data.new_surface_pressed = nil
    end
    update_left_frame(event.player_index)
    update_right_frame(event.player_index)
end

-- Handles new surface name textfield being changed
-- Assuming that event routing was already done
-- Used when on_gui_text_changed event is triggered
function Helper.process_new_surface_name_changed(event)
    local manager_data = storage.surface_manager[event.player_index]
    local element = event.element
    manager_data.new_surface_name = element.text
    -- changing label above the textfield based on name availability
    local name_available = backend.surface_name_available(element.text)
    local label = element.parent[names.prefix .. names.sm_new_surface_name_label]
    configure_name_available_label(label, name_available)
    -- enabling confirm button if all fields are set
    local confirm_flow = element.parent[names.prefix .. names.sm_new_surface_confirm_flow]
    local confirm_btn = confirm_flow[names.prefix .. names.sm_new_surface_confirm_btn]
    confirm_btn.enabled = can_create_surface(event.player_index)
end

-- Handles new surface type dropdown being changed
-- Assuming that event routing was already done
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_new_surface_type(event)
    local manager_data = storage.surface_manager[event.player_index]
    local selected_type = event.element.selected_index
    manager_data.new_surface_type = selected_type
    update_right_frame(event.player_index)
end

-- Handles new surface size dropdown being changed
-- Assuming that event routing was already done
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_new_surface_size(event)
    local manager_data = storage.surface_manager[event.player_index]
    local element = event.element
    local selected_index = element.selected_index
    manager_data.new_surface_size = selected_index
    update_right_frame(event.player_index)
end

-- Handles confirm surface creation button being pressed 
-- Assuming that event routing was already done
-- Used when on_gui_click event is triggered
function Helper.process_creation_confirm(event)
    local manager_data = storage.surface_manager[event.player_index]

    -- surface creation parameters
    local surface_config = {
        name = manager_data.new_surface_name,
        size = manager_data.new_surface_size * 64,
        type = manager_data.new_surface_type,
    }

    -- last check for name availability
    if not backend.surface_name_available(surface_config.name) then return end

    -- cleaning up manager_data
    manager_data.new_surface_name = nil
    manager_data.new_surface_type = nil
    manager_data.new_surface_size = nil
    manager_data.new_surface_pressed = nil

    -- closing surface manager window
    local player = game.get_player(event.player_index)
    if not player then return end
    player.opened = nil

    -- creating surface and moving player's camera to it
    backend.create_v_surface(surface_config, player)
end

-- Handles template name textfield being changed
-- Assuming that event routing was already done
-- Used when on_gui_text_changed event is triggered
function Helper.process_template_name_textfield(event)
    local manager_data = storage.surface_manager[event.player_index]
    local element = event.element
    manager_data.template_name = event.text
    -- checking template name availability
    local name_available = utils.template_name_available(event.text)
    -- updating text label above based on status
    local label = element.parent[names.prefix .. names.sm_template_name_label]
    configure_name_available_label(label, name_available)
    -- enabling compilation button if name is available
    local compile_flow = element.parent[names.prefix .. names.sm_start_compilation_flow]
    local compile_btn = compile_flow[names.prefix .. names.sm_start_compilation_btn]
    compile_btn.enabled = can_compile_surface(event.player_index)
end

-- Handles compile button being pressed
-- Assuming that event routing was already done
-- Used when on_gui_click event is triggered
function Helper.process_compile_button(event)
    local manager_data = storage.surface_manager[event.player_index]
    local surface_name = manager_data.selected_vsurface
    if not surface_name then return end
    local surface = game.get_surface(surface_name)
    if not surface then return end

    -- starting compilation
    local result = compiler.start_compilation(surface.index, manager_data.template_name)

    -- cleaning up surface manager
    if result then
        manager_data.template_name = nil
        storage.v_surfaces[surface.index].status = "compiling"
    end

    update_left_frame(event.player_index)
    update_right_frame(event.player_index)
end


-- Closes the surface manager when player.opened changes.
-- Assuming that event routing was already done.
-- Used when on_gui_closed event is triggered
function Helper.process_surface_manager_gui_closed(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.opened = nil
    manager_data.main_window.destroy()
end

-- Toggles surface manager when shortcut bar element is clicked
-- Assuming that event routing was already done.
-- Used when on_lua_shortcut event is triggered
function Helper.process_surface_manager_shortcut(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_surface_manager(player)
end

-- Toggles surface manager when custom hotkey is pressed
script.on_event(names.prefix .. names.sm_hotkey, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_surface_manager(player)
end)

return Helper