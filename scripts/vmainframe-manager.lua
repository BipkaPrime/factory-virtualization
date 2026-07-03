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
-- requesting bool: true if mainframe is requesting anything for constructions
-- operational bool: true if mainframe has constructed a template and can operate
-- requesting_buildings table: contains buildings that are being requested for template construction
--      2-level hmap: table[name][quality] = value
-- contained_buildings table: all buildings that are currently "contained" in the mainframe


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
    properties.contained_buildings = nil
end

-- Prepares for construction of new template: copies template building
-- cost to requesting table, makes sure containing table has sections for
-- all requesting items.
local function construct_new_template(properties)
    local template_name = properties.selected_template
    if not template_name then return end
    local template = storage.compiled_templates[template_name]
    local build_cost = template.building_cost
    if not build_cost then return end
    -- initializing requesting and containing tables
    properties.requesting_buildings = {}
    properties.contained_buildings = properties.contained_buildings or {}
    local requests = properties.requesting_buildings
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

-- Handles template name being changed. This is called when
-- selected_template ~= active template
local function handle_template_change(properties)
    deconstruct_old_template(properties)
    construct_new_template(properties)
    properties.active_template = properties.selected_template
    properties.operational = false
    properties.requesting = true
end

-- Adds everything from requesting_buildings to logistic
-- requests of given mainframe
local function set_construction_requests(properties)
    local entity = properties.entity
    local log_point = entity.get_requester_point()
    local section_count = log_point.sections_count
    -- removing all logistic sections
    for i = section_count, 1, -1 do
        log_point.remove_section(i)
    end
    -- creating one logistic section
    log_point.add_section()
    local log_section = log_point.get_section(1)
    local requests = properties.requesting_buildings
    local curr_slot = 1
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
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    game.print("1")
    local requests = properties.requesting_buildings
    if not requests then return end
    game.print("2")
    local inv_contents = inventory.get_contents()
    game.print("3")
    for _, item in ipairs(inv_contents) do
        local section = requests[item.name]
        if section and section[item.quality] then
            game.print("4")
            local demand = section[item.quality]
            local removed_count = inventory.remove({
                name = item.name,
                quality = item.quality,
                count = math.min(demand, item.count),
            })
            game.print(removed_count)
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
    if properties.selected_template ~= properties.active_template then
        handle_template_change(properties)
    end
    if properties.requesting then
        withdraw_building_materials(properties)
        set_construction_requests(properties)
        local requests = properties.requesting_building
        if not requests or not next(requests) then
            properties.requesting = false
            properties.operational = true
        end
    end
    --game.print(serpent.block(properties.requesting_buildings))
end


return Helper