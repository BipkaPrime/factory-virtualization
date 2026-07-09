-- Most entities added by this mod have custom guis.

-- Currently entities with custom gui are handled as follows:
-- When player opens an entity from this mod, we close vanilla gui and open ours.
-- For convenience internal name of gui window is the same for all entities. 
-- So basically it's always the same window, however elements displayed depend on entity.

-- For convenience created elements are saved to storage to storage.entity_gui[player_index]
-- This way they can be accessed easily without the need for traversal of the gui tree.
-- This table also contains important data like reference to opened entity, registry data, etc.
-- When gui is closed, this table is deleted.

-- This gui also works for ghost-entity. In this case user inputs are saved in entity tags
-- instead of entity registry. They will be processed and added to registry when entity is built.

--------------------------------------------------------------------------------------------
-- STORAGE KEYS FOR CONVENIENCE
--------------------------------------------------------------------------------------------
-- table = storage.entity_gui[player_index]. table keys:
-- entity LuaEntity: opened entity object
-- entity_name string: name of entity or ghost
-- is_ghost bool: true if entity is a ghost
-- properties table: entity properties from entity registry or table that
--                   should be stored in entity.tags for ghosts
-- template_search_query string: user input into textfield above template selector
-- elements.template_selector LuaGuiElement: reference to template selector
-- elements.template_selector_label LuaGuiElement: reference to template selector label
-- elements.template_search LuaGuiElement: reference to template searchfield
-- elements.choose_item_button LuaGuiElement: reference to choose item button
-- elements.choose_fluid_button LuaGuiElement: reference to choose fluid button
-- elements.input_radiobutton LuaGuiElement: reference to input radiobutton
-- elements.output_radiobutton LuaGuiElement: reference to output radiobutton
-- elements.main_window LuaGuiElement: reference to main entity gui window
-- elements.datafield LuaGuiElement: reference to datafield on the right side of interface
-- elements.left_frame LuaGuiElement: reference to left frame of interface


local common = require("scripts.gui.common")
local entity_processor = require("scripts.entity-processor")
local vcluster_info = require("scripts.gui.vcluster-info")
local misc = require("scripts.misc")

local Helper = {}

-------------------------------------------------------------------------------
-- ENTITY CONTROLS: ELEMENTS THAT EXPECT USER INPUT
-------------------------------------------------------------------------------

-- There are 3 functions that should be defined for each element.
-- First function to add element to gui, second function to configure it
-- according to "gui_data" third function is to handle player interfaction with the element.

-- All create element and update element functions assume that entity is valid.
-- Entity validity must be checked before calling them (in handlers and before gui creation)

-- Closes whatever is opened for a given player
local function close_opened_window(player_index)
    local player = game.get_player(player_index)
    if not player or not player.valid then return end
    player.opened = nil
end

-- Standart check performed before handling any user inputs
-- Checks that gui_data exists and entity is valid
-- If any check fails, the window is closed (player.opened is set to nil)
-- @returns bool: true if everything is ok
local function assert_entity_validity(player_index, gui_data)
    -- checking that gui_data exists
    if not gui_data then
        close_opened_window(player_index)
        return false
    end
    -- checking that entity is valid
    local entity = gui_data.entity
    if not entity or not entity.valid then
        close_opened_window(player_index)
        return false
    end
    return true
end

-- Updates table in entity tags with gui_data.properties 
-- Does nothing if entity is not a ghost. Entity is assumed to be valid.
local function update_entity_tags(gui_data)
    if not gui_data.is_ghost then return end
    local key = PREFIX
    local entity = gui_data.entity
    local tags = entity.tags or {}
    tags[key] = gui_data.properties
    entity.tags = tags
end

-- Configures only template selector. Used for handling search.
local function configure_template_selector(gui_data)
    local selector = gui_data.elements.template_selector
    local query = gui_data.template_search_query
    local properties = gui_data.properties
    local options = misc.get_all_templates()
    local selected = properties.selected_template
    common.arrange_selector(selector, options, query, selected)
end

-- Configures template selector as well as searchbox and label above 
local function configure_template_selection_widget(gui_data)
    local label = gui_data.elements.template_selector_label
    local search = gui_data.elements.template_search
    -- setting searchbox text and label caption
    search.text = gui_data.template_search_query or ""
    label.caption = {"gui-label.select-template"}
    configure_template_selector(gui_data)
end

-- Adds and configures template selection widget that consists of
-- title, searchbox and selector element
local function add_template_selection_widget(parent, gui_data)
    local search, selector, label = common.selection_widget(
        parent,
        PREFIX .. "entity-template-search",
        PREFIX .. "entity-template-selector"
    )
    gui_data.elements.template_search = search
    gui_data.elements.template_selector = selector
    gui_data.elements.template_selector_label = label
    configure_template_selection_widget(gui_data)
end

-- Handles template name search query being changed
-- Used when on_gui_text_changed event is triggered
function Helper.process_template_searchfield(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.template_search_query = event.element.text
    configure_template_selector(gui_data)
end

-- Handles template selector being changed
-- Used when on_gui_selection_state_changed event is triggered
function Helper.process_template_selector(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    local properties = gui_data.properties
    local element = event.element
    local old_selection = properties.selected_template
    local new_selection = element.items[element.selected_index]
    -- if selected item is clicked again, we want to unselect it
    if old_selection == new_selection then
        properties.selected_template = nil
        configure_template_selector(gui_data)
    else
        properties.selected_template = new_selection
    end
    update_entity_tags(gui_data)
end

local function configure_choose_item_button(gui_data)
    local button = gui_data.elements.choose_item_button
    -- setting chosen element according to entity properties
    local properties = gui_data.properties
    if properties.selected_item then
        local item = properties.selected_item
        button.elem_value = {
            name = item.name,
            quality = item.quality,
        }
    end
end

-- Adds choose elem button with type "item-with-quality"
local function add_choose_item_button(parent, gui_data)
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

-- Handles choose item button being changed 
-- Used when on_gui_elem_changed event is triggered
function Helper.process_choose_item_button(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    -- saving selection to entity properties
    local properties = gui_data.properties
    local item = event.element.elem_value
    if item then
        properties.selected_item = {
            name = item.name,
            quality = item.quality
        }
    else
        properties.selected_item = nil
    end
    update_entity_tags(gui_data)
end

local function configure_choose_fluid_button(gui_data)
    local button = gui_data.elements.udlink_choose_fluid_button
    -- setting selected fluid according to entity properties
    local properties = gui_data.properties
    if properties.selected_fluid then
        local fluid = properties.selected_fluid
        button.elem_value = fluid
    end
end

-- Adds choose elem button with type "fluid"
local function add_choose_fluid_button(parent, gui_data)
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

-- Handles choose fluid button being changed
-- Used when on_gui_elem_changed event is triggered
function Helper.process_choose_fluid_button(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    -- saving selection to entity properties
    local properties = gui_data.properties
    local fluid_name = event.element.elem_value
    if fluid_name then
        properties.selected_fluid = fluid_name
    else
        properties.selected_fluid = nil
    end
    update_entity_tags(gui_data)
end

local function configure_choose_io_buttons(gui_data)
    local input_button = gui_data.elements.input_radiobutton
    local output_button = gui_data.elements.output_radiobutton
    local properties = gui_data.properties
    if properties.is_output then
        input_button.state = false
        output_button.state = true
    else
        input_button.state = true
        output_button.state = false
    end
end

-- Adds 2 radiobuttons to choose IO mode of operation 
local function add_choose_io_buttons(parent, gui_data)
    local main_flow = parent.add{type = "flow", direction = "vertical"}
    main_flow.add{type = "label", caption = {"gui-label.operation-mode"}}
    main_flow.style.bottom_margin = 12

    -- input radiobutton 
    local row1 = main_flow.add{type = "flow", "horizontal"}
    row1.style.vertical_align = "center"
    local button1 = row1.add{
        type = "radiobutton",
        name = PREFIX .. "input-radiobutton",
        state = false
    }
    row1.add{type = "label", caption = {"gui-label.input"}}
    gui_data.elements.input_radiobutton = button1

    -- output radiobutton 
    local row2 = main_flow.add{type = "flow", "horizontal"}
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

-- Handles input radiobutton being pressed
function Helper.process_input_chosen(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    -- saving selection to entity properties
    local properties = gui_data.properties
    properties.is_output = nil
    configure_choose_io_buttons(gui_data)
    update_entity_tags(gui_data)
end

-- Handles output radiobutton being pressed
function Helper.process_output_chosen(event)
    local gui_data = storage.entity_gui[event.player_index]
    local status = assert_entity_validity(event.player_index, gui_data)
    if not status then return end
    -- saving selection to entity properties
    local properties = gui_data.properties
    properties.is_output = true
    configure_choose_io_buttons(gui_data)
    update_entity_tags(gui_data)
end

-------------------------------------------------------------------------------
-- ENTITY INFO ELEMENTS: THESE DO NOT EXPECT USER INPUT
-------------------------------------------------------------------------------

-- converts table containing items in the 2-level hmap format of:
-- "table[item_name][quality_name] = count" to displayable format
-- of array of {type, name, count, quality}.
local function collect_item_table(input_table)
    local result = {}
    if not input_table then return result end
    for name, q_counts in pairs(input_table) do
        for quality, count in pairs(q_counts) do
            local data = {
                type = "item",
                name = name,
                count = count,
                quality = quality
            }
            table.insert(result, data)
        end
    end
    return result
end

-- Adds a status display for virtualization mainframe
local function vmainframe_status_display(parent, properties)
    local section = common.info_element_base(parent, "VMAINFRAME INFO DISPLAY")
    local status = "STATUS: TEMPLATE NOT SELECTED"
    if properties.operational then
        status = "STATUS: OPERATIONAL"
    elseif properties.active_template then
        status = "STATUS: REQUESTING CONSTRUCTION MATERIALS"
    end
    common.add_bold_label(section, status)
end

-- Collects building requests of a given vmainframe
local function get_vmainframe_requests(reg_data)
    if not reg_data.building_requests then return {} end
    local requests = reg_data.building_requests
    return collect_item_table(requests)
end

local function vmainframe_building_requests(parent, reg_data)
    local section = common.info_element_base(parent, "MISSING CONSTRUCTION MATERIALS")
    local requests = get_vmainframe_requests(reg_data)
    common.sprite_button_panel(section, requests)
end

-------------------------------------------------------------------------------
-- BASE ENTITY GUI WINDOW
-------------------------------------------------------------------------------

-- Gets the name of a a given entity or ghost-entity assuming it's valid
-- @returns string: name of given entity or ghost-entity
-- @returns bool: true if entity is a ghost
local function get_entity_name(entity)
    local entity_name = entity.name
    local is_ghost = false
    if entity_name == "entity-ghost" then
        entity_name = entity.ghost_name
        is_ghost = true
    end
    return entity_name, is_ghost
end

-- Creates a base for entity gui and initializes the entity gui
-- section in storage for given player. It's assumed that custom
-- entity gui window is not opened when this is called.
-- @param player LuaPlayer: assumed to be valid
-- @param entity LuaEntity: assumed to be valid
local function entity_gui_base(player, entity)
    -- initializing entity_gui storage for given player
    storage.entity_gui[player.index] = {}
    local gui_data = storage.entity_gui[player.index]
    gui_data.elements = {}
    gui_data.entity = entity
    gui_data.entity_name, gui_data.is_ghost = get_entity_name(entity)
    gui_data.properties = entity_processor.get_entity_data(entity.unit_number) or {}
    if gui_data.is_ghost and entity.tags and entity.tags[PREFIX] then
        gui_data.properties = entity.tags[PREFIX]
    end

    -- creating base window and "opening" it
    local title = {"entity-name." .. gui_data.entity_name}
    local main_window = common.gui_base_window(
        player,
        PREFIX .. "entity-window",
        title
    )
    player.opened = main_window
    gui_data.elements.main_window = main_window
    main_window.style.height = 500

    -- invisible container for other frames
    local main_flow = main_window.add{
        type="flow",
        direction="horizontal",
    }

    -- left half of interface is for controls
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

-------------------------------------------------------------------------------
-- TIME-BASED ENTITY GUI UPDATES
-------------------------------------------------------------------------------


local function add_all_vcluster_info(parent, vcluster)
    if not vcluster then return end
    vcluster_info.input_buffer(parent, vcluster)
    vcluster_info.output_buffer(parent, vcluster)
    vcluster_info.member_counts(parent, vcluster)
end

local function vmainframe_updater(gui_data)
    local datafield = gui_data.elements.datafield
    local properties = gui_data.properties
    local cluster = properties.cluster
    datafield.clear()
    vmainframe_status_display(datafield, properties)
    vmainframe_building_requests(datafield, properties)
    add_all_vcluster_info(datafield, cluster)
end

local function mainframe_io_updater(gui_data)
    local datafield = gui_data.elements.datafield
    local properties = gui_data.properties
    local cluster = properties.cluster
    add_all_vcluster_info(datafield, cluster)
end

-- key (string): entity name, value (function): handler that updates entity gui
local gui_update_router = {
    [PREFIX .. "mainframe-item-io"] = mainframe_io_updater,
    [PREFIX .. "mainframe-fluid-io"] = mainframe_io_updater,
    [PREFIX .. "mainframe-energy-io"] = mainframe_io_updater,
    [PREFIX .. "virtualization-mainframe"] = vmainframe_updater,
}
-- Time-based updater for entity GUIs
function Helper.update_entity_gui()
    for player_index, gui_data in pairs(storage.entity_gui) do
        local entity = gui_data.entity
        if not entity or not entity.valid then
            close_opened_window(player_index)
            goto continue
        end
        local handler = gui_update_router[entity.name]
        if not handler then goto continue end
        handler(gui_data)
        ::continue::
    end
end

-------------------------------------------------------------------------------
-- OPEN/CLOSE ENTITY GUI
-------------------------------------------------------------------------------

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

-- key (string): entity name, value (function): handler that creates gui
local entity_gui_router = {
    [PREFIX .. "template-item-io"] = template_item_io,
    [PREFIX .. "template-fluid-io"] = template_fluid_io,
    [PREFIX .. "template-energy-io"] = template_energy_io,
    [PREFIX .. "mainframe-item-io"] = mainframe_item_io,
    [PREFIX .. "mainframe-fluid-io"] = mainframe_fluid_io,
    [PREFIX .. "mainframe-energy-io"] = mainframe_energy_io,
    [PREFIX .. "virtualization-mainframe"] = virtualization_mainframe,
}
-- Handles entity gui being opened. If entity from the table above is
-- opened, closes it's vanilla gui and opens a custom one.
script.on_event(defines.events.on_gui_opened, function(event)
    -- checking opened gui type
    if event.gui_type ~= defines.gui_type.entity then return end
    -- checking entity validity
    local entity = event.entity
    if not entity or not entity.valid then return end
    -- getting entity name (handling ghosts)
    local entity_name = get_entity_name(entity)
    -- checking if we need to open a custom gui
    local handler = entity_gui_router[entity_name]
    if not handler then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    handler(player, entity)
end)

-- Closes the custom entity gui when player.opened changes.
-- Used when on_gui_closed event is triggered
function Helper.process_entity_gui_closed(event)
    local gui_data = storage.entity_gui[event.player_index]
    gui_data.elements.main_window.destroy()
    storage.entity_gui[event.player_index] = nil
end

-- After player changes surface with entity gui opened
-- player.opened can be assigned nil with window still opened
-- So if window should be opened, we set player.opened to it.
function Helper.process_player_changed_surface(event)
    local gui_data = storage.entity_gui[event.player_index]
    if not gui_data then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    player.opened = gui_data.elements.main_window
end

return Helper