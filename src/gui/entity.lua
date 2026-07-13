--[[
Entities that are added by this mod have custom gui for several reasons.
Most notably, custom gui are needed to give player the opportunity to manipulate
entity data in entity registry. Second reason is player QoL. Entity gui will often
display important information regarding entity. Like current status, current item
requests of vmainframe, information of cluster entity is connected to, etc.

Technically entity gui is handled as follows: when player opens an entity from this mod,
its vanilla gui is closed and this one open instead. For convenience, internal name of
this window is the same for all entities. Technically it's always the same window, however
elements displayed depend on entity name. Both alive entities and entity-ghosts are supported.
Backend is handled by entity processor.

On gui creation, references to all elements that we want to have quick access to are saved in storage.
As well as several important values like reference to entity, entity name, etc. All data is located
at storage.entity_gui. For this table key is player index, value is table containing gui data.

We need to keep track of all opened entity gui windows for time-based updades. For that
player_indexes of all players who have this window opened are saved at storage.entity_gui.currently_opened
Like this: storage.entity_gui.currently_opened = {1 = true, 7 = true, 123 = true}

-------------------------------------------------------------------------------
GUI DATA KEYS
-------------------------------------------------------------------------------
entity LuaEntity: entity that was opened to create this gui
template_search_query string|nil: user input into textfield above template selector
elements.main_window LuaGuiElement: reference to main entity gui window
elements.left_frame LuaGuiElement: reference to left frame of interface
elements.datafield LuaGuiElement: reference to datafield on the right side of interface
elements.template_selector LuaGuiElement: reference to template selector
elements.template_search LuaGuiElement: reference to template searchfield
elements.choose_item_button LuaGuiElement: reference to choose item button
elements.choose_fluid_button LuaGuiElement: reference to choose fluid button
elements.input_radiobutton LuaGuiElement: reference to input radiobutton
elements.output_radiobutton LuaGuiElement: reference to output radiobutton
--]]

local EntityProcessor = require("src.world.entity-processor")
local TemplateCompiler = require("src.simulation.template-compiler")
local CommonGui = require("src.gui.common")

local PREFIX = "FV-"
local EntityGui = {}

-------------------------------------------------------------------------------
-- CONTROL ELEMENTS: CREATE/CONFIGURE/HANDLE FUNCTIONS
-------------------------------------------------------------------------------

---Sets player.opened to nil for a given player.
---Used to close this gui when entity becomes invalid
---@param player_index integer unique player identifier
local function close_opened_window(player_index)
    local player = game.get_player(player_index)
    if not player or not player.valid then return end
    player.opened = nil
end

---Standart check performed before handling any user inputs. Checks that 
---entity for which gui is opened is still valid. If not, window is closed.
---@return boolean status true if entity is valid
local function assert_entity_validity(player_index, gui_data)
    -- checking that entity is valid
    local entity = gui_data.entity
    if not entity.valid then
        close_opened_window(player_index)
        return false
    end
    return true
end

---Configures choose input/output radiobuttons
---@param gui_data table entity gui data from storage
local function configure_choose_io_buttons(gui_data)
    local input_button = gui_data.elements.input_radiobutton
    local output_button = gui_data.elements.output_radiobutton
    local is_output = EntityProcessor.get_output_flag(gui_data.entity)
    input_button.state = not is_output
    output_button.state = not not is_output
end

---Adds 2 radiobuttons to choose IO mode of operation.
---@param parent LuaGuiElement buttons will be added here
---@param gui_data table entity gui data from storage
local function create_choose_io_buttons(parent, gui_data)
    local main_flow = parent.add{type = "flow", direction = "vertical"}
    main_flow.add{type = "label", caption = {"gui-label.operation-mode"}}
    main_flow.style.bottom_margin = 12

    -- input radiobutton 
    local row1 = main_flow.add{type = "flow", direction = "horizontal"}
    row1.style.vertical_align = "center"
    local button1 = row1.add{
        type = "radiobutton",
        name = PREFIX .. "input-radiobutton",
        state = false
    }
    row1.add{type = "label", caption = {"gui-label.input"}}
    gui_data.elements.input_radiobutton = button1

    -- output radiobutton
    local row2 = main_flow.add{type = "flow", direction = "horizontal"}
    row2.style.vertical_align = "center"
    local button2 = row2.add{
        type = "radiobutton",
        name = PREFIX .. "output-radiobutton",
        state = false
    }
    row2.add{type = "label", caption = {"gui-label.output"}}
    gui_data.elements.output_radiobutton = button2

    configure_choose_io_buttons(gui_data)
end

---Handles input radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.process_input_chosen(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    EntityProcessor.set_output_flag(gui_data.entity, false)
    configure_choose_io_buttons(gui_data)
end

---Handles output radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.process_output_chosen(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    EntityProcessor.set_output_flag(gui_data.entity, true)
    configure_choose_io_buttons(gui_data)
end

---Configures template selector
---@param gui_data table entity gui data from storage
local function configure_template_selector(gui_data)
    local selector = gui_data.elements.template_selector
    local options = TemplateCompiler.get_all_template_names()
    local query = gui_data.template_search_query
    local selected = EntityProcessor.get_selected_template(gui_data.entity)
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures template selector and searchbox above
---@param gui_data table entity gui data from storage
local function configure_template_selection_widget(gui_data)
    local search = gui_data.elements.template_search
    search.text = gui_data.template_search_query or ""
    configure_template_selector(gui_data)
end

---Adds template selection widget that consists of subtitle,
---searchbox and selector element
---@param parent LuaGuiElement widget will be added here
---@param gui_data table entity gui data from storage
local function create_template_selection_widget(parent, gui_data)
    local search, selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "entity-template-search",
        PREFIX .. "entity-template-selector",
        {"gui-label.select-template"}
    )
    gui_data.elements.template_search = search
    gui_data.elements.template_selector = selector
    configure_template_selection_widget(gui_data)
end

---Handles template name search query being changed
---@param event EventData.on_gui_text_changed
function EntityGui.process_template_searchfield(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.template_search_query = event.element.text
    configure_template_selector(gui_data)
end

---Handles template selection being changed
---@param event EventData.on_gui_selection_state_changed
function EntityGui.process_template_selector(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end

    local entity = gui_data.entity
    local old_selection = EntityProcessor.get_selected_template(entity)
    local element = event.element
    local new_selection = element.items[element.selected_index]
    ---@cast new_selection string|nil

    -- if selected item is clicked again, we want to unselect it
    if old_selection == new_selection then
        EntityProcessor.set_selected_template(entity, nil)
        configure_template_selector(gui_data)
    else
        EntityProcessor.set_selected_template(entity, new_selection)
    end
end

---Configures choose item button
---@param gui_data table entity gui data from storage
local function configure_choose_item_button(gui_data)
    local button = gui_data.elements.choose_item_button
    -- setting selected item according to entity processor
    local item = EntityProcessor.get_selected_item(gui_data.entity)
    if item then
        button.elem_value = {
            name = item.name,
            quality = item.quality
        }
    end
end

---Adds choose elem button with type "item-with-quality"
---@param parent LuaGuiElement widget will be added here
---@param gui_data table entity gui data from storage
local function create_choose_item_button(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    row.add{type="label", caption={"gui-label.select-item"}}
    local button = row.add{
        type = "choose-elem-button",
        name = PREFIX .. "choose-item-button",
        elem_type = "item-with-quality",
    }
    gui_data.elements.choose_item_button = button
    configure_choose_item_button(gui_data)
end

---Handles choose item button selection being changed
---@param event EventData.on_gui_elem_changed
function EntityGui.process_choose_item_button(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    -- saving selection to entity processor
    local selection = event.element.elem_value
    local item = selection and {name = selection.name, quality = selection.quality}
    EntityProcessor.set_selected_item(gui_data.entity, item)
end

---Configures choose fluid button
---@param gui_data table entity gui data from storage
local function configure_choose_fluid_button(gui_data)
    local button = gui_data.elements.choose_fluid_button
    -- setting selected fluid according to entity processor
    local fluid = EntityProcessor.get_selected_fluid(gui_data.entity)
    if fluid then button.elem_value = fluid end
end

-- Adds choose elem button with type "fluid"
local function create_choose_fluid_button(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    row.add{type = "label", caption = {"gui-label.select-fluid"}}
    local button = row.add{
        type = "choose-elem-button",
        name = PREFIX .. "choose-fluid-button",
        elem_type = "fluid",
    }
    gui_data.elements.choose_fluid_button = button
    configure_choose_fluid_button(gui_data)
end

---Handles choose fluid button selection being changed
---@param event EventData.on_gui_elem_changed
function EntityGui.process_choose_fluid_button(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end

    -- saving selected fluid to entity processor
    local fluid_name = event.element.elem_value
    ---@diagnostic disable-next-line: param-type-mismatch
    EntityProcessor.set_selected_fluid(gui_data.entity, fluid_name)
end

-------------------------------------------------------------------------------
-- GUI CONSTRUCTORS
-------------------------------------------------------------------------------

---Creates a base for entity gui and initializes the entity gui
---section in storage for given player. It's assumed that custom
---entity gui window is not opened when this is called.
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_entity_gui_base(player, entity)
    -- initializing entity_gui storage for given player
    storage.entity_gui[player.index] = storage.entity_gui[player.index] or {}
    local gui_data = storage.entity_gui[player.index]
    gui_data.elements = {}
    gui_data.entity = entity

    -- creating base window
    local entity_name = entity.name
    if entity_name == "entity-ghost" then entity_name = entity.ghost_name end
    local title = {"entity-name." .. entity_name}
    local main_window = CommonGui.create_base_window(
        player,
        PREFIX .. "entity-window",
        title
    )
    gui_data.elements.main_window = main_window
    main_window.style.height = 500

    -- "opening" this window for player
    player.opened = main_window
    storage.entity_gui.currently_opened = storage.entity_gui.currently_opened or {}
    local curr_opened = storage.entity_gui.currently_opened
    curr_opened[player.index] = true

    -- invisible container for other frames
    local main_flow = main_window.add{
        type="flow",
        direction="horizontal",
    }

    -- left half of interface for controls
    local left_frame = main_flow.add{
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding",
    }
    left_frame.style.right_margin = 12
    gui_data.elements.left_frame = left_frame

    -- right side of interface is for info display
    local right_frame = main_flow.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical"
    }
    right_frame.style.width = 444
    local datafield = right_frame.add{type = "scroll-pane"}
    datafield.style.vertically_stretchable = true
    gui_data.elements.datafield = datafield
    return gui_data
end


local function template_item_io(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    add_choose_io_buttons(left_frame, gui_data)
    add_choose_item_button(left_frame, gui_data)
end

local function template_fluid_io(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    add_choose_io_buttons(left_frame, gui_data)
    add_choose_fluid_button(left_frame, gui_data)
end

local function template_energy_io(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    add_choose_io_buttons(left_frame, gui_data)
end

local function mainframe_item_io(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    add_choose_io_buttons(left_frame, gui_data)
    add_template_selection_widget(left_frame, gui_data)
    add_choose_item_button(left_frame, gui_data)
end

local function mainframe_fluid_io(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    add_choose_io_buttons(left_frame, gui_data)
    add_template_selection_widget(left_frame, gui_data)
    add_choose_fluid_button(left_frame, gui_data)
end

local function mainframe_energy_io(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    add_choose_io_buttons(left_frame, gui_data)
    add_template_selection_widget(left_frame, gui_data)
end

local function virtualization_mainframe(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    add_template_selection_widget(left_frame, gui_data)
end