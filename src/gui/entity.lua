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
--]]

---Table with references to entity gui elements.
---@class EntityGuiElements: GuiElementsBase
---@field left_frame LuaGuiElement Left column
---@field datafield LuaGuiElement Right column for information display
---@field template_selector LuaGuiElement|nil Mainframes, Mainframe IOs
---@field template_search LuaGuiElement|nil Mainframes, Mainframe IOs
---@field choose_item_button LuaGuiElement|nil EntityWithItemSelection
---@field choose_fluid_button LuaGuiElement|nil EntityWithFluidSelection
---@field input_radiobutton LuaGuiElement|nil EntityWithIOSelection
---@field output_radiobutton LuaGuiElement|nil EntityWithIOSelection
---@field item_mode_radiobutton LuaGuiElement|nil InterClusterBridge
---@field fluid_mode_radiobutton LuaGuiElement|nil InterClusterBridge
---@field energy_mode_radiobutton LuaGuiElement|nil InterClusterBridge
---@field source_cluster_search LuaGuiElement|nil InterClusterBridge
---@field source_cluster_selector LuaGuiElement|nil InterClusterBridge
---@field destination_cluster_search LuaGuiElement|nil InterClusterBridge
---@field destination_cluster_selector LuaGuiElement|nil InterClusterBridge

---Table describing entity GUI state
---@class EntityGuiData: GuiDataBase
---@field entity LuaEntity entity that was opened to create this gui
---@field player_index number unique player identifier
---@field template_search_query string|nil user input into template search
---@field source_cluster_query string|nil user input into source cluster search
---@field destination_cluster_query string|nil user input into destination cluster search
---@field elements EntityGuiElements|nil


local EntityProcessor = require("src.world.entity-processor")
local TemplateCompiler = require("src.simulation.template-compiler")
local ClusterProcessor = require("src.simulation.cluster-processor")
local CommonGui = require("src.gui.common")
local ClusterInfo = require("src.gui.cluster-info")
local GuiUpdater = require("src.gui.updater")

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
---@param gui_data EntityGuiData
local function configure_choose_io_buttons(gui_data)
    local input_button = gui_data.elements.input_radiobutton
    local output_button = gui_data.elements.output_radiobutton
    ---@cast input_button LuaGuiElement
    ---@cast output_button LuaGuiElement
    if not input_button.valid or not output_button.valid then return end
    local is_output = EntityProcessor.get_output_flag(gui_data.entity)
    input_button.state = not is_output
    output_button.state = not not is_output
end

---Adds 2 radiobuttons to choose IO mode of operation.
---@param parent LuaGuiElement buttons will be added here
---@param gui_data EntityGuiData
local function create_choose_io_buttons(parent, gui_data)
    local main_flow = parent.add{type = "flow", direction = "vertical"}
    main_flow.add{type = "label", caption = {"gui-label.operation-mode"}}

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
---@param gui_data EntityGuiData
local function configure_template_selector(gui_data)
    local selector = gui_data.elements.template_selector
    ---@cast selector LuaGuiElement
    if not selector.valid then return end
    local options = TemplateCompiler.get_all_template_names()
    local query = gui_data.template_search_query
    local selected = EntityProcessor.get_selected_template(gui_data.entity)
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures template selector and searchbox above
---@param gui_data EntityGuiData
local function configure_template_selection_widget(gui_data)
    local search = gui_data.elements.template_search
    ---@cast search LuaGuiElement
    if not search.valid then return end
    search.text = gui_data.template_search_query or ""
    configure_template_selector(gui_data)
end

---Adds template selection widget that consists of subtitle,
---searchbox and selector element
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData
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
---@param gui_data EntityGuiData
local function configure_choose_item_button(gui_data)
    local button = gui_data.elements.choose_item_button
    ---@cast button LuaGuiElement
    if not button.valid then return end
    -- setting selected item according to entity processor
    local name, quality = EntityProcessor.get_selected_item(gui_data.entity)
    button.elem_value = name and quality and {name = name, quality = quality} or nil
    -- checking if button should be enabled
    button.enabled = EntityProcessor.get_item_selection_enabled(gui_data.entity)
end

---Adds choose elem button with type "item-with-quality"
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData
local function create_choose_item_button(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local button = row.add{
        type = "choose-elem-button",
        name = PREFIX .. "choose-item-button",
        elem_type = "item-with-quality",
    }
    row.add{type="label", caption={"gui-label.select-item"}}
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
    local name = selection and selection.name
    local quality = selection and selection.quality
    ---@cast quality string|nil
    EntityProcessor.set_selected_item(gui_data.entity, name, quality)
end

---Configures choose fluid button
---@param gui_data EntityGuiData
local function configure_choose_fluid_button(gui_data)
    local button = gui_data.elements.choose_fluid_button
    ---@cast button LuaGuiElement
    if not button.valid then return end
    -- setting selected fluid according to entity processor
    local fluid = EntityProcessor.get_selected_fluid(gui_data.entity)
    button.elem_value = fluid

    -- checking if button should be enabled
    button.enabled = EntityProcessor.get_fluid_selection_enabled(gui_data.entity)
end

---Adds choose elem button with type "fluid"
---@param parent LuaGuiElement button will be added here
---@param gui_data EntityGuiData
local function create_choose_fluid_button(parent, gui_data)
    local row = parent.add{type = "flow", direction = "horizontal"}
    row.style.vertical_align = "center"
    local button = row.add{
        type = "choose-elem-button",
        name = PREFIX .. "choose-fluid-button",
        elem_type = "fluid",
    }
    row.add{type = "label", caption = {"gui-label.select-fluid"}}
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

---Configures 3 radio buttons used for mode selection of an entity
---@param gui_data EntityGuiData
local function configure_mode_selection_widget(gui_data)
    local item_button = gui_data.elements.item_mode_radiobutton
    local fluid_button = gui_data.elements.fluid_mode_radiobutton
    local energy_button = gui_data.elements.energy_mode_radiobutton
    ---@cast item_button LuaGuiElement
    ---@cast fluid_button LuaGuiElement
    ---@cast energy_button LuaGuiElement
    if not item_button.valid or not fluid_button.valid or not energy_button.valid then return end

    local mode = EntityProcessor.get_mode(gui_data.entity)

    item_button.state = (mode == "item")
    fluid_button.state = (mode == "fluid")
    energy_button.state = (mode == "energy")
end

---Adds 3 radio buttons used for mode selection of an entity
---@param parent LuaGuiElement widget will be added here
---@param gui_data EntityGuiData
local function create_mode_selection_widget(parent, gui_data)
    local main_flow = parent.add{type = "flow", direction = "vertical"}
    main_flow.add{type = "label", caption = {"gui-label.operation-mode"}}

    -- item mode radiobutton
    local row1 = main_flow.add{type = "flow", direction = "horizontal"}
    row1.style.vertical_align = "center"
    local button1 = row1.add{
        type = "radiobutton",
        name = PREFIX .. "item-mode-radiobutton",
        state = false
    }
    row1.add{type = "label", caption = {"gui-label.item"}}
    gui_data.elements.item_mode_radiobutton = button1

    -- fluid mode radiobutton
    local row2 = main_flow.add{type = "flow", direction = "horizontal"}
    row2.style.vertical_align = "center"
    local button2 = row2.add{
        type = "radiobutton",
        name = PREFIX .. "fluid-mode-radiobutton",
        state = false
    }
    row2.add{type = "label", caption = {"gui-label.fluid"}}
    gui_data.elements.fluid_mode_radiobutton = button2

    -- energy mode radiobutton
    local row3 = main_flow.add{type = "flow", direction = "horizontal"}
    row3.style.vertical_align = "center"
    local button3 = row3.add{
        type = "radiobutton",
        name = PREFIX .. "energy-mode-radiobutton",
        state = false
    }
    row3.add{type = "label", caption = {"gui-label.energy"}}
    gui_data.elements.energy_mode_radiobutton = button3

    configure_mode_selection_widget(gui_data)
end

---Handles any of operation mode radiobuttons being pressed
---@param player_index number unique player identifier
---@param mode "item"|"fluid"|"energy"
local function process_operation_mode_radiobutton(player_index, mode)
    local gui_data = storage.entity_gui[player_index]
    local status = assert_entity_validity(player_index, gui_data)
    if not status then return end
    EntityProcessor.set_mode(gui_data.entity, mode)
    configure_mode_selection_widget(gui_data)
    configure_choose_fluid_button(gui_data)
    configure_choose_item_button(gui_data)
end

---Handles item mode radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.process_item_mode_radiobutton(event)
    process_operation_mode_radiobutton(event.player_index, "item")
end

---Handles fluid mode radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.process_fluid_mode_radiobutton(event)
    process_operation_mode_radiobutton(event.player_index, "fluid")
end

---Handles energy mode radiobutton being pressed
---@param event EventData.on_gui_checked_state_changed
function EntityGui.process_energy_mode_radiobutton(event)
    process_operation_mode_radiobutton(event.player_index, "energy")
end

---Configures source cluster selector
---@param gui_data EntityGuiData
local function configure_source_selector(gui_data)
    ---@type LuaGuiElement
    local selector = gui_data.elements.source_cluster_selector
    if not selector.valid then return end
    local surface_index = gui_data.entity.surface_index
    local options = ClusterProcessor.get_surface_clusters(surface_index)
    local query = gui_data.source_cluster_query
    local selected = EntityProcessor.get_source_template(gui_data.entity)

    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures destination cluster selector
---@param gui_data EntityGuiData
local function configure_destination_selector(gui_data)
    ---@type LuaGuiElement
    local selector = gui_data.elements.destination_cluster_selector
    if not selector.valid then return end
    local surface_index = gui_data.entity.surface_index
    local options = ClusterProcessor.get_surface_clusters(surface_index)
    local query = gui_data.destination_cluster_query
    local selected = EntityProcessor.get_destination_template(gui_data.entity)
    CommonGui.configure_selector(selector, options, query, selected)
end

---Configures "source" and "destination" cluster selectors and their searchboxes
---@param gui_data EntityGuiData
local function configure_cluster_selection_widget(gui_data)
    local source_search = gui_data.elements.source_cluster_search
    local destination_search = gui_data.elements.destination_cluster_search
    ---@cast source_search LuaGuiElement
    ---@cast destination_search LuaGuiElement
    if not source_search.valid or not destination_search.valid then return end
    -- loading last user input to searchfields
    source_search.text = gui_data.source_cluster_query or ""
    destination_search.text = gui_data.destination_cluster_query or ""

    configure_source_selector(gui_data)
    configure_destination_selector(gui_data)
end

---Adds "source" and "destination" cluster selector widgets
---@param parent LuaGuiElement
---@param gui_data EntityGuiData
local function create_cluster_selection_widget(parent, gui_data)
    -- source cluster selection
    local source_search, source_selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "source-cluster-search",
        PREFIX .. "source-cluster-selector",
        {"gui-label.select-source-cluster"},
        100
    )
    gui_data.elements.source_cluster_search = source_search
    gui_data.elements.source_cluster_selector = source_selector

    -- destination cluster selection
    local destination_search, destination_selector = CommonGui.create_selection_widget(
        parent,
        PREFIX .. "destination-cluster-search",
        PREFIX .. "destination-cluster-selector",
        {"gui-label.select-destination-cluster"},
        100
    )
    gui_data.elements.destination_cluster_search = destination_search
    gui_data.elements.destination_cluster_selector = destination_selector

    configure_cluster_selection_widget(gui_data)
end

---Handles source selection search being changed
---@param event EventData.on_gui_text_changed
function EntityGui.process_source_cluster_search(event)
    ---@type EntityGuiData
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.source_cluster_query = event.element.text
    configure_source_selector(gui_data)
end

---Handles destination selection search being changed
---@param event EventData.on_gui_text_changed
function EntityGui.process_destination_cluster_search(event)
    ---@type EntityGuiData
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.destination_cluster_query = event.element.text
    configure_destination_selector(gui_data)
end

---Handles source cluster selection being changed
---@param event EventData.on_gui_selection_state_changed
function EntityGui.process_source_cluster_selector(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end

    local entity = gui_data.entity
    local old_selection = EntityProcessor.get_source_template(entity)
    local element = event.element
    local new_selection = element.items[element.selected_index]
    ---@cast new_selection string|nil

    -- if selected item is clicked again, we want to unselect it
    if old_selection == new_selection then
        EntityProcessor.set_source_template(entity, nil)
        configure_source_selector(gui_data)
    else
        EntityProcessor.set_source_template(entity, new_selection)
    end
end

---Handles destination cluster selection being changed
---@param event EventData.on_gui_selection_state_changed
function EntityGui.process_destination_cluster_selector(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end

    local entity = gui_data.entity
    local old_selection = EntityProcessor.get_destination_template(entity)
    local element = event.element
    local new_selection = element.items[element.selected_index]
    ---@cast new_selection string|nil

    -- if selected item is clicked again, we want to unselect it
    if old_selection == new_selection then
        EntityProcessor.set_destination_template(entity, nil)
        configure_destination_selector(gui_data)
    else
        EntityProcessor.set_destination_template(entity, new_selection)
    end
end

-------------------------------------------------------------------------------
-- INFORMATION ELEMENTS
-------------------------------------------------------------------------------

---Adds a status display for virtualization mainframe
---@param parent LuaGuiElement section will be added here
---@param entity LuaEntity virtualization mainframe
local function create_mainframe_status_display(parent, entity)
    local status = EntityProcessor.get_mainframe_status(entity)
    local caption = {"", {"gui-label.entity-status"}, ": " , status}
    CommonGui.create_info_element_base(parent, caption)
end

---Adds section displaying current mainframe requests if there are any.
---@param parent LuaGuiElement section will be added here
---@param entity LuaEntity virtualization mainframe
local function create_mainframe_requests(parent, entity)
    local requests = EntityProcessor.get_construction_requests(entity)
    if not requests or not next(requests) then return end

    -- Collecting sprite button data 
    ---@type SpriteButtonData[]
    local buttons = {}
    for key, buffer in pairs(requests) do
        table.insert(
            buttons,
            CommonGui.assemble_sprite_button_data(key, buffer.count)
        )
    end

    local section = CommonGui.create_info_element_base(
        parent,
        {"gui-label.missing-construction-materials"}
    )
    CommonGui.create_sprite_button_table(section, buttons)
end

---Adds section displaying buildings contained in the mainframe.
---@param parent LuaGuiElement section will be added here
---@param entity LuaEntity virtualization mainframe
local function create_mainframe_building_contents(parent, entity)
    local contents = EntityProcessor.get_contained_buildings(entity)
    if not contents or not next(contents) then return end

    -- Collecting sprite button data 
    ---@type SpriteButtonData[]
    local buttons = {}
    for key, buffer in pairs(contents) do
        if buffer.count > 0 then
            table.insert(
                buttons,
                CommonGui.assemble_sprite_button_data(key, buffer.count)
            )
        end
    end

    local section = CommonGui.create_info_element_base(
        parent,
        {"gui-label.collected-construction-materials"}
    )
    CommonGui.create_sprite_button_table(section, buttons)
end

-------------------------------------------------------------------------------
-- GUI CONSTRUCTORS
-------------------------------------------------------------------------------

---Creates a base for entity gui and initializes the entity gui
---section in storage for given player. It's assumed that custom
---entity gui window is not opened when this is called.
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
---@return EntityGuiData
local function create_entity_gui_base(player, entity)
    -- initializing entity_gui storage for given player
    storage.entity_gui[player.index] = storage.entity_gui[player.index] or {}
    local gui_data = storage.entity_gui[player.index]
    gui_data.opened = true
    gui_data.player_index = player.index
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
    player.opened = main_window

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
    -- flow for vertical spacing
    local left_flow = left_frame.add{type = "flow", direction = "vertical"}
    left_flow.style.vertical_spacing = 8
    gui_data.elements.left_frame = left_flow

    -- right side of interface is for info display
    local right_frame = main_flow.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical"
    }

    local datafield = right_frame.add{type = "scroll-pane"}
    datafield.style.vertically_stretchable = true
    gui_data.elements.datafield = datafield
    GuiUpdater.register_gui("entity", gui_data, player.index)
    return gui_data
end

---Creates template item IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_item_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    create_choose_io_buttons(left_frame, gui_data)
    create_choose_item_button(left_frame, gui_data)
end

---Creates template fluid IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_fluid_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    create_choose_io_buttons(left_frame, gui_data)
    create_choose_fluid_button(left_frame, gui_data)
end

---Creates template energy IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_energy_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    create_choose_io_buttons(left_frame, gui_data)
end

---Used for time-based updates of cluster IO guis
function cluster_io_updater(gui_data)
    local entity = gui_data.entity
    local datafield = gui_data.elements.datafield
    datafield.clear()

    local cluster = EntityProcessor.get_cluster(entity)
    ClusterInfo.create_all_cluster_info(datafield, cluster)
end

---Creates cluster item IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_item_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    create_choose_io_buttons(left_frame, gui_data)
    create_template_selection_widget(left_frame, gui_data)
    create_choose_item_button(left_frame, gui_data)
end

---Creates cluster fluid IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_fluid_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    create_choose_io_buttons(left_frame, gui_data)
    create_template_selection_widget(left_frame, gui_data)
    create_choose_fluid_button(left_frame, gui_data)
end

---Creates cluster energy IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_energy_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    create_choose_io_buttons(left_frame, gui_data)
    create_template_selection_widget(left_frame, gui_data)
end

---Used for time-based updates of mainframe interface
function mainframe_updater(gui_data)
    local entity = gui_data.entity
    local datafield = gui_data.elements.datafield
    datafield.clear()

    create_mainframe_status_display(datafield, entity)
    create_mainframe_requests(datafield, entity)
    create_mainframe_building_contents(datafield, entity)

    local cluster = EntityProcessor.get_cluster(entity)
    ClusterInfo.create_all_cluster_info(datafield, cluster)
end

---Creates virtualization mainframe interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_virtualization_mainframe_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    create_template_selection_widget(left_frame, gui_data)
end

---Creates inter cluster bridge interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_inter_cluster_bridge_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    create_mode_selection_widget(left_frame, gui_data)
    create_choose_item_button(left_frame, gui_data)
    create_choose_fluid_button(left_frame, gui_data)
    create_cluster_selection_widget(left_frame, gui_data)
end

-------------------------------------------------------------------------------
-- OPEN/CLOSE ENTITY GUI
-------------------------------------------------------------------------------

---Maps entity names to functions used to construct their gui
local entity_gui_router = {
    [PREFIX .. "template-item-io-mk1"] = create_template_item_io_gui,
    [PREFIX .. "template-item-io-mk2"] = create_template_item_io_gui,
    [PREFIX .. "template-item-io-mk3"] = create_template_item_io_gui,
    [PREFIX .. "template-fluid-io-mk1"] = create_template_fluid_io_gui,
    [PREFIX .. "template-fluid-io-mk2"] = create_template_fluid_io_gui,
    [PREFIX .. "template-fluid-io-mk3"] = create_template_fluid_io_gui,
    [PREFIX .. "template-energy-io-mk1"] = create_template_energy_io_gui,
    [PREFIX .. "template-energy-io-mk2"] = create_template_energy_io_gui,
    [PREFIX .. "template-energy-io-mk3"] = create_template_energy_io_gui,
    [PREFIX .. "cluster-item-io-mk1"] = create_cluster_item_io_gui,
    [PREFIX .. "cluster-item-io-mk2"] = create_cluster_item_io_gui,
    [PREFIX .. "cluster-item-io-mk3"] = create_cluster_item_io_gui,
    [PREFIX .. "cluster-fluid-io-mk1"] = create_cluster_fluid_io_gui,
    [PREFIX .. "cluster-fluid-io-mk2"] = create_cluster_fluid_io_gui,
    [PREFIX .. "cluster-fluid-io-mk3"] = create_cluster_fluid_io_gui,
    [PREFIX .. "cluster-energy-io-mk1"] = create_cluster_energy_io_gui,
    [PREFIX .. "cluster-energy-io-mk2"] = create_cluster_energy_io_gui,
    [PREFIX .. "cluster-energy-io-mk3"] = create_cluster_energy_io_gui,
    [PREFIX .. "virtualization-mainframe-mk1"] = create_virtualization_mainframe_gui,
    [PREFIX .. "virtualization-mainframe-mk2"] = create_virtualization_mainframe_gui,
    [PREFIX .. "virtualization-mainframe-mk3"] = create_virtualization_mainframe_gui,
    [PREFIX .. "inter-cluster-bridge-mk1"] = create_inter_cluster_bridge_gui,
    [PREFIX .. "inter-cluster-bridge-mk2"] = create_inter_cluster_bridge_gui,
    [PREFIX .. "inter-cluster-bridge-mk3"] = create_inter_cluster_bridge_gui,
}

---Handles gui being opened by the player. If entity gui from the table above is
---opened, closes it's vanilla gui and opens a custom one.
---@param event EventData.on_gui_opened
function EntityGui.process_gui_opened(event)
    -- checking opened gui type
    if event.gui_type ~= defines.gui_type.entity then return end
    local entity = event.entity
    if not entity or not entity.valid then return end
    -- getting entity name (handling ghosts)
    local entity_name = entity.name
    if entity_name == "entity-ghost" then entity_name = entity.ghost_name end
    -- checking if we need to open a custom gui
    local handler = entity_gui_router[entity_name]
    if not handler then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    handler(player, entity)
end

---Closes the custom entity gui when player.opened changes from it to something else.
---@param event EventData.on_gui_closed
function EntityGui.process_entity_gui_closed(event)
    local player_idx = event.player_index
    local gui_data = storage.entity_gui[player_idx]
    gui_data.opened = nil
    gui_data.entity = nil
    gui_data.elements.main_window.destroy()
    gui_data.elements = nil
end

-------------------------------------------------------------------------------
-- TIME-BESED ENTITY GUI UPDATES
-------------------------------------------------------------------------------

---Maps entity names to functions used to update their gui
local gui_update_router = {
    [PREFIX .. "cluster-item-io-mk1"] = cluster_io_updater,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_io_updater,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_io_updater,
    [PREFIX .. "cluster-fluid-io-mk1"] = cluster_io_updater,
    [PREFIX .. "cluster-fluid-io-mk2"] = cluster_io_updater,
    [PREFIX .. "cluster-fluid-io-mk3"] = cluster_io_updater,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_io_updater,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_io_updater,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_io_updater,
    [PREFIX .. "virtualization-mainframe-mk1"] = mainframe_updater,
    [PREFIX .. "virtualization-mainframe-mk2"] = mainframe_updater,
    [PREFIX .. "virtualization-mainframe-mk3"] = mainframe_updater,
}

---Time-based updater for entity GUI window
---@param gui_data EntityGuiData
local function time_based_updater(gui_data)
    local entity = gui_data.entity
    -- closing window if entity became invalid
    if not entity or not entity.valid then
        close_opened_window(gui_data.player_index)
        return
    end

    local handler = gui_update_router[entity.name]
    if not handler then return end
    handler(gui_data)
end

GuiUpdater.add_schema("entity", time_based_updater)

return EntityGui