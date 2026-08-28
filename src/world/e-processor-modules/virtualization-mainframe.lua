--[[
Virtualization mainframe is needed to provide crafting power to clusters.
It connects to a cluster and "builds" the template assigned to cluster.
Building a template means that it requests items (via logistic network)
required for construction of given template. When template construction
is complete, crafting power is provided to cluster.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Mandatory entity configuration is provided:
    1. first_cluster. Used to determine the cluster to connect to.
II. Entity is not located on a vsurface.
III. Selected cluster exists and this entity can be added to it.

Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. capacity. amount of crafting power this building can provide
3. inventory. Used to make calls for factorio API
4. logistic_point. Used to make calls for factorio API
5. state. ("idle", "constructing", "deconstructing", "operational").
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick processing:
1. assigned_template. Uuid of template being constructed
2. building_requests. Used to create requests and track building progress.
3. building_contents. Used to track buildings stored in the mainframe.

Entity state meaning breakdown:
1. "Idle": entity does not have an assigned template, does not request
    anything, does not provide crafting power
2. "Constructing": entity has an assigned template and is requesting
    materials, does not provide crafting power
3. "Deconstructing": entity does not have an assigned template, does not
    request anything, does not provide crafting power, currently trying
    to eject building contents to physical inventory.
4. "Operational": entity has an assigned template, does not request anything
    does provide crafting power.
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local VMainframe = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
VMainframe.configuration = {
    "first_cluster",
}

---Maps entity names to amount of crafting power they provide
local crafting_power = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1,
    [PREFIX .. "virtualization-mainframe-mk2"] = 10,
    [PREFIX .. "virtualization-mainframe-mk3"] = 100,
}

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1e-5,
    [PREFIX .. "virtualization-mainframe-mk2"] = 1e-4,
    [PREFIX .. "virtualization-mainframe-mk3"] = 1e-3,
}

---@enum
local entity_states = {
    idle = "idle",
    constructing = "constructing",
    deconstructing = "deconstructing",
    operational = "operational",
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function VMainframe.initialize(properties)
    -- Checking that cluster uuid is provided
    local cluster_uuid = properties.first_cluster
    if not cluster_uuid then
        properties.status = Utilities.entity_status.no_primary_cluster
        return Utilities.registry_sections.incorrect
    end
    -- Checking that entity is not located on a virtualization surface
    local entity = properties.entity
    if VSurfaceManager.is_vsurface(entity.surface_index) then
        properties.status = Utilities.entity_status.vsurface_no_work
        return Utilities.registry_sections.incorrect
    end
    -- Checking that cluster exists
    if not ClusterProcessor.does_cluster_exist(cluster_uuid) then
        properties.status = Utilities.entity_status.cluster_not_found
        return Utilities.registry_sections.incorrect
    end
    -- Attempting to add entity to the cluster
    local entity_name = properties.entity_name
    local status = ClusterProcessor.add_member_to_cluster(
        entity,
        cluster_uuid,
        weights[entity_name]
    )
    if not status then
        properties.status = Utilities.entity_status.cluster_cant_connect
        return Utilities.registry_sections.incorrect
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    local base_capacity = crafting_power[entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    properties.capacity = base_capacity * quality_mult
    properties.inventory = entity.get_inventory(defines.inventory.chest)
    properties.logistic_point = entity.get_requester_point()
    properties.state = entity_states.idle
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function VMainframe.uninitialize(properties)

end

-------------------------------------------------------------------------------
--------------------------------- IDLE STATE ----------------------------------
-------------------------------------------------------------------------------

---Prepares properties for construction of the template
---@param properties EntityProperties
local function prepare_template_construction(properties)
    local build_cost = ClusterProcessor.get_build_cost(properties.first_cluster)
    local mult = properties.capacity
    ---@type table<BufferKeyString, ItemBuffer>
    local requests = {}
    ---@type table<BufferKeyString, ItemBuffer>
    local contents = {}
    -- processing all items from building cost of new template
    for key, count in pairs(build_cost) do
        local start_idx, end_idx = string.find(key, "//", 1, true)
        local name = string.sub(key, 1, start_idx - 1)
        local quality = string.sub(key, end_idx + 1)
        requests[key] = {
            name = name,
            count = math.ceil(count * mult),
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

---Used for on-tick updates of this entity in idle state.
---@param properties EntityProperties
---@return EntityRegistrySection
local function idle_state_update(properties)
    local template_uuid = ClusterProcessor.get_assigned_template(
        properties.first_cluster
    )
    if not template_uuid then
        -- No assigned template: moving entity to stalled
        properties.status = Utilities.entity_status.no_assigned_template
        return Utilities.registry_sections.stalled
    end
    -- Assigned template is found: preparing for construction
    properties.assigned_template = template_uuid
    prepare_template_construction(properties)
    properties.state = entity_states.constructing
    return Utilities.registry_sections.active
end

-------------------------------------------------------------------------------
----------------------------- CONSTRUCTING STATE ------------------------------
-------------------------------------------------------------------------------

---Scans entity inventory and withdraws anything that is in building requests
---@param properties EntityProperties
local function withdraw_construction_materials(properties)
    ---@type table<BufferKeyString, ItemBuffer> assuming table was created
    local requests = properties.building_requests
    ---@type LuaInventory assuming it was cached on initialization
    local inventory = properties.inventory

    -- iterating over contents of entity inventory
    local inv_contents = inventory.get_contents()
    for _, item in ipairs(inv_contents) do
        local buffer_key = string.format("%s//%s", item.name, item.quality)
        local entry = requests[buffer_key]
        -- inventory can contain something that was not requested
        if entry then
            ---@diagnostic disable-next-line
            local removed_count = inventory.remove(entry)
            -- updating requests table
            entry.count = entry.count - removed_count
            if entry.count == 0 then requests[buffer_key] = nil end
            -- updating contents table
            entry = properties.building_contents[buffer_key]
            entry.count = entry.count + removed_count
        end
    end
end

-- TODO: change data structure. Have to cache table with section filters



---Clears logistic requests for a given mainframe
---@param properties EntityProperties
local function clear_logistic_requests(properties)
    ---@type LuaLogisticPoint assigned on initialization
    local point = properties.logistic_point
    point.trash_not_requested = true
    -- deleting all sections from logistic point
    for i = point.sections_count, 1, -1 do
        point.remove_section(i)
    end
end

---Sets logistic requests of an entity exactly to building requests.
---@param properties EntityProperties
local function set_logistic_requests(properties)
    ---@type LuaLogisticPoint assuming is was cached on initialization
    local point = properties.logistic_point
    point.trash_not_requested = true

    -- Making sure there is exactly one logistic section and getting it
    local s_count = point.sections_count
    local section
    if s_count == 0 then
        section = point.add_section()
    else
        -- deleting all sections except the first one
        for i = s_count, 2, -1 do
            point.remove_section(i)
        end
        section = point.get_section(1)
    end
    -- safety check: just in case
    if not section or not section.is_manual then return end

    local filters = {}
    for _, entry in pairs(properties.building_requests) do
        local count = entry.count
        local filter = {
            value = {name = entry.name, quality = entry.quality},
            min = count,
            max = count,
        }
        table.insert(filters, filter)
    end
    section.filters = filters
    


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



---Used for on-tick updates of this entity in constructing state.
---@param properties EntityProperties
---@return EntityRegistrySection
local function constructing_state_update(properties)

end

-------------------------------------------------------------------------------
---------------------------- DECONSTRUCTING STATE -----------------------------
-------------------------------------------------------------------------------

---Used for on-tick updates of this entity in deconstructing state.
---@param properties EntityProperties
---@return EntityRegistrySection
local function deconstructing_state_update(properties)

end

---Used for on-tick updates of this entity in operational state.
---@param properties EntityProperties
---@return EntityRegistrySection
local function operational_state_update(properties)

end



---Maps entity states to corresponding update functions
local update_router = {
    [entity_states.idle] = idle_state_update,
    [entity_states.constructing] = constructing_state_update,
    [entity_states.deconstructing] = deconstructing_state_update,
    [entity_states.operational] = operational_state_update,
}

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function VMainframe.update(properties)
    -- Checking that associated cluster exists
    ---@type string checked on initialization
    local cluster_uuid = properties.first_cluster
    if not ClusterProcessor.does_cluster_exist(cluster_uuid) then
        -- cluster does not exist: setting entity to not operational
        properties.status = Utilities.entity_status.cluster_deleted
        return Utilities.registry_sections.incorrect
    end



    local handler = update_router[properties.state]
    return handler(properties)
end

return VMainframe

--[[


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
    if VSurfaceManager.is_vsurface(entity.surface_index) then return false end

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
    properties.logistic_point = 
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

--]]