-- This file contains on-tick handler for virtualization mainframes.

-- Virtualization mainframes allow "running" compiled templates.
-- By running I mean transforming inputs into outputs at rates defined in template.
-- But this comes at a price. Before mainframe can operate, it has to be provided
-- with buildings specified in the template. I think the best approach to this is 
-- to make virtualization mainframe a fancy requester chest.

-- When we detect that selected template has changed for a given mainframe we need to
-- take several actions regarding template "building". First, create logistic requests for all 
-- items required for building new template. Second, if mainframe contains something 
-- (from previous template) return everything to physical inventory.

-- create logistic requests for all building materials. Once provided with all 
-- needed materials, mainframe can start normal operation.

--------------------------------------------------------------------------------------------
-- VIRTUALIZATION MAINFRAME PROPERTIES
--------------------------------------------------------------------------------------------
-- entity LuaEntity: reference to entity
-- unit_number uint64: unit number of this entity (not really relevant while entity is valid)
-- selected_template string: selected template for a given entity if any (user input)
-- active_template string: name of template currently in operation (constructing or running)
-- operational bool: true if mainframe has constructed a template and can operate
-- building_requests table: contains buildings that are being requested for template construction
--      2-level hmap: table[name][quality] = value
-- contained_buildings table: all buildings that are currently "contained" in the mainframe
-- cluster table: reference to virtualization cluster that has this mainframe as a member


-- Virtualization mainframes and uplinks/downlinks placed on the same surface and 
-- having the same template selected form a "Virtualization Cluster".
-- This cluster is associated with a table in storage.vclusters[template_name][surface_idx]
-- It stores everything needed for operation of the system.
-- We need to keep track of all members of the same system for several reasons.
-- First, we want to adjust IO buffers based on number of VMs in the system.
-- Second, we want to discourage players from building members of the same system too far apart,
-- because in this case they get free item teleportation. To solve this we introduce an energy penalty.
-- When entity is processed in the entity registry, it checks the distance from it to the center of mass
-- of the system it is a part of and subtracts the penalty from input energy buffer.

-- For energy penalty idea to work properly, we want several accurate datapoints.
-- First, we need entity properties from registry to contain a reference to associated
-- virtual cluster in order to easily access it during an on-tick entity update.
-- Second, we need vcluster to contain table with all members
-- with key being unit number and value being a table containing all necessery information
-- like pos_x, pos_y of entity.
-- Third, we want to store information needed to calculate center of mass of a system.
-- sum_x, sum_y, total_weight (member count if we assume that all members have a weight of 1).
-- This allows to calculate center of mass in O(1) time as well as addition and deletion
-- of entities in O(1) time.

local vcluster = require("scripts.entity.vcluster")

local Helper = {}

-- Returns all buildings that were used for template construction
-- to physical inventory of vmainframe
local function deconstruct_old_template(properties)
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local buildings = properties.contained_buildings
    if not buildings then return end
    for name, q_counts in pairs(buildings) do
        for quality, count in pairs(q_counts) do
            if count > 0 then
                -- TODO: make sure everything fits
                local inserted_count = inventory.insert({
                name = name,
                count = count,
                quality = quality
            })
            end
        end
    end
    properties.contained_buildings = {}
end

-- Prepares for construction of new template: copies template building
-- cost to requesting table, makes sure containing table has sections for
-- all requesting items.
local function request_new_template(properties)
    properties.building_requests = {}
    local template_name = properties.selected_template
    if not template_name then return end
    local template = storage.compiled_templates[template_name]
    if not template then return end
    local build_cost = template.building_cost
    if not build_cost then return end
    -- initializing requesting and containing tables
    properties.contained_buildings = properties.contained_buildings or {}
    local requests = properties.building_requests
    local contents = properties.contained_buildings
    -- processing all items from building cost of new template
    for name, q_counts in pairs(build_cost) do
        requests[name] = {}
        contents[name] = contents[name] or {}
        for quality, count in pairs(q_counts) do
            requests[name][quality] = count
            contents[name][quality] = contents[name][quality] or 0
        end
    end
end

-- Adds everything from requests table to logistic
-- requests of given mainframe
local function set_construction_requests(properties)
    local entity = properties.entity
    local log_point = entity.get_requester_point()
    log_point.trash_not_requested = true
    local section_count = log_point.sections_count
    -- removing all logistic sections
    for i = section_count, 1, -1 do
        log_point.remove_section(i)
    end
    -- creating one logistic section
    log_point.add_section()
    local log_section = log_point.get_section(1)
    local curr_slot = 1
    local requests = properties.building_requests
    if not requests then return end
    for name, q_counts in pairs(requests) do
        for quality, count in pairs(q_counts) do
            local filter = {
                value = {name = name, quality = quality},
                min = count,
                max = count,
            }
            log_section.set_slot(curr_slot, filter)
            curr_slot = curr_slot + 1
        end
    end
end

-- Scans mainframe inventory and withdraws anything
-- that is in building requests
local function withdraw_building_materials(properties)
    local requests = properties.building_requests
    if not requests then return end
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local inv_contents = inventory.get_contents()
    for _, item in ipairs(inv_contents) do
        local section = requests[item.name]
        if section and section[item.quality] then
            local demand = section[item.quality]
            local removed_count = inventory.remove({
                name = item.name,
                quality = item.quality,
                count = math.min(demand, item.count),
            })
            -- updating requests table
            section[item.quality] = section[item.quality] - removed_count
            if section[item.quality] == 0 then section[item.quality] = nil end
            if not next(section) then requests[item.name] = nil end
            -- updating contained_buildings table
            if removed_count > 0 then
                local cont_section = properties.contained_buildings[item.name]
                cont_section[item.quality] = cont_section[item.quality] + removed_count
            end
        end
    end
end

-- On-tick processor for virtualization mainframes
function Helper.update_vmainframe(properties)
    -- handling template being changed
    if properties.selected_template ~= properties.active_template then
        -- managing template construction
        deconstruct_old_template(properties)
        request_new_template(properties)
        -- moving VM to new vcluster
        vcluster.remove_from_cluster(properties)
        vcluster.add_to_cluster(properties)
        properties.active_template = properties.selected_template
        properties.operational = false
    end
    -- handling building requests (only if mainframe is not operational)
    if not properties.operational then
        withdraw_building_materials(properties)
        set_construction_requests(properties)
        local requests = properties.building_requests
        if properties.active_template and (not requests or not next(requests)) then
            vcluster.set_mainframe_operational(properties)
            properties.operational = true
        end
    end
end


return Helper