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
4. logistic_filters. Used to set filters of logistic section to requests.
5. filter_lookup. Maps buffer keys to position in "logistic_filters" field.
6. logistic_section. Cached logistic section used to setup filters.

Entity state meaning breakdown:
1. "Idle": entity does not have an assigned template, does not request
    anything, does not provide crafting power
2. "Constructing": entity has an assigned template and is requesting
    materials, does not provide crafting power
3. "Deconstructing": entity has an assigned template, does not
    request anything, does not provide crafting power, currently trying
    to eject building contents to physical inventory.
4. "Operational": entity has an assigned template, does not request anything
    does provide crafting power.
--]]

local ClusterProcessor = require("scripts.simulation.cluster-processor")
local VSurfaceManager = require("scripts.world.vsurface-manager")
local Utilities = require("scripts.world.e-processor-modules.utilities")

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

-------------------------------------------------------------------------------
--------------------------------- IDLE STATE ----------------------------------
-------------------------------------------------------------------------------

---Used to change entity state from "idle" to "constructing".
---Adds 4 tables to properties that are used in "constructing" mode.
---@param properties EntityProperties
local function from_idle_to_constructing(properties)
    local build_cost = ClusterProcessor.get_build_cost(properties.first_cluster)
    local mult = properties.capacity
    ---@type table<BufferKeyString, ItemBuffer>
    local requests = {}
    ---@type table<BufferKeyString, ItemBuffer>
    local contents = {}
    ---@type LogisticFilter[]
    local filters = {}
    ---@type table<BufferKeyString, integer>
    local filter_lookup = {}
    -- processing all items from building cost of new template
    for key, count in pairs(build_cost) do
        local start_idx, end_idx = string.find(key, "//", 1, true)
        local name = string.sub(key, 1, start_idx - 1)
        local quality = string.sub(key, end_idx + 1)
        local final_count = math.ceil(count * mult)
        -- adding entry to requests table
        requests[key] = {
            name = name,
            count = final_count,
            quality = quality,
        }
        -- adding entry to contents table
        contents[key] = {
            name = name,
            count = 0,
            quality = quality,
        }
        -- adding element to filters and its lookup table
        local filter_idx = #filters + 1
        filters[filter_idx] = {
            value = {name = name, quality = quality},
            min = final_count,
            max = final_count,
        }
        filter_lookup[key] = filter_idx
    end
    properties.building_requests = requests
    properties.building_contents = contents
    properties.logistic_filters = filters
    properties.filter_lookup = filter_lookup
    properties.state = entity_states.constructing
    properties.status = Utilities.entity_status.requesting_materials
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
    from_idle_to_constructing(properties)
    return Utilities.registry_sections.active
end

-------------------------------------------------------------------------------
----------------------------- CONSTRUCTING STATE ------------------------------
-------------------------------------------------------------------------------

---Scans entity inventory and withdraws anything that is in building requests
---@param properties EntityProperties
local function withdraw_construction_materials(properties)
    ---Assuming tables below were created on state change
    ---@type table<BufferKeyString, ItemBuffer>
    local requests = properties.building_requests
    ---@type table<BufferKeyString, ItemBuffer>
    local contents = properties.building_contents
    ---@type LogisticFilter[]
    local filters = properties.logistic_filters
    ---@type table<BufferKeyString, integer>
    local lookup = properties.filter_lookup

    ---@type LuaInventory saved on initialization
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

            -- updating "requests" and "filters" tables
            local new_count = entry.count - removed_count
            local filter_idx = lookup[buffer_key]
            if new_count > 0 then
                entry.count = new_count
                -- updating corresponding filter
                local filter = filters[filter_idx]
                filter.max = new_count
                filter.min = new_count
            else
                -- new count is 0: removing this entry
                requests[buffer_key] = nil
                -- swapping current filter with last element for deletion
                local last_filter = filters[#filters]
                local value = last_filter.value
                ---@diagnostic disable-next-line
                local last_key = string.format("%s//%s", value.name, value.quality)
                filters[filter_idx] = last_filter
                filters[#filters] = nil
                -- correcting lookup table
                lookup[last_key] = filter_idx
                lookup[buffer_key] = nil
            end

            -- updating contents table
            entry = contents[buffer_key]
            entry.count = entry.count + removed_count
        end
    end
end

---Sets logistic requests of an entity exactly to building requests.
---@param properties EntityProperties
local function set_logistic_requests(properties)
    local section = properties.logistic_section
    if not section or not section.valid then
        ---@type LuaLogisticPoint
        local log_point = properties.logistic_point
        -- trying to get first section
        section = log_point.get_section(1)
        if not section then
            -- no sections found: attempting to add one
            section = log_point.add_section()
            -- cannot create a section: return
            if not section then return end
        end
        properties.logistic_section = section
    end
    section.filters = properties.logistic_filters
end

---Used to change entity state from "constructing" to "deconstructing"
---@param properties EntityProperties
local function from_constructing_to_deconstructing(properties)
    -- Cleaning up fields used exclusively in "constructing" state
    properties.building_requests = nil
    properties.logistic_filters = nil
    properties.filter_lookup = nil
    properties.logistic_section = nil

    properties.state = entity_states.deconstructing
    properties.status = Utilities.entity_status.deconstructing
end

---Used to change entity state from "constructing" to "operational"
---@param properties EntityProperties
local function from_constructing_to_operational(properties)
    -- Cleaning up fields used exclusively in "constructing" state
    properties.building_requests = nil
    properties.logistic_filters = nil
    properties.filter_lookup = nil
    properties.logistic_section = nil

    -- Assigning crafting power and marking operational
    ---@type string checking on initialization
    local cluster_uuid = properties.first_cluster
    local unit_number = properties.unit_number
    ClusterProcessor.assign_member_crafting_power(
        cluster_uuid,
        unit_number,
        properties.capacity
    )
    ClusterProcessor.mark_member_operational(
        cluster_uuid,
        unit_number
    )

    properties.state = entity_states.operational
    properties.status = Utilities.entity_status.operational
end

---Used for on-tick updates of this entity in constructing state.
---@param properties EntityProperties
---@return EntityRegistrySection
local function constructing_state_update(properties)
    -- Checking for template change in the cluster
    local current_template = properties.assigned_template
    local cluster_template = ClusterProcessor.get_assigned_template(
        properties.first_cluster
    )
    if current_template ~= cluster_template then
        from_constructing_to_deconstructing(properties)
        return Utilities.registry_sections.active
    end

    -- No template change occured: constructing current
    withdraw_construction_materials(properties)
    if not next(properties.building_requests) then
        -- construction complete: moving to operational
        from_constructing_to_operational(properties)
        return Utilities.registry_sections.active
    end
    -- construction not complete: setting up filters
    set_logistic_requests(properties)
    return Utilities.registry_sections.active
end

-------------------------------------------------------------------------------
---------------------------- DECONSTRUCTING STATE -----------------------------
-------------------------------------------------------------------------------

---Attempts to move building contents to physical inventory. Can be called
---in "deconstructing" state or during uninitialization.
---Has to be safe in all possible initialized states.
---@param properties EntityProperties
local function eject_building_contents(properties)
    ---@type LuaInventory assigned on initialization
    local inventory = properties.inventory
    -- inventory can be invalid during uninit
    if not inventory.valid then return end
    local contents = properties.building_contents
    -- table does not exist in all states
    if not contents then return end

    for key, entry in pairs(contents) do
        if entry.count > 0 then
            ---@diagnostic disable-next-line
            local inserted_count = inventory.insert(entry)
            local new_count = entry.count - inserted_count
            if new_count > 0 then
                entry.count = new_count
            else
                contents[key] = nil
            end
        else
            contents[key] = nil
        end
    end
end

---Used for on-tick updates of this entity in deconstructing state.
---@param properties EntityProperties
---@return EntityRegistrySection
local function deconstructing_state_update(properties)
    ---Assuming table exists in this state
    ---@type table<BufferKeyString, ItemBuffer>
    local contents = properties.building_contents
    if next(contents) then
        eject_building_contents(properties)
    end

    local is_empty = properties.inventory.is_empty()
    if not next(contents) and is_empty then
        -- Deconstruction is complete: changing state to idle
        properties.building_contents = nil
        properties.assigned_template = nil
        properties.state = entity_states.idle
        properties.status = Utilities.entity_status.idle
    end
    return Utilities.registry_sections.active
end

-------------------------------------------------------------------------------
------------------------------ OPERATIONAL STATE ------------------------------
-------------------------------------------------------------------------------

---Used to change entity state from "operational" to "deconstructing"
---@param properties EntityProperties
local function from_operational_to_deconstructing(properties)
    -- Removing crafting power and marking not operational
    ---@type string checking on initialization
    local cluster_uuid = properties.first_cluster
    local unit_number = properties.unit_number
    ClusterProcessor.remove_member_crafting_power(
        cluster_uuid,
        unit_number
    )
    ClusterProcessor.mark_member_not_operational(
        cluster_uuid,
        unit_number
    )

    properties.state = entity_states.deconstructing
    properties.status = Utilities.entity_status.deconstructing
end

---Used for on-tick updates of this entity in operational state.
---@param properties EntityProperties
---@return EntityRegistrySection
local function operational_state_update(properties)
    -- Checking for template change in the cluster
    local current_template = properties.assigned_template
    local cluster_template = ClusterProcessor.get_assigned_template(
        properties.first_cluster
    )
    if current_template == cluster_template then
        -- this is required to prevent problems in case template is
        -- "dropped" when it is assigned to the cluster
        ClusterProcessor.assign_member_crafting_power(
            properties.first_cluster,
            properties.unit_number,
            properties.capacity
        )
    else
        from_operational_to_deconstructing(properties)
    end
    return Utilities.registry_sections.active
end

-------------------------------------------------------------------------------
------------------------- UPDATE AND UNINITIALIZATION -------------------------
-------------------------------------------------------------------------------

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

    -- Managing logistic sections
    ---@type LuaLogisticPoint
    local log_point = properties.logistic_point
    log_point.trash_not_requested = true
    -- removing all sections from logistic point except first
    local section_count = log_point.sections_count
    for i = section_count, 2, -1 do
        log_point.remove_section(i)
    end
    -- one section is allowed is "constructing" state
    if properties.state ~= entity_states.constructing and section_count > 0 then
        log_point.remove_section(1)
    end

    -- State-specific updater
    local handler = update_router[properties.state]
    return handler(properties)
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function VMainframe.uninitialize(properties)
    eject_building_contents(properties)
    ClusterProcessor.remove_member_from_cluster(
        properties.first_cluster,
        properties.unit_number
    )
    properties.capacity = nil
    properties.inventory = nil
    properties.logistic_point = nil
    properties.state = nil
    properties.assigned_template = nil
    properties.building_requests = nil
    properties.building_contents = nil
    properties.logistic_filters = nil
    properties.filter_lookup = nil
    properties.logistic_section = nil
end

return VMainframe