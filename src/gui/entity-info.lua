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