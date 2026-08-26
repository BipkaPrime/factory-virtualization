--[[
Template item IOs are used in creation of templates on virtualization surfaces.
They serve as inputs and outputs of items.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. io_mode. Used to determine the entity operation.
    2. selected_item. Used to determine the buffer key.
II. Entity is located on a vsurface.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. buffer_key. Used to make calls to venv processor
3. is_output. Used to determine entity operation
4. flow_limit. Determines maximum flow rate for this entity
5. inventory. Used to make calls to factorio API
6. io_request. Used to make calls to factorio API
7. surface_index. Used to make calls to venv processor

Properties that can be assigned during on-tick processing:
1. ls_flow. Can be used to track entity work.
--]]

local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local TemplateItemIO = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
TemplateItemIO.configuration = {
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

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function TemplateItemIO.initialize(properties)
    -- Checking that io mode is selected
    local io_mode = properties.io_mode
    if not io_mode then
        properties.status = Utilities.entity_status.no_io_mode_primary
        return Utilities.registry_sections.incorrect
    end
    -- Checking that item and quality are selected
    local item_name = properties.selected_item_name
    local item_quality = properties.selected_item_quality
    if not item_name or not item_quality then
        properties.status = Utilities.entity_status.no_selected_item
        return Utilities.registry_sections.incorrect
    end
    -- Checking that entity is located on a virtualization surface
    local entity = properties.entity
    if not VSurfaceManager.is_vsurface(entity.surface_index) then
        properties.status = Utilities.entity_status.vsurface_only_work
        return Utilities.registry_sections.incorrect
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    properties.buffer_key = item_name .. "//" .. item_quality
    properties.is_output = (io_mode == "output")
    local base_flow = flow_limits[properties.entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    local flow_limit = base_flow * quality_mult
    properties.flow_limit = flow_limit
    properties.inventory = entity.get_inventory(defines.inventory.chest)
    properties.io_request = {
        name = item_name,
        quality = item_quality,
        count = flow_limit
    }
    properties.surface_index = entity.surface_index
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function TemplateItemIO.uninitialize(properties)
    properties.buffer_key = nil
    properties.is_output = nil
    properties.flow_limit = nil
    properties.inventory = nil
    properties.io_request = nil
    properties.surface_index = nil
    properties.ls_flow = nil
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function TemplateItemIO.update(properties)
    local delta = 0
    if properties.is_output then
        ---@diagnostic disable-next-line
        delta = properties.inventory.remove(properties.io_request)
        if delta > 0 then
            VSurfaceManager.add_to_venv_output(
                properties.surface_index,
                properties.buffer_key,
                delta
            )
        end
    else
        ---@diagnostic disable-next-line
        delta = properties.inventory.insert(properties.io_request)
        if delta > 0 then
            VSurfaceManager.add_to_venv_input(
                properties.surface_index,
                properties.buffer_key,
                delta
            )
        end
    end
    properties.ls_flow = delta
    return Utilities.registry_sections.active
end

return TemplateItemIO