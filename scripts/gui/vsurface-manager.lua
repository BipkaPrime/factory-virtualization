-- V-surface manager is a gui window that allows players to manage virtualization
-- surfaces (create, destroy, start compilation, see information).

-- Main considerations to keep in mind when creating this gui.
-- 1. I want all data to persist if interface is closed and then opened again.
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
-- elements.new_surface_drain LuaGuiElement: reference to new surface energy drain label
-- element.compile_btn LuaGuiElement: reference to compile button
-- elements.compile_btn_status LuaGuiElement: reference to status label above compile button
-- elements.new_surface_confirm LuaGuiElement: reference to confirm create new surface btn
-- elements.new_surface_confirm_status LuaGuiElement: reference to status label above confirm create btn
-- elements.compile_bar_label LuaGuiElement: reference to label above compilation progressbar
-- elements.compile_progressbar LuaGuiElement: reference to progressbar indicating surface compilation progress
-- elements.template_name_textfield LuaGuiElement: reference to template name textfield element
-- elements.template_name_label LuaGuiElement: refenrence label above template name textfield
-- opened bool: indicates if surface manager is currently opened
-- vsurface_search_query string: last user input into vsurface searchfield
-- selected_vsurface string: surface name selected in the selector
-- new_surface_pressed bool: indicates if "create new surface" button is pressed
-- new_surface_size int: chosen surface size dropdown index. (1 = 64 x 64; 2 = 128 x 128; etc)
-- new_surface_type int: chosen surface type dropdown index. (1 = "production", 2 = "science")
-- new_surface_name string: last user input into new surface name textfield
-- template_name string: last user input into template name textfield

local chunk_processor = require("scripts.template-creation.chunk-processor")
local venv_processor = require("scripts.template-creation.venv-processor")
local common = require("scripts.gui.common")
local misc = require("scripts.misc")

local Helper = {}

-------------------------------------------------------------------------------
-- VSURFACE CREATION/DELETION/LOOKUP
-------------------------------------------------------------------------------

-- Checks if a vsurface with given properties can be created, also trims surface name
-- @returns bool: true if surface can be created
-- @return string/nil: reason why surface cannot be created if any
local function can_create_vsurface(properties)
    -- checking that name is not empty
    if not properties.name or properties.name == "" then
        return false, "Surface name is missing"
    end
    -- trimming the name and checking if it's not empty
    properties.name = properties.name:match("^%s*(.-)%s*$")
    if properties.name == "" then
        return false, "Surface name is missing"
    end
    -- checking if surface with given name already exists
    if game.get_surface(properties.name) ~= nil then
        return false, "Surface with provided name already exists"
    end
    -- checking if planet with provided name exists
    if game.planets[properties.name] ~= nil then
        return false, "Surface name not available"
    end
    -- checking if surface size is provided
    if not properties.size then
        return false, "Surface size not specified"
    end
    -- checking if surface type is provided
    if not properties.type then
        return false, "Surface type not specified"
    end
    return true
end

-- Creates a new square virtualization surface
-- @param properties table: contains all data required for surface creation
-- @returns bool: true if surface was created
-- @returns string/nil: reason why surface was not created if any
local function create_vsurface(properties, player)
    -- checking that surface can be created
    local status, reason = can_create_vsurface(properties)
    if not status then return status, reason end

    -- creating surface with specified properties
    local surface = game.create_surface(properties.name, {
        width = properties.size,
        height = properties.size,
        starting_area = 0
    })
    if not surface then
        return false, "Could not create surface"
    end

    -- Modifying surface attributes
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.show_clouds = false

    local chunk_radius = math.ceil(properties.size / 64)
    surface.request_to_generate_chunks({0, 0}, chunk_radius)
    surface.force_generate_chunk_requests()
    game.forces["player"].chart_all(surface)

    -- adding created surface table with vsurfaces
    storage.v_surfaces[surface.index] = {
        research_surface = (properties.type == 2),
        width = properties.size,
        height = properties.size,
    }
    -- adding surface to chunk registry
    chunk_processor.register_surface(surface.index)
    -- move player's camera to created surface
    if player and player.valid then
        player.set_controller{
            type = defines.controllers.remote,
            surface = surface,
            position = {0, 0}
        }
    end
    return true
end

-- Fetches data about vsurface from storage
local function get_vsurface_data(surface_name)
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then return end
    local vsurface_data = storage.v_surfaces[surface.index]
    return vsurface_data
end

-- collects names of all existing vsurfaces
-- @returns table[string]: collected names
local function get_all_vsurfaces()
    local result = {}
    for surface_index, _ in pairs(storage.v_surfaces) do
        local surface = game.get_surface(surface_index)
        if surface and surface.valid then
            table.insert(result, surface.name)
        end
    end
    return result
end

-- Deletes vsurface provided it's name
local function delete_vsurface(surface_name)
    local surface = game.get_surface(surface_name)
    if not surface or not surface.valid then return end
    -- checking if provided surface is a vsurface
    local vsurface_data = storage.v_surfaces[surface.index]
    if not vsurface_data then return end
    local status = game.delete_surface(surface.index)
    if status then storage.v_surfaces[surface.index] = nil end
end

-- Erasing surface data from storage.vsurfaces when surface is deleted
script.on_event(defines.events.on_surface_deleted, function(event)
    storage.v_surfaces[event.surface_index] = nil
end)

-------------------------------------------------------------------------------
-- MANAGER CONTROL ELEMENTS UPDATERS
-------------------------------------------------------------------------------

-- Updates vsurface selector located on the left side of interface
local function update_vsurface_selector(manager_data)
    local selector = manager_data.elements.vsurface_selector
    if not selector or not selector.valid then return end
    local query = manager_data.vsurface_search_query
    local selected_vsurface = manager_data.selected_vsurface
    local options = get_all_vsurfaces()
    common.arrange_selector(selector, options, query, selected_vsurface)
end

-- Updates "create new surface" button on the left side of interface
local function update_create_new_surface_btn(manager_data)
    local button = manager_data.elements.create_surface_btn
    if not button or not button.valid then return end
    if manager_data.new_surface_pressed then
        button.enabled = false
    else
        button.enabled = true
    end
end

-- Updates "delete selected surface" button on the left side of interface
local function update_delete_surface_btn(manager_data)
    local button = manager_data.elements.delete_surface_btn
    if not button or not button.valid then return end
    if manager_data.selected_vsurface then
        button.enabled = true
    else
        button.enabled = false
    end
end

-- Updates new surface energy drain label
local function update_new_surface_drain(manager_data)
    local label = manager_data.elements.new_surface_drain
    if not label or not label.valid then return end
    local size = (manager_data.new_surface_size or 0) * 64
    local drain = misc.template_area_to_power(size^2)
    local formated = misc.format_double(drain) .. "W"
    label.caption = {"", {"gui-label.template-energy-drain"}, ": ", formated}
end

-- Creates a table with surface properties
local function assemble_new_surface_properties(manager_data)
    local properties = {
        name = manager_data.new_surface_name,
        size = nil,
        type = manager_data.new_surface_type,
    }
    local surface_size = manager_data.new_surface_size
    if surface_size and surface_size > 0 then
        properties.size = surface_size * 64
    end
    return properties
end

-- Updates confirm create new surface button and its status label above
local function update_confirm_create_surface(manager_data)
    local button = manager_data.elements.new_surface_confirm
    local label = manager_data.elements.new_surface_confirm_status
    if not button or not button.valid or not label or not label.valid then return end
    local properties = assemble_new_surface_properties(manager_data)
    -- sending request to backend to decide if surface can be created
    local can_create, code = can_create_vsurface(properties)
    if can_create then
        button.enabled = true
        label.caption = ""
    else
        button.enabled = false
        label.caption = code
        label.style.font_color = {r = 0.8, g = 0.2, b = 0.2}
    end
end

-- Updates compile surface button and its status label above
local function update_compile_button(manager_data)
    local button = manager_data.elements.compile_btn
    local label = manager_data.elements.compile_btn_status
    if not button or not button.valid or not label or not label.valid then return end
    local surface_name = manager_data.selected_vsurface
    local template_name = manager_data.template_name
    -- sending request to compiler to decide if compilation can be started
    local can_compile, code = venv_processor.can_start_compilation(surface_name, template_name)
    if can_compile then
        button.enabled = true
        label.caption = ""
    else
        button.enabled = false
        label.caption = code
        label.style.font_color = {r = 0.8, g = 0.2, b = 0.2}
    end
end

-- Updates compilation progressbar and caption above
local function update_compile_progressbar(manager_data)
    local bar = manager_data.elements.compile_progressbar
    local label = manager_data.elements.compile_bar_label
    if not bar or not bar.valid or not label or not label.valid then return end
    local selected_surface = manager_data.selected_vsurface
    local elapsed, remaining = venv_processor.get_compilation_progress(selected_surface)

    if elapsed then -- compilation in progress
        bar.value = elapsed/(elapsed + remaining)
        bar.visible = true
        label.visible = true
    else -- compilation is not in progress
        bar.visible = false
        label.visible = false
    end
end

-- Updates template name textfield and label above
local function update_template_name_textfield(manager_data)
    local textfield = manager_data.elements.template_name_textfield
    local label = manager_data.elements.template_name_label
    if not textfield or not textfield.valid or not label or not label.valid then return end
    local selected_surface = manager_data.selected_vsurface
    local compiling = venv_processor.get_compilation_progress(selected_surface)
    if compiling then
        textfield.enabled = false
        label.enabled = false
        textfield.text = ""
    else
        textfield.enabled = true
        label.enabled = true
    end
end

-- Creates a surface manager base. It's assumed that surface manager is not opened when this is called.
local function surface_manager_base(player)
    -- creating base window and "opening" it
    local main_frame = common.gui_base_window(
        player,
        PREFIX .. "sm-window",
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
        left_frame,
        PREFIX .. "sm-vsurface-search",
        PREFIX .. "sm-vsurface-selector",
        {"gui-label.v-surface-selection"}
    )
    manager_data.elements.vsurface_selector = selector
    -- arranging selector and searchfield based on saved state
    searchfield.text = manager_data.vsurface_search_query or ""
    update_vsurface_selector(manager_data)

    -- create new surface button
    local create_button = left_frame.add{
        type = "button",
        name = PREFIX .. "sm-new-surface-btn",
        caption = {"gui-label.create-new-v-surface"},
    }
    create_button.style.horizontally_stretchable = true
    create_button.style.bottom_margin = 12
    manager_data.elements.create_surface_btn = create_button
    update_create_new_surface_btn(manager_data)

    -- delete current surface button
    local delete_button = left_frame.add{
        type = "button",
        name = PREFIX .. "sm-delete-surface-btn",
        caption = {"gui-label.delete-selected-surface"},
        style = "red_button",
    }
    delete_button.style.horizontally_stretchable = true
    manager_data.elements.delete_surface_btn = delete_button
    update_delete_surface_btn(manager_data)

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
local function vsurface_creation_gui(manager_data)
    local right_frame = manager_data.elements.right_frame

    -- caption above name textfield
    right_frame.add{
        type = "label",
        caption = {"gui-label.enter-surface-name"}
    }
    -- textfield for new surface name
    local textfield = right_frame.add{
        type = "textfield",
        name = PREFIX .. "sm-new-surface-name",
    }
    textfield.text = manager_data.new_surface_name or ""
    textfield.style.bottom_margin = 12

    -- caption above type selection
    right_frame.add{
        type = "label",
        caption = {"gui-label.select-surface-type"},
    }
    -- surface type selection (production/science)
    local type_dropdown = right_frame.add{
        type = "drop-down",
        name = PREFIX .. "sm-new-surface-type",
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
        name = PREFIX .. "sm-new-surface-size",
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
    update_new_surface_drain(manager_data)
    drain_label.style.bottom_margin = 12

    -- spacer to put confirmation button at the bottom
    local v_spacer = right_frame.add{type = "flow"}
    v_spacer.style.vertically_stretchable = true
    -- needed to align confirmation flow on the right
    local confirm_flow = right_frame.add{
        type = "flow",
        direction = "vertical",
    }
    confirm_flow.style.horizontally_stretchable = true
    confirm_flow.style.horizontal_align = "right"

    local confirm_label = confirm_flow.add{type = "label"}
    local confirm_btn = confirm_flow.add{
        type = "button",
        name = PREFIX .. "sm-new-surface-confirm",
        caption = {"gui-label.confirm"},
        style = "confirm_button",
    }
    confirm_btn.tooltip = {"gui-label.confirm-tooltip"}
    manager_data.elements.new_surface_confirm_status = confirm_label
    manager_data.elements.new_surface_confirm = confirm_btn
    update_confirm_create_surface(manager_data)
end

-- maps vsurface types to their descriptions (1 = production, 2 = science).
local vsurface_type_description = {
    {"gui-label.production-type-detailed"},
    {"gui-label.science-type-detailed"},
}
-- Builds gui that displays information about given vsurface
local function vsurface_info_gui(manager_data)
    local right_frame = manager_data.elements.right_frame
    local surface_name = manager_data.selected_vsurface
    local vsurface_data = get_vsurface_data(surface_name)
    if not vsurface_data then return end

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
    local width = vsurface_data.width
    local height = vsurface_data.height
    local dimensions = tostring(width) .. " x " .. tostring(height)
    right_frame.add{
        type = "label",
        style = "bold_label",
        caption = {"", {"gui-label.dimensions"}, ": " .. dimensions}
    }
    -- power drain info label
    local power_usage = misc.template_area_to_power(width * height)
    local formated = misc.format_double(power_usage) .. "W"
    local power_label = right_frame.add{
        type = "label",
        caption = {"", {"gui-label.template-energy-drain"}, ": ", formated},
    }
    power_label.style.bottom_margin = 12

    -- caption above template name textfield
    local label = right_frame.add{
        type = "label",
        caption = {"gui-label.enter-template-name"},
    }
    -- textfield for template name
    local textfield = right_frame.add{
        type = "textfield",
        name = PREFIX .. "sm-template-name",
    }
    manager_data.elements.template_name_textfield = textfield
    manager_data.elements.template_name_label = label
    textfield.text = manager_data.template_name or ""
    update_template_name_textfield(manager_data)
    textfield.style.bottom_margin = 12

    -- compilation progress
    local label = right_frame.add{
        type = "label",
        caption = "Compilation in progress"
    }
    local bar = right_frame.add{type = "progressbar"}
    bar.style.bar_width = 12
    manager_data.elements.compile_bar_label = label
    manager_data.elements.compile_progressbar = bar
    update_compile_progressbar(manager_data)

    -- spacer to put compilation button at the bottom
    local spacer = right_frame.add{type = "flow"}
    spacer.style.vertically_stretchable = true
    -- needed to align compilation button on the right
    local compile_flow = right_frame.add{
        type = "flow",
        direction = "vertical",
    }
    compile_flow.style.horizontally_stretchable = true
    compile_flow.style.horizontal_align = "right"
    local status_label = compile_flow.add{type = "label"}
    local compile_btn = compile_flow.add{
        type = "button",
        name = PREFIX .. "sm-start-compilation-btn",
        caption = {"gui-label.start-compilation"},
        style = "confirm_button",
    }
    compile_btn.tooltip = {"gui-label.compile-tooltip"}
    manager_data.elements.compile_btn = compile_btn
    manager_data.elements.compile_btn_status = status_label
    update_compile_button(manager_data)
end

-- Updates all gui elements in the right frame
local function update_right_frame(manager_data)
    local right_frame = manager_data.elements.right_frame
    right_frame.clear()

    if manager_data.new_surface_pressed then
        vsurface_creation_gui(manager_data)
    elseif manager_data.selected_vsurface then
        vsurface_info_gui(manager_data)
    end
end

-- Opens surface manager for a given player or closes if already opened
local function toggle_surface_manager(player)
    local manager_data = storage.surface_manager[player.index]
    -- closing the window if it was opened
    if manager_data and manager_data.opened then
        player.opened = nil
        return
    end

    surface_manager_base(player)
    update_right_frame(storage.surface_manager[player.index])
end

-- Handles "create new v-surface" button being pressed
-- Used when on_gui_click event is triggered
function Helper.process_new_surface_button(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.new_surface_pressed = true
    manager_data.selected_vsurface = nil
    update_create_new_surface_btn(manager_data)
    update_delete_surface_btn(manager_data)
    update_vsurface_selector(manager_data)
    update_right_frame(manager_data)
end

-- Handles "delete selected surface" button being pressed
-- Used when on_gui_click event is triggered
function Helper.process_delete_surface_button(event)
    local manager_data = storage.surface_manager[event.player_index]
    local surface_name = manager_data.selected_vsurface
    delete_vsurface(surface_name)
    manager_data.selected_vsurface = nil
    update_delete_surface_btn(manager_data)
    update_vsurface_selector(manager_data)
    update_right_frame(manager_data)
end

-- Handles vsurface searchfield being changed
-- Used when on_gui_text_changed event is triggered
function Helper.process_vsurface_searchfield(event)
    local manager_data = storage.surface_manager[event.player_index]
    -- storing new query and updating selector
    manager_data.vsurface_search_query = event.text
    update_vsurface_selector(manager_data)
end

-- Handles vsurface selector being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_vsurface_selector(event)
    local manager_data = storage.surface_manager[event.player_index]
    local element = event.element
    local old_name = manager_data.selected_vsurface
    local new_name = element.items[element.selected_index]
    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        manager_data.selected_vsurface = nil
        -- in this case we want to update the selector
        update_vsurface_selector(manager_data)
    else
        manager_data.selected_vsurface = new_name
    end
    manager_data.new_surface_pressed = nil
    update_create_new_surface_btn(manager_data)
    update_delete_surface_btn(manager_data)
    update_right_frame(manager_data)
end

-- Handles new surface name textfield being changed
-- Used when on_gui_text_changed event is triggered
function Helper.process_new_surface_name_changed(event)
    local manager_data = storage.surface_manager[event.player_index]
    local element = event.element
    -- saving provided name and updating confirm create button
    manager_data.new_surface_name = element.text
    update_confirm_create_surface(manager_data)
end

-- Handles new surface type dropdown being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_new_surface_type(event)
    local manager_data = storage.surface_manager[event.player_index]
    local selected_type = event.element.selected_index
    -- saving selection and updating confirm button
    manager_data.new_surface_type = selected_type
    update_confirm_create_surface(manager_data)
end

-- Handles new surface size dropdown being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_new_surface_size(event)
    local manager_data = storage.surface_manager[event.player_index]
    local selected_index = event.element.selected_index
    -- saving selection and updating energy drain info label
    manager_data.new_surface_size = selected_index
    update_new_surface_drain(manager_data)
    update_confirm_create_surface(manager_data)
end

-- Handles confirm surface creation button being pressed
-- Used when on_gui_click event is triggered
function Helper.process_creation_confirm(event)
    local manager_data = storage.surface_manager[event.player_index]
    local surface_properties = assemble_new_surface_properties(manager_data)

    -- cleaning up manager_data
    manager_data.new_surface_name = nil
    manager_data.new_surface_type = nil
    manager_data.new_surface_size = nil
    manager_data.new_surface_pressed = nil

    -- closing window because it closes anyway when creating
    -- vsurface from nauvis
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = nil

    -- creating surface and moving player's camera to it
    create_vsurface(surface_properties, player)
end

-- Handles template name textfield being changed
-- Used when on_gui_text_changed event is triggered
function Helper.process_template_name_textfield(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.template_name = event.text
    update_compile_button(manager_data)
end

-- Handles compile button being pressed
-- Used when on_gui_click event is triggered
function Helper.process_compile_button(event)
    local manager_data = storage.surface_manager[event.player_index]
    local surface_name = manager_data.selected_vsurface
    local template_name = manager_data.template_name
    -- starting the compilation
    venv_processor.start_compilation(surface_name, template_name)
    manager_data.template_name = nil
    update_right_frame(manager_data)
end

-- Time-based vsurface manager updater
function Helper.update_opened_managers()
    for _, manager_data in pairs(storage.surface_manager) do
        -- updating info panel if surface is selected
        if manager_data.opened and manager_data.selected_vsurface then
            update_compile_button(manager_data)
            update_compile_progressbar(manager_data)
            update_template_name_textfield(manager_data)
        end
    end
end

-- Closes the surface manager when player.opened changes.
-- Used when on_gui_closed event is triggered
function Helper.process_surface_manager_gui_closed(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.opened = nil
    manager_data.elements.main_window.destroy()
end

-- Toggles surface manager when shortcut bar element is clicked
-- Used when on_lua_shortcut event is triggered
function Helper.process_surface_manager_shortcut(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_surface_manager(player)
end

-- Toggles surface manager when custom hotkey is pressed
script.on_event(PREFIX .. "sm-hotkey", function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_surface_manager(player)
end)

-- After player changes surface with vsurface manager opened
-- player.opened can be assigned nil with window still opened
-- So if window should be opened, we set player.opened to it.
function Helper.process_player_changed_surface(event)
    local manager_data = storage.surface_manager[event.player_index]
    if not manager_data or not manager_data.opened then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = manager_data.elements.main_window
end

return Helper