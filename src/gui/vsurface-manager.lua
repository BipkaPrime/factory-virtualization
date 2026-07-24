--[[
Vsurface manager is a gui window that allows players to create and destroy vsurfaces.
As well as see vsurface info and start/stop compilation of any vsurface.

We want to store a bunch of data regarding this window in storage for 2 reasons.
First one is QoL of user, we want window state to persist through close-open cycle.
That's why we will be storing all user inputs in storage.
Second on is QoL of developer. We want to store references to all created gui elements
that we will be modifying in some way. This is much more convenient than traversing gui
tree by element names. Vsurface manager data for all players is located at storage.surface_manager.
For this table key is player index, value is table containing manager data.
--]]

---Table with references to surface manager gui elements
---@class SurfaceManagerElements: GuiElementsBase
---@field right_frame LuaGuiElement
---@field vsurface_selector LuaGuiElement reference to selector element on the left side
---@field vsurface_search LuaGuiElement reference to textfield above vsurface selector
---@field create_surface_btn LuaGuiElement reference to "create new surface" button
---@field delete_surface_btn LuaGuiElement reference to "delete selected surface" button
---@field new_surface_name_textfield LuaGuiElement|nil reference to new surface name textfield
---@field new_surface_confirm LuaGuiElement|nil reference to confirm create new surface btn
---@field new_surface_confirm_status LuaGuiElement|nil reference to status label above confirm create btn
---@field new_surface_width LuaGuiElement|nil reference to new surface width textfield
---@field new_surface_height LuaGuiElement|nil reference to new surface height textfield
---@field new_surface_drain LuaGuiElement|nil reference to new surface energy drain label
---@field planet_selector LuaGuiElement|nil reference to "generate as" planet selector
---@field template_name_textfield LuaGuiElement|nil reference to template name textfield element
---@field template_name_label LuaGuiElement|nil refenrence label above template name textfield
---@field compile_progressbar LuaGuiElement|nil reference to progressbar indicating surface compilation progress
---@field compile_bar_label LuaGuiElement|nil reference to label above compilation progressbar
---@field compile_btn LuaGuiElement|nil reference to compile button
---@field compile_btn_status LuaGuiElement|nil reference to status label above compile button

---Table with vsurface manager gui data
---@class SurfaceManagerData: GuiDataBase
---@field vsurface_search_query string|nil last user input into vsurface searchfield
---@field selected_vsurface string|nil surface name selected in the selector
---@field new_surface_pressed boolean|nil true if "vsurface creation interface" is opened
---@field new_surface_name string|nil last user input into new surface name textfield
---@field new_surface_width number|nil last user input into new surface width field
---@field new_surface_height number|nil last user input into new surface height field
---@field selected_planet string|nil planet selector chosen option in new surface interface 
---@field template_name string|nil last user input into template name textfield
---@field elements SurfaceManagerElements|nil


local VSurfaceManager = require("src.world.vsurface-manager")
local VEnvProcessor = require("src.simulation.venv-processor")
local CommonGui = require("src.gui.common")
local GuiUpdater = require("src.gui.updater")

local PREFIX = "FV-"
local SurfaceManagerGui = {}

-------------------------------------------------------------------------------
-- CONTROL ELEMENTS: CREATE/CONFIGURE FUNCTIONS
-------------------------------------------------------------------------------

---Updates vsurface selector located on the left side of interface
---@param manager_data SurfaceManagerData
local function configure_vsurface_selector(manager_data)
    local selector = manager_data.elements.vsurface_selector
    if not selector.valid then return end
    local options = VSurfaceManager.get_all_vsurface_names()
    local query = manager_data.vsurface_search_query
    local selected = manager_data.selected_vsurface
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures vsurface selector and searchfield above
---@param manager_data SurfaceManagerData
local function configure_vsurface_selection_widget(manager_data)
    local search = manager_data.elements.vsurface_search
    if not search.valid then return end
    search.text = manager_data.vsurface_search_query or ""
    configure_vsurface_selector(manager_data)
end

---Adds vsurface selection widget to given element. Widget contains
---of "label", "textfield" for searching and "list-box" for selection.
---@param parent LuaGuiElement widget will be added here
---@param manager_data SurfaceManagerData
local function create_vsurface_selection_widget(parent, manager_data)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "sm-vsurface-search",
        PREFIX .. "sm-vsurface-selector",
        {"gui-label.select-vsurface"}
    )
    manager_data.elements.vsurface_selector = selector
    manager_data.elements.vsurface_search = search
    configure_vsurface_selection_widget(manager_data)
end

---Configures "create new surface" button
---@param manager_data SurfaceManagerData
local function configure_create_new_surface_btn(manager_data)
    local button = manager_data.elements.create_surface_btn
    if not button.valid then return end
    button.enabled = not manager_data.new_surface_pressed
end

---Adds "create new surface" button to given element
---@param parent LuaGuiElement button will be added here
---@param manager_data SurfaceManagerData
local function create_create_new_surface_btn(parent, manager_data)
    local create_button = parent.add{
        type = "button",
        name = PREFIX .. "sm-new-surface-btn",
        caption = {"gui-label.create-new-vsurface"},
    }
    create_button.style.horizontally_stretchable = true
    manager_data.elements.create_surface_btn = create_button
    configure_create_new_surface_btn(manager_data)
end

---Configures "delete selected surface" button
---@param manager_data SurfaceManagerData
local function configure_delete_surface_btn(manager_data)
    local button = manager_data.elements.delete_surface_btn
    if not button.valid then return end
    button.enabled = not not manager_data.selected_vsurface
end

---Adds "delete selected surface" button to given element
---@param parent LuaGuiElement button will be added here
---@param manager_data SurfaceManagerData
local function create_delete_surface_btn(parent, manager_data)
    local delete_button = parent.add{
        type = "button",
        name = PREFIX .. "sm-delete-surface-btn",
        caption = {"gui-label.delete-selected-vsurface"},
        style = "red_button",
    }
    delete_button.style.horizontally_stretchable = true
    manager_data.elements.delete_surface_btn = delete_button
    configure_delete_surface_btn(manager_data)
end

---Configures new surface name textfield
---@param manager_data SurfaceManagerData
local function configure_new_surface_name_field(manager_data)
    local textfield = manager_data.elements.new_surface_name_textfield
    ---@cast textfield LuaGuiElement
    if not textfield.valid then return end
    textfield.text = manager_data.new_surface_name or ""
end

---Adds textfield where new surface name can be typed and label above.
---@param parent LuaGuiElement button will be added here
---@param manager_data table vsurface manager data from storage
local function create_new_surface_name_field(parent, manager_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{type = "label", caption = {"gui-label.new-surface-name"}}
    local textfield = flow.add{
        type = "textfield",
        name = PREFIX .. "sm-new-surface-name",
        lose_focus_on_confirm = true,
    }
    manager_data.elements.new_surface_name_textfield = textfield
    configure_new_surface_name_field(manager_data)
end

---Configured new surface energy drain label
---@param manager_data SurfaceManagerData
local function configure_new_surface_drain(manager_data)
    local drain_label = manager_data.elements.new_surface_drain
    ---@cast drain_label LuaGuiElement
    if not drain_label.valid then return end
    local width = tonumber(manager_data.new_surface_width)
    local height = tonumber(manager_data.new_surface_height)
    local drain = VSurfaceManager.calculate_energy_drain(width, height)
    local formated_drain = CommonGui.format_number(drain) .. "W"
    drain_label.caption = {"", {"gui-label.template-energy-drain"}, ": ", formated_drain}
end

---Configures new surface size widget. Loads last user input and
---updates template energy drain label.
---@param manager_data SurfaceManagerData
local function configure_new_surface_size_widget(manager_data)
    local width_field = manager_data.elements.new_surface_width
    local height_field = manager_data.elements.new_surface_height
    ---@cast width_field LuaGuiElement
    ---@cast height_field LuaGuiElement
    if not width_field.valid or not height_field.valid then return end
    -- loading last user input into height and width fields
    local saved_width = manager_data.new_surface_width
    local seved_height = manager_data.new_surface_height

    width_field.text = saved_width and tostring(saved_width) or ""
    height_field.text = seved_height and tostring(seved_height) or ""

    configure_new_surface_drain(manager_data)
end

---Adds 2 textfields where height and width of new surface can be specified.
---@param parent LuaGuiElement widget will be added here
---@param manager_data SurfaceManagerData
local function create_new_surface_size_widget(parent, manager_data)
    local main_flow = parent.add{type = "flow", direction = "vertical"}

    -- width and height textfields with their labels and spacer between
    local h_flow = main_flow.add{type = "flow", direction = "horizontal"}
    h_flow.style.horizontal_spacing = 0
    local v_flow1 = h_flow.add{type = "flow", direction = "vertical"}
    v_flow1.add{type = "label", caption = {"gui-label.width"}}
    local width_field = v_flow1.add{
        type = "textfield",
        name = PREFIX .. "sm-new-surface-width",
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
        lose_focus_on_confirm = true,
    }
    width_field.style.width = 75
    manager_data.elements.new_surface_width = width_field
    local spacer = h_flow.add{type = "flow"}
    spacer.style.width = 50
    local v_flow2 = h_flow.add{type = "flow", direction = "vertical"}
    v_flow2.add{type = "label", caption = {"gui-label.height"}}
    local height_field = v_flow2.add{
        type = "textfield",
        name = PREFIX .. "sm-new-surface-height",
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
        lose_focus_on_confirm = true,
    }
    height_field.style.width = 75
    manager_data.elements.new_surface_height = height_field

    -- template energy drain label
    local drain = main_flow.add{type = "label", style = "bold_label"}
    manager_data.elements.new_surface_drain = drain
    configure_new_surface_size_widget(manager_data)
end

---Configures "generate as" planet selector
---@param manager_data SurfaceManagerData
local function configure_planet_selector(manager_data)
    local selector = manager_data.elements.planet_selector
    ---@cast selector LuaGuiElement
    if not selector.valid then return end
    local options = VSurfaceManager.get_generate_as_options()
    local selected = manager_data.selected_planet
    CommonGui.configure_selector(selector, options, nil, selected)
end

---Adds "generate as" planet selector to new surface creation interface
---@param parent LuaGuiElement element will be added here
---@param manager_data SurfaceManagerData
local function create_planet_selector(parent, manager_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    flow.add{type = "label", caption = {"gui-label.generate-as"}}
    local selector = flow.add{type = "list-box", name = PREFIX .. "sm-planet-selector"}
    selector.style.width = 200
    selector.style.height = 100
    manager_data.elements.planet_selector = selector
    configure_planet_selector(manager_data)
end

---Configures confirm create new surface button.
---@param manager_data SurfaceManagerData
local function configure_new_surface_confirm_btn(manager_data)
    local button = manager_data.elements.new_surface_confirm
    local label = manager_data.elements.new_surface_confirm_status
    ---@cast button LuaGuiElement
    ---@cast label LuaGuiElement
    if not button.valid or not label.valid then return end

    local can_create, response = VSurfaceManager.can_create_vsurface(
        manager_data.new_surface_name,
        manager_data.new_surface_width,
        manager_data.new_surface_height,
        manager_data.selected_planet
    )

    button.enabled = can_create
    label.caption = (response or "")
end

---Adds confirm create new surface button with status label above.
---Also adds invisible spacers to put button at the bottom right corner.
---@param parent LuaGuiElement button will be added here
---@param manager_data SurfaceManagerData
local function create_new_surface_confirm_btn(parent, manager_data)
    -- spacer to put confirmation button at the bottom
    local v_spacer = parent.add{type = "flow"}
    v_spacer.style.vertically_stretchable = true

    -- needed to put elements on the right side
    local flow = parent.add{
        type = "flow",
        direction = "vertical",
    }
    flow.style.horizontally_stretchable = true
    flow.style.horizontal_align = "right"

    -- button and status label
    local label = flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    local button = flow.add{
        type = "button",
        name = PREFIX .. "sm-new-surface-confirm",
        caption = {"gui-label.confirm"},
        style = "confirm_button",
    }
    button.tooltip = {"gui-label.confirm-tooltip"}
    manager_data.elements.new_surface_confirm = button
    manager_data.elements.new_surface_confirm_status = label
    configure_new_surface_confirm_btn(manager_data)
end

---Configures template name textfield and label above
---@param manager_data SurfaceManagerData
local function configure_template_name_textfield(manager_data)
    local textfield = manager_data.elements.template_name_textfield
    local label = manager_data.elements.template_name_label
    ---@cast textfield LuaGuiElement
    ---@cast label LuaGuiElement
    if not textfield.valid or not label.valid then return end
    local surface_name = manager_data.selected_vsurface
    local compilation_progress = VEnvProcessor.get_compilation_progress(surface_name)
    local is_compiling = (compilation_progress ~= nil)
    textfield.visible = not is_compiling
    label.visible = not is_compiling
    textfield.text = (manager_data.template_name or "")
end

---Adds textfield where template name can be typed as well as label above.
---@param parent LuaGuiElement button will be added here
---@param manager_data SurfaceManagerData
local function create_template_name_textfield(parent, manager_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    local label = flow.add{
        type = "label",
        caption = {"gui-label.enter-template-name"},
    }
    local textfield = flow.add{
        type = "textfield",
        name = PREFIX .. "sm-template-name",
        lose_focus_on_confirm = true,
    }
    manager_data.elements.template_name_textfield = textfield
    manager_data.elements.template_name_label = label
    configure_template_name_textfield(manager_data)
end

---Configured start compilation button and status label above
---@param manager_data SurfaceManagerData
local function configure_start_compilation_btn(manager_data)
    local button = manager_data.elements.compile_btn
    local label = manager_data.elements.compile_btn_status
    ---@cast button LuaGuiElement
    ---@cast label LuaGuiElement
    if not button.valid or not label.valid then return end

    local surface_name = manager_data.selected_vsurface
    local template_name = manager_data.template_name

    -- checking if compilation can be started
    local can_compile, response = VEnvProcessor.can_start_compilation(surface_name, template_name)
    button.enabled = can_compile
    label.caption = (response or "")

    -- checking if surface is already compiling
    local compilation_progress = VEnvProcessor.get_compilation_progress(surface_name)
    local is_compiling = (compilation_progress ~= nil)
    button.visible = not is_compiling
    label.visible = not is_compiling
end

---Adds start compilation button and status label above
---Also adds invisible spacers to put button at the bottom right corner.
---@param parent LuaGuiElement button will be added here
---@param manager_data SurfaceManagerData
local function create_start_compilation_btn(parent, manager_data)
    -- spacer to put compilation button at the bottom
    local spacer = parent.add{type = "flow"}
    spacer.style.vertically_stretchable = true

    -- needed to put elements on the right side
    local flow = parent.add{
        type = "flow",
        direction = "vertical",
    }
    flow.style.horizontally_stretchable = true
    flow.style.horizontal_align = "right"

    local label = flow.add{type = "label"}
    label.style.font_color = CommonGui.red
    local button = flow.add{
        type = "button",
        name = PREFIX .. "sm-start-compilation-btn",
        caption = {"gui-label.start-compilation"},
        style = "confirm_button",
    }
    button.tooltip = {"gui-label.compile-tooltip"}
    manager_data.elements.compile_btn = button
    manager_data.elements.compile_btn_status = label
    configure_start_compilation_btn(manager_data)
end

-------------------------------------------------------------------------------
-- INFORMATION ELEMENTS: CREATE/CONFIGURE FUNCTIONS 
-------------------------------------------------------------------------------

---Configures compilation progressbar and label above
---@param manager_data SurfaceManagerData
local function configure_compilation_progressbar(manager_data)
    local bar = manager_data.elements.compile_progressbar
    local label = manager_data.elements.compile_bar_label
    ---@cast bar LuaGuiElement
    ---@cast label LuaGuiElement
    if not bar.valid or not label.valid then return end

    local surface_name = manager_data.selected_vsurface
    local elapsed, remaining = VEnvProcessor.get_compilation_progress(surface_name)
    local is_compiling = (elapsed ~= nil)
    bar.visible = is_compiling
    label.visible = is_compiling
    if is_compiling then
        local total = elapsed + remaining
        bar.value = (total > 0) and (elapsed / total) or 0
        local progress = tostring(elapsed) .. "/" .. tostring(elapsed + remaining)
        label.caption = {"", {"gui-label.compilation-progress"}, ": " .. progress}
    end
end

---Adds compilation progressbar and label above to given element.
---@param parent LuaGuiElement button will be added here
---@param manager_data SurfaceManagerData
local function create_compilation_progressbar(parent, manager_data)
    local flow = parent.add{type = "flow", direction = "vertical"}
    local label = flow.add{type = "label"}
    local bar = flow.add{type = "progressbar"}
    bar.style.bar_width = 12
    manager_data.elements.compile_bar_label = label
    manager_data.elements.compile_progressbar = bar
    configure_compilation_progressbar(manager_data)
end

-------------------------------------------------------------------------------
-- GUI CONSTRUCTION
-------------------------------------------------------------------------------

---Creates vsurface manager base. Surface manager must be closed when calling this.
---Base consists of elements that are always present in the window.
---@param player LuaPlayer player for which window is created. Assumed to be valid.
---@return SurfaceManagerData
local function create_surface_manager_base(player)
    -- creating base window and "opening" it
    local main_frame = CommonGui.create_base_window(
        player,
        PREFIX .. "sm-window",
        {"gui-label.vsurface-manager-window"}
    )
    player.opened = main_frame

    -- fetching or creating manager data in storage for given player
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
        style="inside_shallow_frame_with_padding",
    }
    left_frame.style.right_margin = 12
    left_frame.style.vertically_stretchable = true
    -- required to set vertical spacing
    local left_flow = left_frame.add{
        type = "flow",
        direction = "vertical",
    }
    left_flow.style.vertical_spacing = 12
    create_vsurface_selection_widget(left_flow, manager_data)
    create_create_new_surface_btn(left_flow, manager_data)
    create_delete_surface_btn(left_flow, manager_data)

    -- right half of interface
    local right_frame = main_content_frame.add{
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }
    right_frame.style.minimal_width = 350
    right_frame.style.vertically_stretchable = true
    -- required to set vertical spacing
    local right_flow = right_frame.add{
        type = "flow",
        direction = "vertical",
    }
    right_flow.style.vertical_spacing = 12
    manager_data.elements.right_frame = right_flow
    return manager_data
end

---Clears all element in the right frame and populates it.
---@param manager_data SurfaceManagerData
local function update_right_frame(manager_data)
    local right_frame = manager_data.elements.right_frame
    right_frame.clear()

    if manager_data.new_surface_pressed then
        -- new vsurface creation gui
        create_new_surface_name_field(right_frame, manager_data)
        create_new_surface_size_widget(right_frame, manager_data)
        create_planet_selector(right_frame, manager_data)
        create_new_surface_confirm_btn(right_frame, manager_data)
    elseif manager_data.selected_vsurface then
        -- existing vsurface compilation gui
        create_template_name_textfield(right_frame, manager_data)
        create_compilation_progressbar(right_frame, manager_data)
        create_start_compilation_btn(right_frame, manager_data)
    end
end

---Time-based updater for vsurface manager window
local function time_based_updater(manager_data)
    if manager_data.selected_vsurface then
        configure_template_name_textfield(manager_data)
        configure_compilation_progressbar(manager_data)
        configure_start_compilation_btn(manager_data)
    end
end

GuiUpdater.add_schema("surface_manager", time_based_updater)

-------------------------------------------------------------------------------
-- CONTROL ELEMENTS: HANDLER FUNCTIONS
-------------------------------------------------------------------------------

---Handles vsurface selector searchfield being changed
---@param event EventData.on_gui_text_changed
function SurfaceManagerGui.process_vsurface_selection_search(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.vsurface_search_query = event.text
    configure_vsurface_selector(manager_data)
end

---Handles vsurface being changed in the selector
---@param event EventData.on_gui_selection_state_changed
function SurfaceManagerGui.process_vsurface_selection_changed(event)
    local manager_data = storage.surface_manager[event.player_index]
    local selector = event.element
    local old_name = manager_data.selected_vsurface
    local new_name = selector.items[selector.selected_index]

    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        manager_data.selected_vsurface = nil
        configure_vsurface_selector(manager_data)
    else
        manager_data.selected_vsurface = new_name
    end
    manager_data.new_surface_pressed = nil

    configure_create_new_surface_btn(manager_data)
    configure_delete_surface_btn(manager_data)
    update_right_frame(manager_data)
end

---Handles "create new v-surface" button being pressed. Opens new vsurface creation gui.
---@param event EventData.on_gui_click
function SurfaceManagerGui.process_create_new_surface_btn(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.new_surface_pressed = true
    manager_data.selected_vsurface = nil
    configure_vsurface_selector(manager_data)
    configure_create_new_surface_btn(manager_data)
    configure_delete_surface_btn(manager_data)
    update_right_frame(manager_data)
end

---Handles "delete current surface" being pressed. Requests deletion of the surface.
---@param event EventData.on_gui_click
function SurfaceManagerGui.process_delete_surface_btn(event)
    local manager_data = storage.surface_manager[event.player_index]
    local surface_name = manager_data.selected_vsurface
    VSurfaceManager.delete_vsurface(surface_name)
    manager_data.selected_vsurface = nil
    configure_delete_surface_btn(manager_data)
    configure_vsurface_selector(manager_data)
    update_right_frame(manager_data)
end

---Handles new surface name textfield being changed. Saves entered text.
---@param event EventData.on_gui_text_changed
function SurfaceManagerGui.process_new_surface_name_changed(event)
    local manager_data = storage.surface_manager[event.player_index]
    local textfield = event.element
    manager_data.new_surface_name = textfield.text
    configure_new_surface_confirm_btn(manager_data)
end

---Handles new surface width textfield being changed.
---@param event EventData.on_gui_text_changed
function SurfaceManagerGui.process_new_surface_width_changed(event)
    local manager_data = storage.surface_manager[event.player_index]
    local element = event.element
    manager_data.new_surface_width = tonumber(element.text)
    configure_new_surface_drain(manager_data)
    configure_new_surface_confirm_btn(manager_data)
end

---Handles new surface height textfield being changed.
---@param event EventData.on_gui_text_changed
function SurfaceManagerGui.process_new_surface_height_changed(event)
    local manager_data = storage.surface_manager[event.player_index]
    local element = event.element
    manager_data.new_surface_height = tonumber(element.text)
    configure_new_surface_drain(manager_data)
    configure_new_surface_confirm_btn(manager_data)
end

---Handles "generate as" planet selection being changed
---@param event EventData.on_gui_selection_state_changed
function SurfaceManagerGui.process_planet_selector(event)
    ---@type SurfaceManagerData
    local manager_data = storage.surface_manager[event.player_index]
    local selector = event.element
    local old_name = manager_data.selected_planet
    local new_name = selector.items[selector.selected_index]
    ---@cast new_name string|nil

    -- if selected item is clicked again, we want to unselect it
    if old_name == new_name then
        manager_data.selected_planet = nil
        configure_planet_selector(manager_data)
    else
        manager_data.selected_planet = new_name
    end
    configure_new_surface_confirm_btn(manager_data)
end

---Handles confirm create new surface button being pressed. Requests surface creation.
---Closes opened window because creation function moves camera to created surface.
---@param event EventData.on_gui_click
function SurfaceManagerGui.process_new_surface_confirm_btn(event)
    local manager_data = storage.surface_manager[event.player_index]

    -- getting LuaPlayer object and closing window
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = nil

    -- creating requested surface
    VSurfaceManager.create_vsurface(
        player,
        manager_data.new_surface_name,
        manager_data.new_surface_width,
        manager_data.new_surface_height,
        manager_data.selected_planet
    )

    -- cleaning up manager data
    manager_data.new_surface_name = nil
    manager_data.new_surface_width = nil
    manager_data.new_surface_height = nil
    manager_data.selected_planet = nil
    manager_data.new_surface_pressed = nil
end

---Handles template name textfield being changed. Saves user input.
---@param event EventData.on_gui_text_changed
function SurfaceManagerGui.process_template_name_changed(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.template_name = event.text
    configure_start_compilation_btn(manager_data)
end

---Handles start compilation button being pressed. Requests compilation start.
---@param event EventData.on_gui_click
function SurfaceManagerGui.process_start_compilation_btn(event)
    local manager_data = storage.surface_manager[event.player_index]
    local surface_name = manager_data.selected_vsurface
    local template_name = manager_data.template_name
    VEnvProcessor.start_compilation(surface_name, template_name)
    manager_data.template_name = nil
    update_right_frame(manager_data)
end

-------------------------------------------------------------------------------
-- MAIN LOGIC: OPEN/CLOSE/UPDATE FUNCTIONS
-------------------------------------------------------------------------------

---Opens surface manager for a given player or closes if already opened
---@param player LuaPlayer
local function toggle_surface_manager(player)
    local manager_data = storage.surface_manager[player.index]

    -- closing the window if it was opened
    if manager_data and manager_data.opened then
        player.opened = nil
        return
    end

    manager_data = create_surface_manager_base(player)
    update_right_frame(manager_data)
    GuiUpdater.register_gui("surface_manager", manager_data, player.index)
end

---Closes the surface manager when player.opened changes from
---vsurface manager window to something else.
---@param event EventData.on_gui_closed 
function SurfaceManagerGui.process_surface_manager_gui_closed(event)
    local manager_data = storage.surface_manager[event.player_index]
    manager_data.opened = nil
    manager_data.elements.main_window.destroy()
    manager_data.elements = nil
end

---Toggles surface manager when shortcut bar element is clicked
---@param event EventData.on_lua_shortcut
function SurfaceManagerGui.process_surface_manager_shortcut(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_surface_manager(player)
end

---Toggles surface manager when custom hotkey is pressed
---@param event EventData.CustomInputEvent
function SurfaceManagerGui.process_surface_manager_hotkey(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    toggle_surface_manager(player)
end

return SurfaceManagerGui