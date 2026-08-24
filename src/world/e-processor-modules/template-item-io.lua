--[[
Template item IOs are used in creation of templates on virtualization surfaces.
They serve as inputs and outputs of items.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. IO mode. Used to determine the entity operation.
    2. Selected item. Used to determine the buffer key.
II. Entity is located on a vsurface.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. Is output. Used to determine entity operation
2. Buffer key. Used to make calls to venv processor
3. Inventory. Used to make calls to factorio API
4. Flow limit. Used to display it in gui.
5. IO request. Used to make calls to factorio API

Properties that can be assigned during on-tick processing:
1. Ls flow. Can be used to track entity work.
--]]

local VSurfaceManager = require("src.world.vsurface-manager")

local PREFIX = "FV-"
local TemplateItemIO = {}

---List of all copyable properties of this entity
TemplateItemIO.copyable = {
    "io_mode",
    "selected_item_name",
    "selected_item_quality",
}

---Maps entity names to their flow limits
local flow_limits = {
    [PREFIX .. "template-item-io-mk1"] = 120,
    [PREFIX .. "template-item-io-mk2"] = 1200,
    [PREFIX .. "template-item-io-mk3"] = 12000,
}

---Checks that all requirements for operation of template item IO are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function TemplateItemIO.attempt_entity_initialization(properties)
    -- 1. IO mode is selected
    local io_mode = properties.io_mode
    if not io_mode then return false end
    -- 2. Item is selected
    local item_name = properties.selected_item_name
    local item_quality = properties.selected_item_quality
    if not item_name or not item_quality then return false end
    -- 3. Entity is located on a vsurface
    local entity = properties.entity
    if not VSurfaceManager.is_vsurface(entity.surface_index) then return false end

    ---All requirements are met. Preparing properties for on-tick processing
    -- assigning io mode flag to entity
    properties.is_output = (io_mode == "output")
    -- assigning buffer key to entity
    properties.buffer_key = item_name .. "//" .. item_quality
    -- caching flow limit of the entity to selected item table
    local flow_limit = flow_limits[properties.entity_name]
    properties.flow_limit = flow_limit
    -- caching LuaInventory of the entity
    properties.inventory = entity.get_inventory(defines.inventory.chest)
    properties.io_request = {name = item_name, quality = item_quality, count = flow_limit}
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function TemplateItemIO.on_processing_stopped(properties)
    properties.ls_flow = nil
    properties.io_request = nil
    properties.inventory = nil
    properties.buffer_key = nil
    properties.is_output = nil
    properties.flow_limit = nil
end

---Used for on-tick processing of template item IOs.
---@param properties EntityProperties
function TemplateItemIO.process_entity(properties)
    local delta = 0
    if properties.is_output then
        ---@diagnostic disable-next-line
        delta = properties.inventory.remove(properties.io_request)
        if delta > 0 then
            VSurfaceManager.add_to_venv_output(
                properties.entity.surface_index,
                properties.buffer_key,
                delta
            )
        end
    else
        ---@diagnostic disable-next-line
        delta = properties.inventory.insert(properties.io_request)
        if delta > 0 then
            VSurfaceManager.add_to_venv_input(
                properties.entity.surface_index,
                properties.buffer_key,
                delta
            )
        end
    end
    properties.ls_flow = delta
end

return TemplateItemIO