--[[
This file helps in creation of entity GUIs. It creates information elements for 
given entity. It works directly (read only) with entity properties from registry.
--]]

local EntityProcessor = require("src.world.entity-processor")
local CommonGui = require("src.gui.common")
local ClusterInfo = require("src.gui.cluster-info")


local EntityInfo = {}
local PREFIX = "FV-"

-------------------------------------------------------------------------------
-- ENTITY STATUS DISPLAY
-------------------------------------------------------------------------------

---Decides template item IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_template_item_io_status(properties)
    -- entity is not on a vsurface
    if not properties.on_vsurface then
        return {"entity-status.works-only-on-vsurface"}
    end
    -- item is not selected
    if not properties.selected_item then
        return {"entity-status.item-not-selected"}
    end
    return {"entity-status.operational"}
end

---Decides template fluid IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_template_fluid_io_status(properties)
    -- entity is not on a vsurface
    if not properties.on_vsurface then
        return {"entity-status.works-only-on-vsurface"}
    end
    -- fluid is not selected
    if not properties.selected_fluid then
        return {"entity-status.fluid-not-selected"}
    end
    return {"entity-status.operational"}
end

---Decides template energy IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_template_energy_io_status(properties)
    -- entity is not on a vsurface
    if not properties.on_vsurface then
        return {"entity-status.works-only-on-vsurface"}
    end
    return {"entity-status.operational"}
end

---Decides cluster item IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_cluster_item_io_status(properties)
    -- entity is on a vsurface
    if properties.on_vsurface then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- item is not selected
    if not properties.selected_item then
        return {"entity-status.item-not-selected"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.not-connected-to-cluster"}
    end
    return {"entity-status.operational"}
end

---Decides cluster fluid IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_cluster_fluid_io_status(properties)
    -- entity is on a vsurface
    if properties.on_vsurface then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- fluid is not selected
    if not properties.selected_fluid then
        return {"entity-status.fluid-not-selected"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.not-connected-to-cluster"}
    end
    return {"entity-status.operational"}
end

---Decides cluster energy IO status based on its properties
---@param properties EntityProperties table from entity registry
local function get_cluster_energy_io_status(properties)
    -- entity is on a vsurface
    if properties.on_vsurface then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.not-connected-to-cluster"}
    end
    return {"entity-status.operational"}
end

---Decides mainframe status based on its properties
---@param properties EntityProperties table from entity registry
local function get_mainframe_status(properties)
    -- entity is on a vsurface
    if properties.on_vsurface then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- entity is not connected to cluster
    if not properties.first_cluster then
        return {"entity-status.not-connected-to-cluster"}
    end
    -- something is being requested
    local requests = properties.building_requests
    if requests and next(requests) then
        return {"entity-status.requesting-construction-materials"}
    end
    -- template constructed: mainframe operational
    if properties.operational then
        return {"entity-status.operational"}
    end
end

---Decides inter-cluster bridge statusbased on its properties
---@param properties EntityProperties table from entity registry
local function get_inter_cluster_bridge_status(properties)
    -- entity is on a vsurface
    if properties.on_vsurface then
        return {"entity-status.does-not-work-on-vsurface"}
    end
    -- source cluster is not selected
    if not properties.first_cluster then
        return {"entity-status.source-cluster-not-selected"}
    end
    -- destination cluster is not selected
    if not properties.second_cluster then
        return {"entity-status.destination-cluster-not-selected"}
    end
    local mode = properties.mode
    if not mode then
        return {"entity-status.mode-not-selected"}
    end
    -- item is not selected in item mode
    if mode == "item" and not properties.selected_item then
        return {"entity-status.item-not-selected"}
    end
    -- fluid is not selected in fluid mode
    if mode == "fluid" and not properties.selected_fluid then
        return {"entity-status.fluid-not-selected"}
    end
    return {"entity-status.operational"}
end

---Maps entity name to function that can get its status
local status_router = {
    [PREFIX .. "template-item-io-mk1"] = get_template_item_io_status,
    [PREFIX .. "template-item-io-mk2"] = get_template_item_io_status,
    [PREFIX .. "template-item-io-mk3"] = get_template_item_io_status,
    [PREFIX .. "template-fluid-io-mk1"] = get_template_fluid_io_status,
    [PREFIX .. "template-fluid-io-mk2"] = get_template_fluid_io_status,
    [PREFIX .. "template-fluid-io-mk3"] = get_template_fluid_io_status,
    [PREFIX .. "template-energy-io-mk1"] = get_template_energy_io_status,
    [PREFIX .. "template-energy-io-mk2"] = get_template_energy_io_status,
    [PREFIX .. "template-energy-io-mk3"] = get_template_energy_io_status,
    [PREFIX .. "cluster-item-io-mk1"] = get_cluster_item_io_status,
    [PREFIX .. "cluster-item-io-mk2"] = get_cluster_item_io_status,
    [PREFIX .. "cluster-item-io-mk3"] = get_cluster_item_io_status,
    [PREFIX .. "cluster-fluid-io-mk1"] = get_cluster_fluid_io_status,
    [PREFIX .. "cluster-fluid-io-mk2"] = get_cluster_fluid_io_status,
    [PREFIX .. "cluster-fluid-io-mk3"] = get_cluster_fluid_io_status,
    [PREFIX .. "cluster-energy-io-mk1"] = get_cluster_energy_io_status,
    [PREFIX .. "cluster-energy-io-mk2"] = get_cluster_energy_io_status,
    [PREFIX .. "cluster-energy-io-mk3"] = get_cluster_energy_io_status,
    [PREFIX .. "virtualization-mainframe-mk1"] = get_mainframe_status,
    [PREFIX .. "virtualization-mainframe-mk2"] = get_mainframe_status,
    [PREFIX .. "virtualization-mainframe-mk3"] = get_mainframe_status,
    [PREFIX .. "inter-cluster-bridge-mk1"] = get_inter_cluster_bridge_status,
    [PREFIX .. "inter-cluster-bridge-mk2"] = get_inter_cluster_bridge_status,
    [PREFIX .. "inter-cluster-bridge-mk3"] = get_inter_cluster_bridge_status,
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

---Adds an element displaying mainframe construction requests
---@param parent LuaGuiElement element will be added here
---@param entity LuaEntity 
function EntityInfo.create_mainframe_construction_requests(parent, entity)
    if not entity.valid then return end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    if not properties then return end
    local requests = properties.building_requests
    if not requests or not next(requests) then return end
    ---@cast requests table<BufferKeyString, ItemBuffer>

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

---Adds an element displaying mainframe contained buildings
---@param parent LuaGuiElement element will be added here
---@param entity LuaEntity 
function EntityInfo.create_mainframe_contained_buildings(parent, entity)
    if not entity.valid then return end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    if not properties then return end
    local contents = properties.building_contents
    if not contents or not next(contents) then return end
    ---@cast contents table<BufferKeyString, ItemBuffer>

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
function EntityInfo.create_inter_cluster_bridge_display(parent, entity)
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

function EntityInfo.create_last_second_flow_display(parent, entity)
    if not entity.valid then return end
    local properties = EntityProcessor.get_entity_properties(entity.unit_number)
    if not properties then return end

    local ls_flow = properties.ls_flow
    local caption = CommonGui.format_number(ls_flow or 0)

    CommonGui.create_info_element_base(
        parent,
        ---@diagnostic disable-next-line
        {"", {"gui-label.last-second-flow"}, ": " .. caption}
    )
end

return EntityInfo