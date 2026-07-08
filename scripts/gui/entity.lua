-- Most entities added by this mod have custom guis.

-- Currently entities with custom gui are handled as follows:
-- When player opens an entity from this mod, we close vanilla gui and open ours.
-- For convenience internal name of gui window is the same for all entities. 
-- So basically it's always the same window, however elements displayed depend on entity.
-- All entity guis are composed of elements defined in "entity-elements.lua".
-- These elements are defined along with their handlers and have no more than 1 handler
-- per type of interaction with that element.

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
-- on_vsurface bool: true if entity is located on a vsurface
-- properties table: entity properties from entity registry or table that
--                   should be stored in entity.tags for ghosts
-- elements table[LuaGuiElement]: references to different buttons in gui (check entity-controls.lua)


local registry = require("scripts.entity.entity-registry")
local names = require("scripts.gui.names")
local common = require("scripts.gui.common")
local entity_controls = require("scripts.gui.entity-controls")
local entity_info = require("scripts.gui.entity-info")
local vcluster_info = require("scripts.gui.vcluster-info")
local misc = require("scripts.misc")

local Helper = {}

-- Adds data related to entity to gui_data
local function add_entity_data(gui_data, entity)
    gui_data.entity = entity
    -- checking if entity is on a vsurface
    if storage.v_surfaces[entity.surface_index] then
        gui_data.on_vsurface = true
    end
    -- getting name and "ghost status"
    local name, is_ghost = misc.get_entity_name(entity)
    gui_data.entity_name = name
    gui_data.is_ghost = is_ghost
    -- entity properties from registry or entity.tags if it's a ghost
    gui_data.properties = registry.get_entity_data(entity.unit_number) or {}
    local key = names.prefix
    if is_ghost and entity.tags and entity.tags[key] then
        gui_data.properties = entity.tags[key]
    end
end

-- key (string): entity name, value (localized string): title
local entity_gui_title = {
    [names.prefix .. "item-uplink"] = {"gui-title.item-uplink"},
    [names.prefix .. "item-downlink"] = {"gui-title.item-downlink"},
    [names.prefix .. "fluid-uplink"] = {"gui-title.fluid-uplink"},
    [names.prefix .. "fluid-downlink"] = {"gui-title.fluid-downlink"},
    [names.prefix .. "energy-uplink"] = {"gui-title.energy-uplink"},
    [names.prefix .. "energy-downlink"] = {"gui-title.energy-downlink"},
    [names.prefix .. "virtualization-mainframe"] = {"gui-title.virtualization-mainframe"},
}
-- Creates a base for entity gui and initializes the entity gui
-- section in storage for given player. It's assumed that custom
-- entity gui window is not opened when this is called.
-- @param player LuaPlayer: assumed to be valid
-- @param entity LuaEntity: assumed to be valid
-- @param title localized string: window title
local function entity_gui_base(player, entity)
    -- initializing entity_gui storage for given player
    storage.entity_gui[player.index] = {}
    local gui_data = storage.entity_gui[player.index]
    gui_data.elements = {}
    add_entity_data(gui_data, entity)

    -- creating base window and "opening" it
    local title = entity_gui_title[gui_data.entity_name]
    local main_window = common.gui_base_window(
        player,
        names.prefix .. names.entity_window,
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
        type="frame",
        direction="vertical",
        style="inside_shallow_frame_with_padding",
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

-- Updates udlink datafield. Displays vcluster information if
-- entity is connected to one. Does nothing otherwise
local function update_udlink_datafield(gui_data)
    local datafield = gui_data.elements.datafield
    local properties = gui_data.properties
    datafield.clear()
    local cluster = properties.cluster
    -- if not connected to clusted, does nothing
    if not cluster then return end
    vcluster_info.vcluster_input_buffer(datafield, cluster)
    vcluster_info.vcluster_output_buffer(datafield, cluster)
end

-- Gui for item uplink/downlink
local function item_udlink_gui(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    entity_controls.add_udlink_io_checkbox(left_frame, gui_data)
    entity_controls.add_template_selection_widget(left_frame, gui_data)
    entity_controls.add_udlink_choose_item_button(left_frame, gui_data)
    update_udlink_datafield(gui_data)
end

-- Gui for fluid uplink/downlink
local function fluid_udlink_gui(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    entity_controls.add_udlink_io_checkbox(left_frame, gui_data)
    entity_controls.add_template_selection_widget(left_frame, gui_data)
    entity_controls.add_udlink_choose_fluid_button(left_frame, gui_data)
    update_udlink_datafield(gui_data)
end

local function energy_udlink_gui(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    entity_controls.add_udlink_io_checkbox(left_frame, gui_data)
    entity_controls.add_template_selection_widget(left_frame, gui_data)
    update_udlink_datafield(gui_data)
end

-- Updates virtualization mainframe datafield
local function update_vmainframe_datafield(gui_data)
    local datafield = gui_data.elements.datafield
    local properties = gui_data.properties
    datafield.clear()
    entity_info.vmainframe_status_display(datafield, properties)
    entity_info.vmainframe_building_requests(datafield, properties)
    -- cluster info if connected to one
    local cluster = properties.cluster
    if not cluster then return end
    vcluster_info.vcluster_input_buffer(datafield, cluster)
    vcluster_info.vcluster_output_buffer(datafield, cluster)
    vcluster_info.vcluster_member_counts(datafield, cluster)
end

-- Creates custom gui for virtualization mainframe
local function vmainframe_gui(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    entity_controls.add_template_selection_widget(left_frame, gui_data)
    update_vmainframe_datafield(gui_data)
end

-- key (string): entity name, value (function): handler that creates gui
local entity_gui_router = {
    [names.prefix .. "item-uplink"] = item_udlink_gui,
    [names.prefix .. "item-downlink"] = item_udlink_gui,
    [names.prefix .. "fluid-uplink"] = fluid_udlink_gui,
    [names.prefix .. "fluid-downlink"] = fluid_udlink_gui,
    [names.prefix .. "energy-uplink"] = energy_udlink_gui,
    [names.prefix .. "energy-downlink"] = energy_udlink_gui,
    [names.prefix .. "virtualization-mainframe"] = vmainframe_gui,
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
    local entity_name = misc.get_entity_name(entity)
    -- checking if we need to open a custom gui
    local handler = entity_gui_router[entity_name]
    if not handler then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    handler(player, entity)
end)

local entity_datafield_router = {
    [names.prefix .. "item-uplink"] = update_udlink_datafield,
    [names.prefix .. "item-downlink"] = update_udlink_datafield,
    [names.prefix .. "fluid-uplink"] = update_udlink_datafield,
    [names.prefix .. "fluid-downlink"] = update_udlink_datafield,
    [names.prefix .. "energy-uplink"] = update_udlink_datafield,
    [names.prefix .. "energy-downlink"] = update_udlink_datafield,
    [names.prefix .. "virtualization-mainframe"] = update_vmainframe_datafield,
}
-- Time-based updater for entity gui datafields
function Helper.update_entity_gui_datafield()
    for _, gui_data in pairs(storage.entity_gui) do
        local entity = gui_data.entity
        if not entity or not entity.valid then goto continue end
        local handler = entity_datafield_router[entity.name]
        if not handler then goto continue end
        handler(gui_data)
        ::continue::
    end
end

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