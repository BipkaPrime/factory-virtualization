-- V-surface manager is a gui window that allows players to manage virtualization
-- surfaces (start compilation, destroy, create).

local gui_names = require("scripts.gui.gui-names")
local gui_common = require("scripts.gui.common-gui-elements")
local utils = require("scripts.gui.utils")
local backend = require("scripts.surface-manager-backend")

local Helper = {}

-- Opens/Closes surface manager for a given player
local function toggle_surface_manager(player)
    -- closing manager if it was opened
    if player.gui.screen[gui_names.prefix .. gui_names.sm_window] then
        player.opened = nil
        return
    end

    -- opening surface manager
    local main_frame = gui_common.gui_base_window(player, gui_names.prefix .. gui_names.sm_window)
    player.opened = main_frame
    storage.surface_manager[player.index] = {}

    -- invisible container for other frames
    local main_content_frame = main_frame.add{
        type="flow",
        name = gui_names.prefix .. gui_names.sm_main_flow,
        direction="horizontal",
    }

    -- left half of interface
    local left_content_frame = main_content_frame.add{
        type="frame",
        name = gui_names.prefix .. gui_names.sm_left_frame,
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    left_content_frame.style.right_margin = 12

    -- Existing surface selection element
    local selector_flow = gui_common.selection_widget(
        left_content_frame,
        gui_names.prefix .. gui_names.sm_selector_flow,
        gui_names.prefix .. gui_names.sm_selector_textfield,
        gui_names.prefix .. gui_names.sm_surface_selector,
        {"gui-label.v-surface-selection"}
    )
    selector_flow.style.bottom_margin = 12

    local button = left_content_frame.add{
        type = "button",
        name = gui_names.prefix .. gui_names.new_surface_button,
        caption = {"gui-label.create-new-v-surface"},
    }
    button.style.horizontally_stretchable = true

    -- arranging surface selector
    local selector = selector_flow[gui_names.prefix .. gui_names.sm_surface_selector]
    local options = backend.get_all_vsurfaces()
    gui_common.arrange_selector(selector, options, nil, nil)

    -- right half of interface
    local right_content_frame = main_content_frame.add{
        type = "frame",
        name = gui_names.prefix .. gui_names.sm_right_frame,
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }
    right_content_frame.style.minimal_width = 300
    right_content_frame.style.vertically_stretchable = true
end

-- Closes the surface manager when player.opened changes.
-- For instance if ESC/E are pressed or when another window is opened. 
-- Used when on_gui_closed event is triggered
function Helper.process_surface_manager_gui_closed(event)
    -- cheking if element is valid
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    local window_name = element.name
    if window_name ~= gui_names.prefix .. gui_names.sm_window then return end

    -- getting the player object
    local player = game.get_player(event.player_index)
    if not player then return end

    -- closing surface manager for given player
    storage.surface_manager[event.player_index] = nil
    local manager_window = player.gui.screen[gui_names.prefix .. gui_names.sm_window]
    if manager_window  then
        manager_window .destroy()
    end
end

-- Toggles surface manager when shortcut bar element is clicked
local manager_shortcut = gui_names.prefix .. gui_names.surface_manager
function Helper.process_surface_manager_shortcut(event)
    if event.prototype_name == manager_shortcut then
        local player = game.get_player(event.player_index)
        if not player then return end
        toggle_surface_manager(player)
    end
end

-- Toggles surface manager when custom hotkey is pressed
function Helper.process_surface_manager_hotkey(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_surface_manager(player)
end

-- Builds gui that displays information about given vsurface
local function vsurface_info_gui(gui_element, surface_name)
    gui_element.clear()

    -- debug placeholder
    gui_element.add{
        type = "label",
        caption = "surface_name:" .. surface_name,
    }
end

-- Handles vsurface selector being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_vsurface_selector(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    if element.name ~= gui_names.prefix .. gui_names.sm_surface_selector then return end

    -- saving selected option
    local surface_name = element.items[element.selected_index]
    storage.surface_manager[event.player_index].selected_vsurface = surface_name

    -- building information panel on the right side
    local right_frame = element.parent.parent.parent[gui_names.prefix .. gui_names.sm_right_frame]
    vsurface_info_gui(right_frame, surface_name)
end

-- Arranges v-surface selector according to search query
-- Used when on_gui_text_changed event is triggered
function Helper.process_left_searchfield(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    if element.name ~= gui_names.prefix .. gui_names.sm_selector_textfield then return end

    -- arranging selector
    local selector = element.parent[gui_names.prefix .. gui_names.sm_surface_selector]
    local options = backend.get_all_vsurfaces()
    local query = event.text
    local chosen_option = storage.surface_manager[event.player_index].selected_vsurface
    gui_common.arrange_selector(selector, options, query, chosen_option)
end


-- Builds gui that is used for creating a new surface
local function vsurface_creation_gui(gui_element)
    gui_element.clear()

    -- caption above name textfield
    gui_element.add{
        type = "label",
        name = gui_names.prefix .. gui_names.sm_new_surface_label,
        caption = {"gui-label.enter-surface-name"}
    }

    -- textfield for new surface name
    local textfield = gui_element.add{
        type = "textfield",
        name = gui_names.prefix .. gui_names.sm_new_surface_textfield,
    }
    textfield.style.bottom_margin = 12

    -- caption above type selection
    gui_element.add{
        type = "label",
        caption = {"gui-label.select-surface-type"},
    }

    -- surface type selection (production/science)
    local type_dropdown = gui_element.add{
        type = "drop-down",
        name = gui_names.prefix .. gui_names.sm_type_dropdown,
        items = {
            {"gui-label.production-type"},
            {"gui-label.science-type"},
        },
    }
    type_dropdown.style.bottom_margin = 12

    -- caption above size selection
    gui_element.add{
        type = "label",
        caption = {"gui-label.select-surface-size"},
    }

    -- surface size selection dropdown
    gui_element.add{
        type = "drop-down",
        name = gui_names.prefix .. gui_names.sm_size_dropdown,
        items = {
            "64 x 64",
            "128 x 128",
            "192 x 192",
            "256 x 256",
        },
    }

    -- template energy demand info textfield
    local drain_label = gui_element.add{
        type = "label",
        name = gui_names.prefix .. gui_names.sm_energy_drain,
        caption = {"", {"gui-label.template-energy-drain"}, ": 0 W"},
    }
    drain_label.style.bottom_margin = 12

    -- spacer to put confirmation button at the bottom
    local spacer = gui_element.add{type = "flow"}
    spacer.style.vertically_stretchable = true

    -- needed to align confirmation button on the right
    local confirm_flow = gui_element.add{
        type = "flow",
        name = gui_names.prefix .. gui_names.sm_confirmation_flow,
        direction = "horizontal",
    }
    confirm_flow.style.horizontally_stretchable = true
    confirm_flow.style.horizontal_align = "right"
    
    local confirm_btn = confirm_flow.add{
        type = "button",
        name = gui_names.prefix .. gui_names.sm_confirm_create,
        caption = {"gui-label.confirm"},
        style = "confirm_button",
    }
    confirm_btn.enabled = false
end

-- Handles "create new v-surface" button being pressed
-- Used when on_gui_click event is triggered
function Helper.process_new_surface_button(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    if element.name ~= gui_names.prefix .. gui_names.new_surface_button then return end

    -- getting the player object
    local player = game.get_player(event.player_index)
    if not player then return end

    -- getting to right content frame
    local sm_window = player.gui.screen[gui_names.prefix .. gui_names.sm_window]
    local sm_flow = sm_window[gui_names.prefix .. gui_names.sm_main_flow]
    local right_frame = sm_flow[gui_names.prefix .. gui_names.sm_right_frame]
    vsurface_creation_gui(right_frame)

    -- creating a checklist for all fields that need to be specified
    storage.surface_manager[event.player_index].ns_config = {
        name = false,
        type = false,
        size = false,
    }

    -- disabling the button so it can't be clicked again
    element.enabled = false
end

-- configures confirm button state based on entered fields
local function confirm_button_state(right_frame, player_index)
    -- enabling confirmation button if all fields are filled
    local button_flow = right_frame[gui_names.prefix .. gui_names.sm_confirmation_flow]
    local button = button_flow[gui_names.prefix .. gui_names.sm_confirm_create]
    local state = utils.all_true(storage.surface_manager[player_index].ns_config)
    button.enabled = state
end

-- Handles new surface name textfield being changed
-- Used when on_gui_text_changed event is triggered
function Helper.process_new_surface_name(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    if element.name ~= gui_names.prefix .. gui_names.sm_new_surface_textfield then return end

    -- checking name availability
    local name_available = backend.surface_name_available(element.text)
    local label = element.parent[gui_names.prefix .. gui_names.sm_new_surface_label]
    if name_available then
        -- changing label to green "name available"
        label.caption = {"gui-label.name-available"}
        label.style.font_color = {r = 0.2, g = 0.8, b = 0.2}
        -- saving name in new surface checklist thus marking it ckecked
        storage.surface_manager[event.player_index].ns_config.name = event.text
    else
        -- changing label to red "name not available"
        label.caption = {"gui-label.name-not-available"}
        label.style.font_color = {r = 0.8, g = 0.2, b = 0.2}
        -- marking name unchecked from checklist
        storage.surface_manager[event.player_index].ns_config.name = false
    end
    confirm_button_state(element.parent, event.player_index)
end

-- Handles new surface type dropdown being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_new_surface_type(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    if element.name ~= gui_names.prefix .. gui_names.sm_type_dropdown then return end

    -- saving selected choice
    local selected_type = element.selected_index
    if selected_type ~= 0 then
        storage.surface_manager[event.player_index].ns_config.type = selected_type
    end
    confirm_button_state(element.parent, event.player_index)
end

-- Handles new surface size dropdown being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_new_surface_size(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    if element.name ~= gui_names.prefix .. gui_names.sm_size_dropdown then return end

    local selected_idx = element.selected_index
    if selected_idx ~= 0 then
        -- saving selected choice
        local selected_size = tonumber(element.items[selected_idx]:match("%d+"))
        storage.surface_manager[event.player_index].ns_config.size = selected_size
        -- updating energy drain displayed below
        local label = element.parent[gui_names.prefix .. gui_names.sm_energy_drain]
        local area = selected_size^2
        local power_usage = utils.template_area_to_power(area)
        local formated = utils.format_double(power_usage) .. "W"
        label.caption = {"", {"gui-label.template-energy-drain"}, ": ", formated}
    end
    confirm_button_state(element.parent, event.player_index)
end

-- Handles confirm surface creation button being pressed 
-- Used when on_gui_click event is triggered
function Helper.process_creation_confirm(event)
    -- checking element validity
    local element = event.element
    if not element or not element.valid then return end

    -- cheking element name
    if element.name ~= gui_names.prefix .. gui_names.sm_confirm_create then return end

    -- surface creation parameters
    local surface_config = storage.surface_manager[event.player_index].ns_config

    -- last check for name availability
    if not backend.surface_name_available(surface_config.name) then return end

    -- closing surface manager window
    local player = game.get_player(event.player_index)
    if player then player.opened = nil end
    
    -- creating surface and moving player's camera to it
    backend.create_v_surface(surface_config, game.get_player(event.player_index))
end


return Helper