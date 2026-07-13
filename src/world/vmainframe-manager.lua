--[[
Virtualization mainframe manager is used only by entity processor.
Virtualization mainframes serve as crafting power providers for virtualization clusters.
VM is a fancy requester chest. This manager does following things:
1. Checks selected_template and connects VM to appropriate cluster when necessery
2. Requests construction materials for selected template and makes it operational when necessery

-------------------------------------------------------------------------------
VIRTUALIZATION MAINFRAME PROPERTIES
-------------------------------------------------------------------------------
entity LuaEntity: reference to entity object 
unit_number number: unique entity identifier
selected_template string|nil (mainframe-io, mainframe): name of selected template (user input)
active_template string|nil (mainframe-io, mainframe): name of template in operation (assigned by processor)
cluster table|nil (mainframe-io, mainframe): reference to virtualization cluster that includes this entity
operational bool|nil (mainframe): true if mainframe has constructed a template and can operate
building_requests table|nil: contains buildings that are being requested for template construction
    2-level hmap: table[name][quality] = value
contained_buildings table|nil (mainframe): all buildings that are currently "contained" in the mainframe
    2-level hmap: table[name][quality] = value
--]]

local ClusterProcessor = require("src.simulation.cluster-processor")
local TemplateCompiler = require("src.simulation.template-compiler")

local VMManager = {}

---Returns all buildings that were used for template construction
---to physical inventory of vmainframe
---@param properties table entity properties from entity processor
local function return_buldings_to_inventory(properties)
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)

    -- iterating over everything contained in VM and inserting these
    -- items into VM physical inventory
    local buildings = properties.contained_buildings
    if not buildings then return end
    for name, q_counts in pairs(buildings) do
        for quality, count in pairs(q_counts) do
            if count > 0 then
                -- TODO: make sure everything fits
                inventory.insert({
                name = name,
                count = count,
                quality = quality
            })
            end
        end
    end
    properties.contained_buildings = {}
end

---Prepares for construction of new template: copies template building cost to requesting
---table, makes sure contained_buildings table has sections for all requesting items.
---@param properties table entity properties from entity processor
local function prepare_new_template_construction(properties)
    local template_name = properties.selected_template
    local build_cost = TemplateCompiler.get_building_cost(template_name)

    -- processing all items from building cost of new template
    local requests = {}
    local contents = {}
    for key, count in pairs(build_cost) do
        local name, quality = key:match("^(.+)//(.+)$")

        requests[name] = requests[name] or {}
        requests[name][quality] = count

        contents[name] = contents[name] or {}
        contents[name][quality] = 0
    end
    properties.building_requests = requests
    properties.contained_buildings = contents
end

---Adds everything from requests table to logistic requests of a given VM
---@param properties table entity properties from entity processor
local function set_logistic_requests(properties)
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

---Scans mainframe inventory and withdraws anything that is in building requests
---@param properties table entity properties from entity processor
local function withdraw_building_materials(properties)
    local requests = properties.building_requests
    if not requests then return end
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local inv_contents = inventory.get_contents()

    -- iterating over inventory contents
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

---On-tick processor of a virtualization mainframe
---@param properties table entity data from entity processor
function VMManager.process_vm(properties)
    -- handling template being changed
    if properties.selected_template ~= properties.active_template then
        -- managing template construction
        return_buldings_to_inventory(properties)
        prepare_new_template_construction(properties)

        -- removing VM from old cluster
        local old_cluster = properties.cluster
        ClusterProcessor.remove_from_cluster(old_cluster, properties.unit_number)

        -- adding VM to new cluster
        local template_name = properties.selected_template
        local entity = properties.entity
        local new_cluster = ClusterProcessor.add_to_cluster(entity, template_name)
        properties.cluster = new_cluster

        properties.active_template = properties.selected_template
        properties.operational = false
    end
    -- handling building requests (only if mainframe is not operational)
    if not properties.operational then
        withdraw_building_materials(properties)
        set_logistic_requests(properties)
        local requests = properties.building_requests
        if properties.active_template and (not requests or not next(requests)) then
            local cluster = properties.cluster
            local unit_number = properties.unit_number
            ClusterProcessor.set_mainframe_operational(cluster, unit_number)
            properties.operational = true
        end
    end
end

return VMManager