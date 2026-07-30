--[[
Virtualization mainframe manager is used only by entity processor.
Virtualization mainframes serve as crafting power providers for virtualization clusters.
VM is a fancy requester chest. This manager does following things:
Requests construction materials for selected template and makes it operational when necessery
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local TemplateCompiler = require("src.simulation.template-compiler")

local VMainframe = {}
local PREFIX = "FV-"

---Maps entity names to amount of buildings it requests
local building_cost_multiplier = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1,
    [PREFIX .. "virtualization-mainframe-mk2"] = 10,
    [PREFIX .. "virtualization-mainframe-mk3"] = 100,
}

---Returns all buildings that were used for template construction
---to physical inventory of mainframe
---@param properties EntityProperties
local function return_buldings_to_inventory(properties)
    -- return if nothing is contained inside vm
    local contents = properties.building_contents
    if not contents or not next(contents) then return end

    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    ---Assuming mainframe prototype has an inventory
    ---@cast inventory LuaInventory

    -- returning everything to inventory
    -- TODO: make sure everything fits
    for _, buffer in pairs(contents) do
        if buffer.count > 0 then
            inventory.insert{
                name = buffer.name,
                count = buffer.count,
                quality = buffer.quality
            }
        end
    end
    properties.building_contents = {}
end

---Prepares for construction of new template: copies template building cost to requesting
---table, makes sure contained_buildings table has sections for all requesting items.
---@param properties EntityProperties
local function prepare_new_template_construction(properties)
    local template_name = properties.first_template
    local build_cost = TemplateCompiler.get_building_cost(template_name)
    local entity_name = properties.entity_name
    local multiplier = building_cost_multiplier[entity_name]

    ---@type table<BufferKeyString, ItemBuffer>
    local requests = {}
    ---@type table<BufferKeyString, ItemBuffer>
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
    properties.building_contents = contents
end

---Clears logistic requests of a given vmainframe
---@param properties EntityProperties
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
---@param properties EntityProperties
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
---@param properties EntityProperties
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
        local contents_buffer = properties.building_contents[key]
        contents_buffer.count = contents_buffer.count + removed_count
    end
end

---Function that is called when template changes
---@param properties EntityProperties
function VMainframe.on_cluster_change(properties)
    return_buldings_to_inventory(properties)
    prepare_new_template_construction(properties)
end

---On-tick processor for virtualization mainframes
---@param properties EntityProperties
function VMainframe.process_vm(properties)
    -- does not work on vsurface
    if properties.on_vsurface then return end

    -- handling building requests (only if mainframe is not operational)
    if not properties.operational then
        withdraw_building_materials(properties)
        set_logistic_requests(properties)
        local requests = properties.building_requests
        if properties.first_cluster and requests and not next(requests) then
            local cluster = properties.first_cluster
            ClusterProcessor.enable_crafting_power(properties.entity, cluster)
            clear_logistic_requests(properties)
            properties.operational = true
        end
    end
end

return VMainframe