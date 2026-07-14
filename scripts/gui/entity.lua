


local common = require("scripts.gui.common")
local entity_processor = require("scripts.entity-processor")
local vcluster_info = require("scripts.gui.vcluster-info")
local misc = require("scripts.misc")

local Helper = {}

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







return Helper