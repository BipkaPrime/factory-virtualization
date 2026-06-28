-- V-surface manager is a gui window that allows players to manage virtualization
-- surfaces (create, destroy, start compilation, see information).

-- Main considerations to keep in mind when creating this gui.
-- 1. I want all data to persist if inteface is closed and then opened again.
--    To achieve this, we store all data related to interface state in storage.
-- 2. We have to update parts of the interface in responce to user inputs.
--    To do this conveniently, we store references to all objects that we want to update,
--    because it's much more convenient and robust then traversing gui by element names.
-- 3. We have to process user inputs. For that we give names to all elements that user
--    can interact with: main_window, textfields, dropdowns, etc.

--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = storage.surface_manager[playaer_index]. table keys:
-- elements.main_window LuaGuiElement: reference to main widow (to destroy it when needed)
-- elements.vsurface_selector LuaGuiElement: reference to selector element on the left side
-- elements.create_surface_btn LuaGuiElement: reference to "create new surface" button
-- elements.delete_surface_btn LuaGuiElement: reference to "delete selected surface" button
-- elements.right_frame LuaGuiElement: reference to frame on the right side of interface
-- elements.new_surface_name_status LuaGuiElement: reference to new surface name status label
-- elements.new_surface_drain LuaGuiElement: reference to new surface energy drain label
-- element.compile_btn LuaGuiElement: reference to compile button
-- elements.new_surface_confirm LuaGuiElement: reference to confirm create new surface btn
-- elements.template_name_status LuaGuiElement: reference to template name status label
-- opened bool: indicates if surface manager is currently opened
-- vsurface_search_query string: last user input into vsurface searchfield
-- selected_vsurface string: surface name selected in the selector
-- new_surface_pressed bool: indicates if "create new surface" button is pressed
-- new_surface_size int: chosen surface size dropdown index. (1 = 64 x 64; 2 = 128 x 128; etc)
-- new_surface_type int: chosen surface type dropdown index. (1 = "production", 2 = "science")
-- new_surface_name string: last user input into new surface name textfield
-- template_name string: last user input into template name textfield


local compiler = require("scripts.template-compiler")
local backend = require("scripts.surface-manager-backend")
local common = require("scripts.gui-v2.common")
local names = require("scripts.gui-v2.names")
local utils = require("scripts.utils")

local Helper = {}

-- Updates vsurface selector
local function update_vsurface_selector(player_index)
    local manager_data = storage.surface_manager[player_index]
    local selector = manager_data.elements.vsurface_selector
    local query = manager_data.vsurface_search_query
    local selected_vsurface = manager_data.selected_vsurface
    local options = backend.get_all_vsurfaces()
    common.arrange_selector(selector, options, query, selected_vsurface)
end

-- Updates new surface energy drain label
local function update_new_surface_drain(player_index)
    local manager_data = storage.surface_manager[player_index]
    local size = (manager_data.new_surface_size or 0) * 64
    local drain = utils.template_area_to_power(size^2)
    local formated = utils.format_double(drain) .. "W"
    local label = manager_data.elements.new_surface_drain
    label.caption = {"", {"gui-label.template-energy-drain"}, ": ", formated}
end

-- changes text and color of given label to "name (not) available"
local function update_name_status_label(label, is_available)
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

-- Updates confirm create new surface button
local function update_confirm_create_surface(player_index)
    local manager_data = storage.surface_manager[player_index]
    local confirm_btn = manager_data.elements.new_surface_confirm
    -- checking if size is selected
    if not manager_data.new_surface_size then
        confirm_btn.enabled = false
        return
    end
    -- cheking if type is selected
    if not manager_data.new_surface_type then
        confirm_btn.enabled = false
        return
    end
    -- cheking if name is selected and available
    local name = manager_data.new_surface_name
    if not name then
        confirm_btn.enabled = false
        return
    end
    -- checking if provided name is available
    if not backend.surface_name_available(name) then
        confirm_btn.enabled = false
        return
    end
    confirm_btn.enabled = true
end

-- Updates compile surface button
local function update_compile_button(player_index)
    local manager_data = storage.surface_manager[player_index]
    local compile_btn = manager_data.element.compile_btn
    -- cheking if template name available
    local template_name = manager_data.template_name
    if not backend.template_name_available(template_name) then
        compile_btn.enabled = false
        return
    end
    -- checking if surface is already compiling
    local surface_name = manager_data.selected_vsurface
    local surface = game.get_surface(surface_name)
    -- checking if surface is valid
    if not surface and surface.valid then
        compile_btn.enabled = false
        return
    end
    -- checking surface status
    local surface_data = storage.v_surfaces[surface.index]
    local status = surface_data.status
    if status == "compiling" then
        compile_btn.enabled = false
        return
    end
    compile_btn.enabled = true
end

-- Creates a surface manager base. It's assumed that surface manager is not opened when this is called.
local function surface_manager_base(player)
    -- creating base window and "opening" it
    local main_frame = common.gui_base_window(
        player,
        names.prefix .. names.sm_window,
        {"gui-title.surface-manager-window"}
    )
    player.opened = main_frame
    storage.surface_manager[player.index] = storage.surface_manager[player.index] or {}
    local manager_data = storage.surface_manager[player.index]
    manager_data.opened = true
    manager_data.elements = {}
    manager_data.elements.main_window = main_frame

    -- invisible container for other frames
    local main_content_frame = main_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    -- left frame of interface
    local left_frame = main_content_frame.add{
        type="frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
    }
    left_frame.style.right_margin = 12

    -- vsurface selector widget
    local searchfield, selector = common.selection_widget(
        manager_data.left_frame,
        names.prefix .. names.sm_vsurface_search,
        names.prefix .. names.sm_vsurface_selector,
        {"gui-label.v-surface-selection"}
    )
    manager_data.elements.vsurface_selector = selector
    -- arranging selector and searchfield based on saved state
    searchfield.text = manager_data.vsurface_search_query or ""
    update_vsurface_selector(player.index)

    -- create new surface button
    local create_button = left_frame.add{
        type = "button",
        name = names.prefix .. names.sm_new_surface_btn,
        caption = {"gui-label.create-new-v-surface"},
    }
    create_button.style.horizontally_stretchable = true
    create_button.style.bottom_margin = 12
    manager_data.elements.create_surface_btn = create_button
    create_button.enabled = not manager_data.new_surface_pressed

    -- delete current surface button
    local delete_button = left_frame.add{
        type = "button",
        name = names.prefix .. names.sm_delete_surface_btn,
        caption = {"gui-label.delete-selected-surface"},
        style = "red_button",
    }
    delete_button.style.horizontally_stretchable = true
    manager_data.elements.delete_surface_btn = delete_button
    -- disabling button if no surface is selected
    if not manager_data.selected_vsurface then
        delete_button.enabled = false
    end

    -- right half of interface
    local right_frame = main_content_frame.add{
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }
    right_frame.style.minimal_width = 350
    right_frame.style.vertically_stretchable = true
    manager_data.elements.right_frame = right_frame
end

-- Builds gui that is used for creating a new surface
local function vsurface_creation_gui(player_index)
    local manager_data = storage.surface_manager[player_index]
    local right_frame = manager_data.elements.right_frame

    -- caption above name textfield
    right_frame.add{
        type = "label",
        caption = {"gui-label.enter-surface-name"}
    }
    -- textfield for new surface name
    local textfield = right_frame.add{
        type = "textfield",
        name = names.prefix .. names.sm_new_surface_name,
    }
    textfield.text = manager_data.new_surface_name or ""
    -- status label below textfield indicating if name is available
    local status_label = right_frame.add{type = "textfield"}
    manager_data.elements.new_surface_name_status = status_label
    status_label.style.bottom_margin = 12
    local name_available = backend.surface_name_available(manager_data.new_surface_name)
    update_name_status_label(status_label, name_available)

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
    local drain_label = right_frame.add{type = "label"}
    manager_data.elements.new_surface_drain = drain_label
    update_new_surface_drain(player_index)
    drain_label.style.bottom_margin = 12

    -- spacer to put confirmation button at the bottom
    local spacer = right_frame.add{type = "flow"}
    spacer.style.vertically_stretchable = true
    -- needed to align confirmation button on the right
    local confirm_flow = right_frame.add{
        type = "flow",
        direction = "horizontal",
    }
    confirm_flow.style.horizontally_stretchable = true
    confirm_flow.style.horizontal_align = "right"

    local confirm_btn = confirm_flow.add{
        type = "button",
        name = names.prefix .. names.sm_new_surface_confirm,
        caption = {"gui-label.confirm"},
        style = "confirm_button",
    }
    manager_data.elements.new_surface_confirm = confirm_btn
    confirm_btn.tooltip = {"gui-label.confirm-tooltip"}
    update_confirm_create_surface(player_index)
end

-- maps vsurface types to their descriptions (1 = production, 2 = science).
local vsurface_type_description = {
    {"gui-label.production-type-detailed"},
    {"gui-label.science-type-detailed"},
}
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
            caption = vsurface_type_description[surface_type]
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
    -- power drain info label
    local power_usage = utils.template_area_to_power(mapgen.width * mapgen.height)
    local formated = utils.format_double(power_usage) .. "W"
    local power_label = right_frame.add{
        type = "label",
        caption = {"", {"gui-label.template-energy-drain"}, ": ", formated},
    }
    power_label.style.bottom_margin = 12

    -- REDO!! ()
    -- surface status (compiling/designing)
    local surface_status = vsurface_data.status
    local status_caption = {"gui-label.surface-designing"}
    if surface_status == "compiling" then
        status_caption = {"gui-label.surface-compiling"}
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
        name = names.prefix .. names.sm_template_name,
    }
    textfield.text = manager_data.template_name or ""
    -- status caption below template name template
    local label = right_frame.add{type = "label"}
    manager_data.elements.template_name_status = label
    local name_available = backend.template_name_available(manager_data.template_name)
    update_name_status_label(label, name_available)

    -- spacer to put compilation button at the bottom
    local spacer = right_frame.add{type = "flow"}
    spacer.style.vertically_stretchable = true
    -- needed to align compilation button on the right
    local compile_flow = right_frame.add{
        type = "flow",
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
    manager_data.element.compile_btn = compile_btn
    compile_btn.tooltip = {"gui-label.compile-tooltip"}
    update_compile_button(player_index)
end

-- Updates all gui elements in the right frame
local function update_right_frame(player_index)
    local manager_data = storage.surface_manager[player_index]
    local right_frame = manager_data.elements.right_frame
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
    update_right_frame(player.index)
end

-- Handles "create new v-surface" button being pressed
-- Assuming that event routing was already done
-- Used when on_gui_click event is triggered
function Helper.process_new_surface_button(event)
    local manager_data = storage.surface_manager[event.player_index]
    -- disabling the pressed button
    manager_data.new_surface_pressed = true
    event.element.enabled = false
    -- unselecting selected vsurface and rearranging selector
    manager_data.selected_vsurface = nil
    update_vsurface_selector(event.player_index)
    -- disabling delete button since there is no selected surface
    manager_data.elements.delete_surface_btn.enabled = false
    -- updating right frame
    update_right_frame(event.player_index)
end

-- Handles vsurface searchfield being changed
-- Assuming that event routing was already done
-- Used when on_gui_text_changed event is triggered
function Helper.process_vsurface_searchfield(event)
    local manager_data = storage.surface_manager[event.player_index]
    -- storing new query and updating selector
    manager_data.vsurface_search_query = event.text
    update_vsurface_selector(event.player_index)
end

-- Handles vsurface selector being changed
-- Assuming that event routing was already done
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_vsurface_selector(event)
    local element = event.element
    local manager_data = storage.surface_manager[event.player_index]
    local old_name = element.items[element.selected_index]
    local new_name = manager_data.selected_vsurface
    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        manager_data.selected_vsurface = nil
        -- in this case we want to update the selector
        update_vsurface_selector(event.player_index)
    else
        manager_data.selected_vsurface = new_name
    end
    -- if selector is changed, we want to enable "create new surface" button
    manager_data.new_surface_pressed = nil
    manager_data.elements.create_surface_btn.enabled = true
    -- updating right frame according to selection
    update_right_frame(event.player_index)
end

-- Handles new surface name textfield being changed
-- Assuming that event routing was already done
-- Used when on_gui_text_changed event is triggered
function Helper.process_new_surface_name_changed(event)
    local manager_data = storage.surface_manager[event.player_index]
    local element = event.element
    -- saving provided text to storage
    manager_data.new_surface_name = element.text
    -- changing label below the textfield based on name availability
    local name_available = backend.surface_name_available(element.text)
    local label = manager_data.elements.new_surface_name_status
    update_name_status_label(label, name_available)
    -- enabling confirm button if all fields are set
    update_confirm_create_surface(event.player_index)
end

-- Handles new surface type dropdown being changed
-- Assuming that event routing was already done
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_new_surface_type(event)
    local manager_data = storage.surface_manager[event.player_index]
    local selected_type = event.element.selected_index
    -- saving selection and updating confirm button
    manager_data.new_surface_type = selected_type
    update_confirm_create_surface(event.player_index)
end

-- Handles new surface size dropdown being changed
-- Assuming that event routing was already done
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_new_surface_size(event)
    local manager_data = storage.surface_manager[event.player_index]
    local selected_index = event.element.selected_index
    -- saving selection and updating energy drain info label
    manager_data.new_surface_size = selected_index
    update_new_surface_drain(event.player_index)
    update_confirm_create_surface(event.player_index)
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
    manager_data.template_name = event.text
    -- updating template name status label and compile button
    local name_available = backend.template_name_available(event.text)
    local label = manager_data.elements.template_name_status
    update_name_status_label(label, name_available)
    update_compile_button(event.player_index)
end

-- Handles compile button being pressed
-- Assuming that event routing was already done
-- Used when on_gui_click event is triggered
function Helper.process_compile_button(event)
    local manager_data = storage.surface_manager[event.player_index]
    local surface_name = manager_data.selected_vsurface
    local surface = game.get_surface(surface_name)
    -- checking surface validity
    if not surface and surface.valid then return end

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