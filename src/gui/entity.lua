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
---@field left_frame LuaGuiElement Left column for controls
---@field datafield LuaGuiElement Right column for information display
---@field input_radiobutton LuaGuiElement|nil used for changing IO mode for entities that support it
---@field output_radiobutton LuaGuiElement|nil used for changing IO mode for entities that support it
---@field first_template_selector LuaGuiElement|nil
---@field first_template_search LuaGuiElement|nil
---@field second_template_selector LuaGuiElement|nil
---@field second_template_search LuaGuiElement|nil
---@field choose_item_button LuaGuiElement|nil
---@field choose_fluid_button LuaGuiElement|nil EntityWithFluidSelection
---@field item_mode_radiobutton LuaGuiElement|nil
---@field fluid_mode_radiobutton LuaGuiElement|nil
---@field energy_mode_radiobutton LuaGuiElement|nil

---Table describing entity GUI state
---@class EntityGuiData: GuiDataBase
---@field entity LuaEntity entity that was opened to create this gui
---@field entity_name string name of this entity or ghost-entity
---@field player_index number unique player identifier
---@field first_template_query string|nil user input into first template search
---@field second_template_query string|nil user input into second template search
---@field elements EntityGuiElements|nil

local CommonGui = require("src.gui.common")
local EntityControls = require("src.gui.entity-controls")
local GuiUpdater = require("src.gui.updater")
local EntityInfo = require("src.gui.entity-info")

local PREFIX = "FV-"
local EntityGui = {}

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
    local player_index = player.index
    storage.entity_gui[player_index] = storage.entity_gui[player.index] or {}
    local gui_data = storage.entity_gui[player_index]
    gui_data.opened = true
    gui_data.entity = entity
    local entity_name = entity.name
    if entity_name == "entity-ghost" then entity_name = entity.ghost_name end
    gui_data.entity_name = entity_name
    gui_data.player_index = player_index
    gui_data.elements = {}

    -- creating base window
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
    -- datafield.style.minimal_width = 
    datafield.style.vertically_stretchable = true
    gui_data.elements.datafield = datafield
    GuiUpdater.register_gui("entity", gui_data, player_index)
    return gui_data
end

---Creates template item IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_item_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    EntityControls.create_choose_io_buttons(left_frame, gui_data)
    EntityControls.create_choose_item_button(left_frame, gui_data)
end

---Creates template fluid IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_fluid_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    EntityControls.create_choose_io_buttons(left_frame, gui_data)
    EntityControls.create_choose_fluid_button(left_frame, gui_data)
end

---Creates template energy IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_template_energy_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    EntityControls.create_choose_io_buttons(left_frame, gui_data)
end

---Creates cluster item IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_item_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    EntityControls.create_choose_io_buttons(left_frame, gui_data)
    EntityControls.create_choose_item_button(left_frame, gui_data)
    EntityControls.create_first_template_selection_widget(
        left_frame,
        gui_data,
        {"gui-label.select-template"}
    )
end

---Creates cluster fluid IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_fluid_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    EntityControls.create_choose_io_buttons(left_frame, gui_data)
    EntityControls.create_choose_fluid_button(left_frame, gui_data)
    EntityControls.create_first_template_selection_widget(
        left_frame,
        gui_data,
        {"gui-label.select-template"}
    )
end

---Creates cluster energy IO interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_cluster_energy_io_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    EntityControls.create_choose_io_buttons(left_frame, gui_data)
    EntityControls.create_first_template_selection_widget(
        left_frame,
        gui_data,
        {"gui-label.select-template"}
    )
end

---Creates virtualization mainframe interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_virtualization_mainframe_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    EntityControls.create_first_template_selection_widget(
        left_frame,
        gui_data,
        {"gui-label.select-template"}
    )
end

---Creates inter-cluster bridge interface
---@param player LuaPlayer assumed to be valid
---@param entity LuaEntity assumed to be valid
local function create_inter_cluster_bridge_gui(player, entity)
    local gui_data = create_entity_gui_base(player, entity)
    local left_frame = gui_data.elements.left_frame
    EntityControls.create_mode_selection_widget(left_frame, gui_data)
    EntityControls.create_choose_item_button(left_frame, gui_data)
    EntityControls.create_choose_fluid_button(left_frame, gui_data)
    EntityControls.create_first_template_selection_widget(
        left_frame,
        gui_data,
        {"gui-label.select-source-cluster"}
    )
    EntityControls.create_second_template_selection_widget(
        left_frame,
        gui_data,
        {"gui-label.select-destination-cluster"}
    )
end

-------------------------------------------------------------------------------
-- OPEN/CLOSE ENTITY GUI
-------------------------------------------------------------------------------

---Maps entity names to functions used to construct their GUIs
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

---Handles gui being opened by the player. If entity from the table above is
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
    if not player then return end
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

---Used for time-based updates of template IO GUIs
---@param gui_data EntityGuiData
local function update_template_io_datafield(gui_data)
    local entity = gui_data.entity
    local datafield = gui_data.elements.datafield
    datafield.clear()

    EntityInfo.create_entity_status_display(datafield, entity)
    EntityInfo.create_last_second_flow_display(datafield, entity)
end

---Used for time-based updates of cluster IO GUIs
---@param gui_data EntityGuiData
local function update_cluster_io_datafield(gui_data)
    local entity = gui_data.entity
    local datafield = gui_data.elements.datafield
    datafield.clear()

    EntityInfo.create_entity_status_display(datafield, entity)
    EntityInfo.create_last_second_flow_display(datafield, entity)
    EntityInfo.create_cluster_information_display(datafield, entity)
end

---Used for time-based updates of mainframe GUIs
---@param gui_data EntityGuiData
local function update_virtualization_mainframe_datafield(gui_data)
    local entity = gui_data.entity
    local datafield = gui_data.elements.datafield
    datafield.clear()

    EntityInfo.create_entity_status_display(datafield, entity)
    EntityInfo.create_mainframe_construction_requests(datafield, entity)
    EntityInfo.create_mainframe_contained_buildings(datafield, entity)
    EntityInfo.create_cluster_information_display(datafield, entity)
end

---Used for time-based updates of inter-cluster bridge GUIs
---@param gui_data EntityGuiData
local function update_inter_cluster_bridge_datafield(gui_data)
    local entity = gui_data.entity
    local datafield = gui_data.elements.datafield
    datafield.clear()

    EntityInfo.create_entity_status_display(datafield, entity)
    EntityInfo.create_last_second_flow_display(datafield, entity)
    EntityInfo.create_inter_cluster_bridge_display(datafield, entity)
end

---Maps entity names to functions used to update their GUIs
local gui_update_router = {
    [PREFIX .. "template-item-io-mk1"] = update_template_io_datafield,
    [PREFIX .. "template-item-io-mk2"] = update_template_io_datafield,
    [PREFIX .. "template-item-io-mk3"] = update_template_io_datafield,
    [PREFIX .. "template-fluid-io-mk1"] = update_template_io_datafield,
    [PREFIX .. "template-fluid-io-mk2"] = update_template_io_datafield,
    [PREFIX .. "template-fluid-io-mk3"] = update_template_io_datafield,
    [PREFIX .. "template-energy-io-mk1"] = update_template_io_datafield,
    [PREFIX .. "template-energy-io-mk2"] = update_template_io_datafield,
    [PREFIX .. "template-energy-io-mk3"] = update_template_io_datafield,
    [PREFIX .. "cluster-item-io-mk1"] = update_cluster_io_datafield,
    [PREFIX .. "cluster-item-io-mk2"] = update_cluster_io_datafield,
    [PREFIX .. "cluster-item-io-mk3"] = update_cluster_io_datafield,
    [PREFIX .. "cluster-fluid-io-mk1"] = update_cluster_io_datafield,
    [PREFIX .. "cluster-fluid-io-mk2"] = update_cluster_io_datafield,
    [PREFIX .. "cluster-fluid-io-mk3"] = update_cluster_io_datafield,
    [PREFIX .. "cluster-energy-io-mk1"] = update_cluster_io_datafield,
    [PREFIX .. "cluster-energy-io-mk2"] = update_cluster_io_datafield,
    [PREFIX .. "cluster-energy-io-mk3"] = update_cluster_io_datafield,
    [PREFIX .. "virtualization-mainframe-mk1"] = update_virtualization_mainframe_datafield,
    [PREFIX .. "virtualization-mainframe-mk2"] = update_virtualization_mainframe_datafield,
    [PREFIX .. "virtualization-mainframe-mk3"] = update_virtualization_mainframe_datafield,
    [PREFIX .. "inter-cluster-bridge-mk1"] = update_inter_cluster_bridge_datafield,
    [PREFIX .. "inter-cluster-bridge-mk2"] = update_inter_cluster_bridge_datafield,
    [PREFIX .. "inter-cluster-bridge-mk3"] = update_inter_cluster_bridge_datafield,
}

---Time-based updater for entity GUI window
---@param gui_data EntityGuiData
local function time_based_updater(gui_data)
    -- closing window if entity became invalid
    local player_index = gui_data.player_index
    local status = EntityControls.assert_entity_validity(player_index, gui_data)
    if not status then return end

    -- picking the right handler for entity
    local entity_name = gui_data.entity_name
    local handler = gui_update_router[entity_name]
    if not handler then return end
    handler(gui_data)
end

GuiUpdater.add_schema("entity", time_based_updater)

return EntityGui