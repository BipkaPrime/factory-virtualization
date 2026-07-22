--[[
Virtualization mainframe manager is used only by entity processor.
Virtualization mainframes serve as crafting power providers for virtualization clusters.
VM is a fancy requester chest. This manager does following things:
Requests construction materials for selected template and makes it operational when necessery
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local TemplateCompiler = require("src.simulation.template-compiler")

local MainframeManager = {}
local PREFIX = "FV-"

---Maps entity names to amount of buildings it requests
local building_cost_multiplier = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1,
    [PREFIX .. "virtualization-mainframe-mk2"] = 10,
    [PREFIX .. "virtualization-mainframe-mk3"] = 100,
}

---Returns all buildings that were used for template construction
---to physical inventory of vmainframe
---@param properties MainframeProperties
local function return_buldings_to_inventory(properties)
    -- return if nothing is contained inside vm
    local buildings = properties.contained_buildings
    if not buildings or not next(buildings) then return end

    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    ---Assuming mainframe prototype has an inventory
    ---@cast inventory LuaInventory

    -- returning everything to inventory
    -- TODO: make sure everything fits
    for _, buffer in pairs(buildings) do
        if buffer.count > 0 then
            inventory.insert{
                name = buffer.name,
                count = buffer.count,
                quality = buffer.quality
            }
        end
    end
    properties.contained_buildings = {}
end

---Prepares for construction of new template: copies template building cost to requesting
---table, makes sure contained_buildings table has sections for all requesting items.
---@param properties MainframeProperties
local function prepare_new_template_construction(properties)
    local template_name = properties.selected_template
    local build_cost = TemplateCompiler.get_building_cost(template_name)
    local entity_name = properties.entity.name
    local multiplier = building_cost_multiplier[entity_name]

    ---@type table<ItemKeyString, ItemBuffer>
    local requests = {}
    ---@type table<ItemKeyString, ItemBuffer>
    local contents = {}
    -- processing all items from building cost of new template
    for key, count in pairs(build_cost) do
        local name, quality = key:match("^(.+)//(.+)$")
        requests[key] = {
            name = name,
            count = count * multiplier,
            quality = quality,
        }
        contents[key] = {
            name = name,
            count = 0,
            quality = quality,
        }
    end
    properties.building_requests = requests
    properties.contained_buildings = contents
end

---Clears logistic requests of a given vmainframe
---@param properties MainframeProperties
---@return LuaLogisticPoint
local function clear_logistic_requests(properties)
    local entity = properties.entity
    local log_point = entity.get_requester_point()

    ---assuming mainframe prototype has it
    ---@cast log_point LuaLogisticPoint

    log_point.trash_not_requested = true
    local section_count = log_point.sections_count
    for i = section_count, 1, -1 do
        log_point.remove_section(i)
    end
    return log_point
end

---Adds everything from requests table to logistic requests of a given VM
---@param properties MainframeProperties
local function set_logistic_requests(properties)
    local requests = properties.building_requests
    if not requests or not next(requests) then return end

    local log_point = clear_logistic_requests(properties)

    -- creating one logistic section
    log_point.add_section()
    local log_section = log_point.get_section(1)

    -- requesting all construction materials
    local curr_slot = 1
    for _, buffer in pairs(requests) do
        local filter = {
            value = {name = buffer.name, quality = buffer.quality},
            min = buffer.count,
            max = buffer.count,
        }
        log_section.set_slot(curr_slot, filter)
        curr_slot = curr_slot + 1
    end
end

---Scans mainframe inventory and withdraws anything that is in building requests
---@param properties MainframeProperties
local function withdraw_building_materials(properties)
    local requests = properties.building_requests
    if not requests or not next(requests) then return end

    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    ---Assuming mainframe prototype has an inventory
    ---@cast inventory LuaInventory

    -- iterating over inventory contents
    local inv_contents = inventory.get_contents()
    for _, item in ipairs(inv_contents) do
        local name, quality = item.name, item.quality
        local available_count = item.count

        local key = name .. "//" .. quality
        local buffer = requests[key]
        local demand = buffer.count

        local removed_count = inventory.remove{
            name = name,
            quality = quality,
            count = math.min(demand, available_count)
        }

        -- updating item requests
        buffer.count = buffer.count - removed_count
        if buffer.count == 0 then requests[key] = nil end

        -- updating contained buildings
        local contained_buffer = properties.contained_buildings[key]
        contained_buffer.count = contained_buffer.count + removed_count
    end
end

---Function that is called when template changes
---@param properties MainframeProperties
function MainframeManager.on_template_change(properties)
    return_buldings_to_inventory(properties)
    prepare_new_template_construction(properties)
end

---On-tick processor for virtualization mainframes
---@param properties MainframeProperties
function MainframeManager.process_vm(properties)
    -- handling building requests (only if mainframe is not operational)
    if not properties.operational then
        withdraw_building_materials(properties)
        set_logistic_requests(properties)
        local requests = properties.building_requests
        if properties.cluster and (not requests or not next(requests)) then
            local cluster = properties.cluster
            ClusterProcessor.enable_crafting_power(properties.entity, cluster)
            clear_logistic_requests(properties)
            properties.operational = true
        end
    end
end

-------------------------------------------------------------------------------
-- INFO REQUESTS (GUI)
-------------------------------------------------------------------------------

---@param properties MainframeProperties
---@return LocalisedString
function MainframeManager.get_mainframe_status(properties)
    -- no selected template: mainframe is idle
    if not properties.cluster then
        return {"entity-status.template-not-selected"}
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
    return {"entity-status.unknown"}
end

---@param properties MainframeProperties
---@return table<ItemKeyString, ItemBuffer>|nil
function MainframeManager.get_contained_buildings(properties)
    return properties.contained_buildings
end

---@param properties MainframeProperties
---@return table<ItemKeyString, ItemBuffer>|nil
function MainframeManager.get_construction_requests(properties)
    return properties.building_requests
end

return MainframeManager