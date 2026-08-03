--[[
Virtualization mainframe is needed to provide crafting power to clusters.
When it connects to a cluster, it starts requesting building materials needed
for template construction. Once construction is finished, crafting power
is added to the cluster.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Mandatory entity controls are provided:
    1. First template. Used to determine the cluster to connect to.
II. Entity is not located on a vsurface.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. First cluster. Used to make calls to cluster processor.
2. Building requests. Used to create logistic requests and track building progress.
3. Building contents. Used to track building stored in the mainframe
4. Inventory. Used to make calls for factorio API
5. Logistic point. Used to make calls for factorio API

Properties that can be assigned during on-tick processing:
1. Operational. Used as an indication of template construction being completed
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local TemplateCompiler = require("src.simulation.template-compiler")
local VSurfaceManager = require("src.world.vsurface-manager")


local PREFIX = "FV-"
local VMainframe = {}

---List of all copyable properties of this entity
VMainframe.copyable = {
    "first_template",
}

---Maps entity names to amount of buildings it requests
local building_cost_multiplier = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1,
    [PREFIX .. "virtualization-mainframe-mk2"] = 10,
    [PREFIX .. "virtualization-mainframe-mk3"] = 100,
}

---Maps entity names to amount of crafting power they provide
local crafting_power = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1,
    [PREFIX .. "virtualization-mainframe-mk2"] = 10,
    [PREFIX .. "virtualization-mainframe-mk3"] = 100,
}

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 10,
    [PREFIX .. "virtualization-mainframe-mk2"] = 100,
    [PREFIX .. "virtualization-mainframe-mk3"] = 1000,
}

---Prepares for construction of new template: copies template building cost to requesting
---table, makes sure contained_buildings table has sections for all requesting items.
---@param properties EntityProperties
local function prepare_template_construction(properties)
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

---Checks that all requirements for operation of virtualization mainframe are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function VMainframe.attempt_entity_initialization(properties)
    -- 1. First template is selected
    local first_template = properties.first_template
    if not first_template then return false end
    -- 2. Entity is not located on a vsurface
    local entity = properties.entity
    if VSurfaceManager.get_vsurface_data(entity.surface_index) then return false end

    ---All requirements are met. Preparing properties for on-tick processing
    -- attempting to connect entity to cluster
    local cluster = ClusterProcessor.add_to_cluster(
        entity,
        first_template,
        weights[properties.entity_name]
    )
    if not cluster then return false end
    properties.first_cluster = cluster
    -- creating contents and requests tables according to template data
    prepare_template_construction(properties)
    -- saving LuaInventory object: assuming it has one
    properties.inventory = entity.get_inventory(defines.inventory.chest)
    -- saving LuaLogisticPoint: assuming it gas one (requester type)
    properties.logistic_point = entity.get_requester_point()
    return true
end

---Returns all buildings that are currently contained inside given
---virtualization mainframe to its physical inventory.
---@param properties EntityProperties
local function return_buildings_to_inventory(properties)
    local inventory = properties.inventory
    -- if entity was not initialized or is invalid, can not do anything
    if not inventory or not inventory.valid then return end

    ---If properties has cached inventory, contents will also be there
    ---@type table<BufferKeyString, ItemBuffer>
    local contents = properties.building_contents
    for _, buffer in pairs(contents) do
        if buffer.count > 0 then
            inventory.insert{
                name = buffer.name,
                count = buffer.count,
                quality = buffer.quality
            }
        end
    end
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function VMainframe.on_processing_stopped(properties)
    properties.operational = nil
    ClusterProcessor.remove_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.first_cluster = nil
    properties.building_requests = nil
    return_buildings_to_inventory(properties)
    properties.building_contents = nil
    properties.inventory = nil
    properties.logistic_point = nil
end

---Clears logistic requests for a given mainframe
---@param properties EntityProperties
local function clear_logistic_requests(properties)
    ---@type LuaLogisticPoint assuming is was cached on initialization
    local point = properties.logistic_point

    -- making sure to always set trash not requested
    point.trash_not_requested = true
    -- deleting all sections from logistic point
    for i = point.sections_count, 1, -1 do
        point.remove_section(i)
    end
end

---Sets logistic requests of a given virtualization mainframe exactly to
---everything currently is in its building requests.
---@param properties EntityProperties
local function set_logistic_requests(properties)
    -- clearing logistic requests
    clear_logistic_requests(properties)
    ---@type LuaLogisticPoint assuming it was cached on initialization
    local log_point = properties.logistic_point
    -- creating one new empty section
    log_point.add_section()
    local section = log_point.get_section(1)

    -- requesting all construction materials
    ---@type table<BufferKeyString, ItemBuffer> assuming table was created
    local requests = properties.building_requests
    local curr_slot = 1
    for _, buffer in pairs(requests) do
        local filter = {
            value = {name = buffer.name, quality = buffer.quality},
            min = buffer.count,
            max = buffer.count,
        }
        section.set_slot(curr_slot, filter)
        curr_slot = curr_slot + 1
    end
end

---Scans mainframe inventory and withdraws anything that is in building requests
---@param properties EntityProperties
local function withdraw_building_materials(properties)
    ---@type table<BufferKeyString, ItemBuffer> assuming table was created
    local requests = properties.building_requests
    ---@type LuaInventory assuming it was cached on initialization
    local inventory = properties.inventory

    -- iterating over inventory contents
    local inv_contents = inventory.get_contents()
    for _, item in ipairs(inv_contents) do
        local name, quality = item.name, item.quality
        local available_count = item.count

        local buffer_key = name .. "//" .. quality
        local buffer = requests[buffer_key]
        -- inventory can contain something that was not requested
        if not buffer then goto continue end

        -- removing item from inventory
        local demand = buffer.count
        local removed_count = inventory.remove{
            name = name,
            quality = quality,
            count = math.min(demand, available_count)
        }

        -- updating building requests
        buffer.count = buffer.count - removed_count
        if buffer.count == 0 then requests[buffer_key] = nil end

        -- updating building contents
        local contents_buffer = properties.building_contents[buffer_key]
        contents_buffer.count = contents_buffer.count + removed_count

        ::continue::
    end
end

---Used for on-tick processing of virtualization mainframes.
---@param properties EntityProperties
function VMainframe.process_entity(properties)
    if not properties.operational then
        withdraw_building_materials(properties)
        ---@type table<BufferKeyString, ItemBuffer> assuming table was created on initialization
        local requests = properties.building_requests
        if next(requests) then
            set_logistic_requests(properties)
        else
            -- template construction is done, enabling crafting power
            ClusterProcessor.add_crafting_power(
                properties.first_cluster,
                properties.unit_number,
                crafting_power[properties.entity_name]
            )
            clear_logistic_requests(properties)
            properties.operational = true
        end
    end
end

return VMainframe