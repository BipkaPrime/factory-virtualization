


local common = require("scripts.gui.common")
local entity_processor = require("scripts.entity-processor")
local vcluster_info = require("scripts.gui.vcluster-info")
local misc = require("scripts.misc")

local Helper = {}


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