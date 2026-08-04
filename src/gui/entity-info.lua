--[[
This file helps in creation of entity GUIs. It creates information elements for 
given entity. It works directly (read only) with entity properties from registry.
--]]

local EntityProcessor = require("src.world.entity-processor")
local CommonGui = require("src.gui.common")
local ClusterInfo = require("src.gui.cluster-info")
local VSurfaceManager = require("src.world.vsurface-manager")


local EntityInfo = {}
local PREFIX = "FV-"

-------------------------------------------------------------------------------
-- ENTITY STATUS DISPLAY
-------------------------------------------------------------------------------

---Decides cluster energy IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_cluster_energy_io_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        return {"entity-status.operational"}
    end
    -- entity does not work on a vsurface
    if VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- cluster is not selected
    if not properties.first_template then
        return {"entity-status.cluster-not-selected"}
    end
    -- io mode is not selected
    if not properties.io_mode then
        return {"entity-status.io-mode-not-selected"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.unable-to-connect-to-cluster"}
    end
    -- selected buffer entry does not exist
    if not properties.first_buffer_entry then
        return {"entity-status.buffer-entry-not-found"}
    end
end

---Decides cluster fluid IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_cluster_fluid_io_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        return {"entity-status.operational"}
    end
    -- entity does not work on a vsurface
    if VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- cluster is not selected
    if not properties.first_template then
        return {"entity-status.cluster-not-selected"}
    end
    -- io mode is not selected
    if not properties.io_mode then
        return {"entity-status.io-mode-not-selected"}
    end
    -- fluid is not selected
    if not properties.selected_fluid then
        return {"entity-status.fluid-not-selected"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.unable-to-connect-to-cluster"}
    end
    -- selected buffer entry does not exist
    if not properties.first_buffer_entry then
        return {"entity-status.buffer-entry-not-found"}
    end
end

---Decides cluster item IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_cluster_item_io_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        return {"entity-status.operational"}
    end
    -- entity does not work on a vsurface
    if VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- cluster is not selected
    if not properties.first_template then
        return {"entity-status.cluster-not-selected"}
    end
    -- io mode is not selected
    if not properties.io_mode then
        return {"entity-status.io-mode-not-selected"}
    end
    -- item is not selected
    if not properties.selected_item then
        return {"entity-status.item-not-selected"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.unable-to-connect-to-cluster"}
    end
    -- selected buffer entry does not exist
    if not properties.first_buffer_entry then
        return {"entity-status.buffer-entry-not-found"}
    end
end

---Decides cluster overflow controller status based on its properties
---@param properties EntityProperties table from entity registry
local function get_cluster_overflow_controller_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        return {"entity-status.operational"}
    end
    -- entity does not work on a vsurface
    if VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- cluster is not selected
    if not properties.first_template then
        return {"entity-status.cluster-not-selected"}
    end
    -- operation mode is not selected
    local operation_mode = properties.operation_mode
    if not operation_mode then
        return {"entity-status.operation-mode-not-selected"}
    end
    -- item is not selected in "item" operation mode
    if operation_mode == "item" and not properties.selected_item then
        return {"entity-status.item-not-selected"}
    end
    -- fluid is not selected in "fluid" operation mode
    if operation_mode == "fluid" and not properties.selected_fluid then
        return {"entity-status.fluid-not-selected"}
    end
    -- overflow threshold is not selected
    if not properties.overflow_threshold then
        return {"entity-status.overflow-threshold-not-selected"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.unable-to-connect-to-cluster"}
    end
    -- selected buffer entry does not exist
    if not properties.first_buffer_entry then
        return {"entity-status.buffer-entry-not-found"}
    end
end

---Decides cluster storage unit status based on its properties
---@param properties EntityProperties table from entity registry
local function get_cluster_storage_unit_status(properties)
    -- entity is initialized
    if properties.initialized then
        if properties.operational then
            return {"entity-status.providing-storage-capacity"}
        else
            return {"entity-status.not-enough-energy"}
        end
    end
    -- entity does not work on a vsurface
    if VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- cluster is not selected
    if not properties.first_template then
        return {"entity-status.cluster-not-selected"}
    end
    -- io mode is not selected
    if not properties.io_mode then
        return {"entity-status.io-mode-not-selected"}
    end
    -- operation mode is not selected
    local operation_mode = properties.operation_mode
    if not operation_mode then
        return {"entity-status.operation-mode-not-selected"}
    end
    -- item is not selected in "item" operation mode
    if operation_mode == "item" and not properties.selected_item then
        return {"entity-status.item-not-selected"}
    end
    -- fluid is not selected in "fluid" operation mode
    if operation_mode == "fluid" and not properties.selected_fluid then
        return {"entity-status.fluid-not-selected"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.unable-to-connect-to-cluster"}
    end
    -- selected buffer entry does not exist
    if not properties.first_buffer_entry then
        return {"entity-status.buffer-entry-not-found"}
    end
end

---Decides inter-cluster bridge statusbased on its properties
---@param properties EntityProperties table from entity registry
local function get_inter_cluster_bridge_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        return {"entity-status.operational"}
    end
    -- entity does not work on a vsurface
    if VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- source cluster is not selected
    if not properties.first_template then
        return {"entity-status.source-cluster-not-selected"}
    end
    -- destination cluster is not selected
    if not properties.second_template then
        return {"entity-status.destination-cluster-not-selected"}
    end
    -- operation mode is not selected
    local operation_mode = properties.operation_mode
    if not operation_mode then
        return {"entity-status.operation-mode-not-selected"}
    end
    -- item is not selected in "item" operation mode
    if operation_mode == "item" and not properties.selected_item then
        return {"entity-status.item-not-selected"}
    end
    -- fluid is not selected in "fluid" operation mode
    if operation_mode == "fluid" and not properties.selected_fluid then
        return {"entity-status.fluid-not-selected"}
    end
    -- entity is not connected to source cluster
    if not properties.first_cluster then
        return {"entity-status.unable-to-connect-to-source-cluster"}
    end
    -- entity is not connected to destination cluster
    if not properties.second_cluster then
        return {"entity-status.unable-to-connect-to-destination-cluster"}
    end
    -- selected buffer entry does not exist in source cluster
    if not properties.first_buffer_entry then
        return {"entity-status.buffer-entry-not-found-source"}
    end
    -- selected buffer entry does not exist in destination cluster
    if not properties.second_buffer_entry then
        return {"entity-status.buffer-entry-not-found-destination"}
    end
end

---Decides template energy IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_template_energy_io_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        return {"entity-status.operational"}
    end
    -- entity works only on a vsurface
    if not VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.works-only-on-vsurface"}
    end
    -- io mode is not selected
    if not properties.io_mode then
        return {"entity-status.io-mode-not-selected"}
    end
end

---Decides template fluid IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_template_fluid_io_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        return {"entity-status.operational"}
    end
    -- entity works only on a vsurface
    if not VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.works-only-on-vsurface"}
    end
    -- io mode is not selected
    if not properties.io_mode then
        return {"entity-status.io-mode-not-selected"}
    end
    -- fluid is not selected
    if not properties.selected_fluid then
        return {"entity-status.fluid-not-selected"}
    end
end

---Decides template item IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_template_item_io_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        return {"entity-status.operational"}
    end
    -- entity works only on a vsurface
    if not VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.works-only-on-vsurface"}
    end
    -- io mode is not selected
    if not properties.io_mode then
        return {"entity-status.io-mode-not-selected"}
    end
    -- item is not selected
    if not properties.selected_item then
        return {"entity-status.item-not-selected"}
    end
end

---Decides virtualization mainframe status based on its properties
---@param properties EntityProperties table from entity registry
local function get_virtualization_mainframe_status(properties)
    -- entity is initialized and operational
    if properties.initialized then
        if properties.operational then
            return {"entity-status.providing-crafting-power"}
        else
            return {"entity-status.requesting-construction-materials"}
        end
    end
    -- entity does not work on a vsurface
    if VSurfaceManager.get_vsurface_data(properties.entity.surface_index) then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- cluster is not selected
    if not properties.first_template then
        return {"entity-status.cluster-not-selected"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.unable-to-connect-to-cluster"}
    end
end

---Maps entity names to functions that can get their status
local status_router = {
    [PREFIX .. "cluster-energy-io-mk1"] = get_cluster_energy_io_status,
    [PREFIX .. "cluster-energy-io-mk2"] = get_cluster_energy_io_status,
    [PREFIX .. "cluster-energy-io-mk3"] = get_cluster_energy_io_status,
    [PREFIX .. "cluster-fluid-io-mk1"] = get_cluster_fluid_io_status,
    [PREFIX .. "cluster-fluid-io-mk2"] = get_cluster_fluid_io_status,
    [PREFIX .. "cluster-fluid-io-mk3"] = get_cluster_fluid_io_status,
    [PREFIX .. "cluster-item-io-mk1"] = get_cluster_item_io_status,
    [PREFIX .. "cluster-item-io-mk2"] = get_cluster_item_io_status,
    [PREFIX .. "cluster-item-io-mk3"] = get_cluster_item_io_status,
    [PREFIX .. "cluster-overflow-controller-mk1"] = get_cluster_overflow_controller_status,
    [PREFIX .. "cluster-overflow-controller-mk2"] = get_cluster_overflow_controller_status,
    [PREFIX .. "cluster-overflow-controller-mk3"] = get_cluster_overflow_controller_status,
    [PREFIX .. "cluster-storage-unit-mk1"] = get_cluster_storage_unit_status,
    [PREFIX .. "cluster-storage-unit-mk2"] = get_cluster_storage_unit_status,
    [PREFIX .. "cluster-storage-unit-mk3"] = get_cluster_storage_unit_status,
    [PREFIX .. "inter-cluster-bridge-mk1"] = get_inter_cluster_bridge_status,
    [PREFIX .. "inter-cluster-bridge-mk2"] = get_inter_cluster_bridge_status,
    [PREFIX .. "inter-cluster-bridge-mk3"] = get_inter_cluster_bridge_status,
    [PREFIX .. "template-energy-io-mk1"] = get_template_energy_io_status,
    [PREFIX .. "template-energy-io-mk2"] = get_template_energy_io_status,
    [PREFIX .. "template-energy-io-mk3"] = get_template_energy_io_status,
    [PREFIX .. "template-fluid-io-mk1"] = get_template_fluid_io_status,
    [PREFIX .. "template-fluid-io-mk2"] = get_template_fluid_io_status,
    [PREFIX .. "template-fluid-io-mk3"] = get_template_fluid_io_status,
    [PREFIX .. "template-item-io-mk1"] = get_template_item_io_status,
    [PREFIX .. "template-item-io-mk2"] = get_template_item_io_status,
    [PREFIX .. "template-item-io-mk3"] = get_template_item_io_status,
    [PREFIX .. "virtualization-mainframe-mk1"] = get_virtualization_mainframe_status,
    [PREFIX .. "virtualization-mainframe-mk2"] = get_virtualization_mainframe_status,
    [PREFIX .. "virtualization-mainframe-mk3"] = get_virtualization_mainframe_status,
}

---Gets status of a given entity
---@param entity LuaEntity
---@return LocalisedString
local function get_entity_status(entity)
    -- entity is invalid
    if not entity.valid then
        return {"entity-status.invalid"}
    end
    -- entity is a ghost
    if entity.name == "entity-ghost" then
        return {"entity-status.ghost"}
    end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    -- entity properties are not found in the registry
    if not properties then
        return {"entity-status.not-registered"}
    end
    local handler = status_router[entity.name]
    local status = handler(properties)
    return status or {"entity-status.unknown"}
end

---Adds entity status display element
---@param parent LuaGuiElement status display will be added here
---@param entity LuaEntity
function EntityInfo.create_entity_status_display(parent, entity)
    local status = get_entity_status(entity)
    local caption = {"", {"gui-label.entity-status"}, ": " , status}
    CommonGui.create_info_element_base(parent, caption)
end

-------------------------------------------------------------------------------
-- MAINFRAME REQUESTS/CONTENTS
-------------------------------------------------------------------------------

---Assembles an array with data needed for creation of sprite buttons,
---which can be used to display contents of input table.
---@param items table<BufferKeyString, ItemBuffer>
---@return SpriteButtonData[]
local function assemble_sprite_button_data(items)
    local buttons = {}
    for _, buffer in pairs(items) do
        local count = buffer.count
        if count > 0 then
            local name = buffer.name
            local data = {
                count = count,
                sprite = "item/" .. name,
                ---@diagnostic disable-next-line
                tooltip = {"?", {"item-name." .. name}, {"entity-name." .. name}},
                quality = buffer.quality
            }
            table.insert(buttons, data)
        end
    end
    return buttons
end

---Adds an element displaying mainframe construction requests
---@param parent LuaGuiElement element will be added here
---@param entity LuaEntity 
function EntityInfo.create_mainframe_construction_requests(parent, entity)
    if not entity.valid then return end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    if not properties then return end
    local requests = properties.building_requests
    if not requests or not next(requests) then return end

    local section = CommonGui.create_info_element_base(
        parent,
        {"gui-label.missing-construction-materials"}
    )
    local buttons = assemble_sprite_button_data(requests)
    CommonGui.create_sprite_button_table(section, buttons)
end

---Adds an element displaying mainframe contained buildings
---@param parent LuaGuiElement element will be added here
---@param entity LuaEntity 
function EntityInfo.create_mainframe_contained_buildings(parent, entity)
    if not entity.valid then return end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    if not properties then return end
    local contents = properties.building_contents
    if not contents or not next(contents) then return end

    local section = CommonGui.create_info_element_base(
        parent,
        {"gui-label.collected-construction-materials"}
    )
    local buttons = assemble_sprite_button_data(contents)
    CommonGui.create_sprite_button_table(section, buttons)
end

-------------------------------------------------------------------------------
-- CLUSTER INFORMATION
-------------------------------------------------------------------------------

---Adds all cluster information for given entity
---@param parent LuaGuiElement element will be added here
---@param entity LuaEntity 
function EntityInfo.create_cluster_information_display(parent, entity)
    if not entity.valid then return end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    if not properties then return end
    local cluster = properties.first_cluster
    ClusterInfo.create_all_cluster_info(parent, cluster)
end

---Adds cluster information for given inter cluster bridge
---@param parent LuaGuiElement info element will be added here
---@param entity LuaEntity 
function EntityInfo.create_icb_cluster_info_display(parent, entity)
    if not entity.valid then return end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    if not properties then return end
    local source_cluster = properties.first_cluster
    if source_cluster then
        ClusterInfo.create_output_buffer(
            parent,
            source_cluster,
            {"gui-label.source-cluster-output-buffer"}
        )
    end
    local destination_cluster = properties.second_cluster
    if destination_cluster then
        ClusterInfo.create_input_buffer(
            parent,
            destination_cluster,
            {"gui-label.destination-cluster-input-buffer"}
        )
    end
end

-------------------------------------------------------------------------------
-- LAST SECOND FLOW DISPLAY
-------------------------------------------------------------------------------

---Adds an information element that displays current/max flow rate.
---@param parent LuaGuiElement info element will be added here
---@param entity LuaEntity 
function EntityInfo.create_last_second_flow_display(parent, entity)
    if not entity.valid then return end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    if not properties then return end

    local ls_flow = properties.ls_flow
    local flow_limit = properties.flow_limit
    if not ls_flow or not flow_limit then return end

    -- creating caption of the form current/max
    local ls_flow_formatted = CommonGui.format_number(ls_flow)
    local flow_limit_formatted = CommonGui.format_number(flow_limit)
    local caption = ls_flow_formatted .. "/" .. flow_limit_formatted

    CommonGui.create_info_element_base(
        parent,
        ---@diagnostic disable-next-line
        {"", {"gui-label.current-flow-rate"}, ": " .. caption}
    )
end

return EntityInfo