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

local entity_registry = require("scripts.entity-registry")
local names = require("scripts.gui.names")
local common = require("scripts.gui.common")
local entity_elem = require("scripts.gui.entity-elements")
local misc = require("scripts.misc")

local Helper = {}

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
    -- creating base window and "opening" it
    local entity_name = misc.get_entity_name(entity)
    local title = entity_gui_title[entity_name]
    local main_frame = common.gui_base_window(
        player,
        names.prefix .. names.entity_window,
        title
    )
    player.opened = main_frame
    -- initializing entity_gui storage for given player
    storage.entity_gui[player.index] = {entity = entity}
    local gui_data = storage.entity_gui[player.index]
    gui_data.elements = {main_window = main_frame}
    gui_data.registry_data = entity_registry.get_entity_data(entity.unit_number)
    -- invisible container for other frames
    local main_flow = main_frame.add{
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

-- Gui for item uplink/downlink
local function item_udlink_gui(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    entity_elem.add_udlink_io_checkbox(left_frame, gui_data)
    entity_elem.add_template_selection_widget(left_frame, gui_data)
    entity_elem.add_udlink_choose_item_button(left_frame, gui_data)
end

-- Gui for fluid uplink/downlink
local function fluid_udlink_gui(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    entity_elem.add_udlink_io_checkbox(left_frame, gui_data)
    entity_elem.add_template_selection_widget(left_frame, gui_data)
    entity_elem.add_udlink_choose_fluid_button(left_frame, gui_data)
end

local function energy_udlink_gui(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    entity_elem.add_udlink_io_checkbox(left_frame, gui_data)
    entity_elem.add_template_selection_widget(left_frame, gui_data)
end

local function vmainframe_gui(player, entity)
    local gui_data = entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    entity_elem.add_template_selection_widget(left_frame, gui_data)
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