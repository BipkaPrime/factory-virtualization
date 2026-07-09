-- This mod introduces several entities that need to be tracked
-- and updated once in a while. For this, we need this entity registry.
-- We want it to do two things. First, it should contain 1-indexed array
-- with all data of entities that are "in" the registry for performance reasons.
-- Each tick we will process every 60-th element of that array with changing offset.
-- Second, we want to be able to access data for a given entity in O(1) time.
-- To achieve this, registry will consist of 2 parts:
--[[
storage.entity_registry = {
    -- main 1-indexed array
    array = {}, 
    -- hashmap for fast access with keys: entity.unit_number,
    -- and values: index of entity data in the main array
    lookup = {},
}
--]]

local util = require("util")
local vcluster = require("scripts.vcluster")

local Helper = {}

-------------------------------------------------------------------------------
-- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP
-------------------------------------------------------------------------------

-- Adds given entity to registry. Entity is assumed to be valid
local function register_entity(entity, entity_tags)
    -- avoiding duplicates
    local reg = storage.entity_registry
    if reg.lookup[entity.unit_number] then return end

    -- mandatory entity properties
    local properties = {
        entity = entity,
        unit_number = entity.unit_number,
    }

    -- handling ghost tags if there were any
    if entity_tags and entity_tags[PREFIX] then
        for tag, value in pairs(entity_tags[PREFIX]) do
            if type(value) == "table" then
                properties[tag] = util.table.deepcopy(value)
            else
                properties[tag] = value
            end
        end
    end

    -- adding table to registry
    table.insert(reg.array, properties)
    reg.lookup[entity.unit_number] = #reg.array
end

-- Removes given entity from registry. Used for automatic garbage collection.
local function unregister_entity(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]

    -- removing entity from vcluster
    local properties = reg.array[index]
    vcluster.remove_from_cluster(properties)

    -- swapping element we want to delete with the last one
    local last_element = reg.array[#reg.array]
    reg.array[index] = last_element
    reg.lookup[last_element.unit_number] = index

    -- removing last element from both tables 
    table.remove(reg.array)
    reg.lookup[unit_number] = nil
end

-- Returns table describing entity from entity registry
-- @param unit_number int: unique entity identifier
function Helper.get_entity_data(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]
    if not index then return end
    return reg.array[index]
end

-------------------------------------------------------------------------------
-- TEMPLATE IO HANDLERS
-------------------------------------------------------------------------------
-- Template IOs help in creation of templates. They serve as inputs and outputs
-- of items, fluids and electric energy on virtualization surfaces.

-- Template IOs can have following properties:
-- entity LuaEntity: reference to entity
-- unit_number uint64: unit number of this entity (not really relevant while entity is valid)
-- is_output bool: true if IO is an output. By default IO is considered an input.
-- selected_item table (only for item IOs): {name = name, quality = quality}
-- selected_fluid string (only for fluid IOs): fluid name, for example "water", "oil", etc.

local function process_template_item_io(properties)
    -- does not operate without selected item
    local item = properties.selected_item
    if not item then return end

    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    if not storage.v_surfaces[entity.surface_index] then return end

    -- removing or adding selected item to physical inventory
    -- and storing delta in venv if surface is compiling
    local inventory = entity.get_inventory(defines.inventory.chest)
    local venv = storage.compiling_surfaces[entity.surface_index]
    if properties.is_output then
        local removed_count = inventory.remove({
            name = item.name,
            quality = item.quality,
            count = 1000000,
        })
        -- checking if vsurface is compiling
        if not venv then return end
        local section = venv.output.items
        section[item.name] = section[item.name] or {}
        section[item.name][item.quality] = section[item.name][item.quality] or 0
        section[item.name][item.quality] = section[item.name][item.quality] + removed_count
    else
        local inserted_count = inventory.insert({
            name = item.name,
            quality = item.quality,
            count = 1000000,
        })
        -- checking if vsurface is compiling
        if not venv then return end
        local section = venv.input.items
        section[item.name] = section[item.name] or {}
        section[item.name][item.quality] = section[item.name][item.quality] or 0
        section[item.name][item.quality] = section[item.name][item.quality] + inserted_count
    end
end

local function process_template_fluid_io(properties)
    -- does not operate without selected fluid
    local fluid = properties.selected_fluid
    if not fluid then return end

    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    if not storage.v_surfaces[entity.surface_index] then return end

    -- removing or adding selected fluid to physical inventory
    -- and storing delta in venv if surface is compiling
    local venv = storage.compiling_surfaces[entity.surface_index]
    if properties.is_output then
        local drained_amount = entity.extract_fluid({
            name = fluid.name,
            amount = 1000000
        })
        -- checking if vsurface is compiling
        if not venv then return end
        local section = venv.output.fluids
        section[fluid.name] = section[fluid.name] or 0
        section[fluid.name] = section[fluid.name] + drained_amount
    else
        local inserted_amount = entity.insert_fluid({
            name = fluid.name,
            amount = 1000000
        })
        -- checking if vsurface is compiling
        if not venv then return end
        local section = venv.input.fluids
        section[fluid.name] = section[fluid.name] or 0
        section[fluid.name] = section[fluid.name] + inserted_amount
    end
end

local function process_template_energy_io(properties)
    -- does not operate on any surfaces except vsufaces
    local entity = properties.entity
    if not storage.v_surfaces[entity.surface_index] then return end

    -- removing or adding energy to this IO
    -- and storing delta in venv if surface is compiling
    local venv = storage.compiling_surfaces[entity.surface_index]
    local max_buffer = entity.electric_buffer_size
    local current_energy = entity.energy
    if properties.is_output then
        entity.energy = 0
        -- checking if vsurface is compiling
        if not venv then return end
        venv.output.energy = venv.output.energy + current_energy
    else
        local inserted_energy = max_buffer - current_energy
        entity.energy = entity.electric_buffer_size
        -- checking if vsurface is compiling
        if not venv then return end
        venv.input.energy = venv.input.energy + inserted_energy
    end
end

-------------------------------------------------------------------------------
-- MAINFRAME IO HANDLERS
-------------------------------------------------------------------------------
-- Mainframe IOs are used for transfering items to/from vclusters.
-- Mainframe IOs can have following properties:
-- entity LuaEntity: reference to entity
-- unit_number uint64: unit number of this entity (not really relevant while entity is valid)
-- selected_template string: selected template for a given entity if any (user input)
-- is_output bool: true if IO is an output. By default IO is considered an input.
-- active_template string: name of template currently in operation
-- selected_item table (only for item IOs): {name = name, quality = quality}
-- selected_fluid string (only for fluid IOs): fluid name, for example "water", "oil", etc.
-- cluster table: reference to virtualization cluster that owns this IO if any.

-- Checks if template change has occured and in case it did,
-- moves mainframe IO to the new virtualization cluster 
local function mainframe_io_template_change(properties)
    if properties.selected_template ~= properties.active_template then
        vcluster.remove_from_cluster(properties)
        vcluster.add_to_cluster(properties)
        properties.active_template = properties.selected_template
    end
end

local function process_mainframe_item_io(properties)
    -- does not operate without selected item
    local item = properties.selected_item
    if not item then return end

    -- checking if template has changed
    mainframe_io_template_change(properties)

    -- does not operate without connecting to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting the buffer for the item and checking its existance
    local buffer_section = (properties.is_output and "output") or "input"
    local key = item.name .. "//" .. item.quality
    local buffer = cluster[buffer_section][key]
    if not buffer then return end

    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local flow_limit = storage.entity_params[entity.name].flow_limit
    if properties.is_output then
        -- moving items from cluster to physical inventory
        local available_count = math.floor(buffer.current)
        if available_count <= 0 then return end
        local inserted_count = inventory.insert({
            name = item.name,
            quality = item.quality,
            count = math.min(flow_limit, available_count)
        })
        buffer.current = buffer.current - inserted_count
    else
        -- moving items from physical inventory to cluster
        local available_space = math.floor(buffer.maximum - buffer.current)
        if available_space <= 0 then return end
        local removed_count = inventory.remove({
            name = item.name,
            quality = item.quality,
            count = math.min(flow_limit, available_space)
        })
        buffer.current = buffer.current + removed_count
    end
end

local function process_mainframe_fluid_io(properties)
    -- does not operate without selected fluid
    local fluid = properties.selected_fluid
    if not fluid then return end

    -- checking if template has changed
    mainframe_io_template_change(properties)

    -- does not operate without connecting to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting the buffer for the fluid and checking its existance
    local buffer_section = (properties.is_output and "output") or "input"
    local buffer = cluster[buffer_section][fluid]
    if not buffer then return end

    local entity = properties.entity
    local flow_limit = storage.entity_params[entity.name].flow_limit
    if properties.is_output then
        -- moving fluid from vcluster to physical inventory
        local available_amount = math.floor(buffer.current)
        if available_amount <= 0 then return end
        local inserted_amount = entity.insert_fluid({
            name = fluid.name,
            amount = math.min(flow_limit, available_amount)
        })
        buffer.current = buffer.current - inserted_amount
    else
        -- moving fluid from physical inventory to vcluster
        local available_space = math.floor(buffer.maximum - buffer.current)
        if available_space <= 0 then return end
        local removed_amount = entity.extract_fluid({
            name = fluid.name,
            amount = math.min(flow_limit, available_space)
        })
        buffer.current = buffer.current + removed_amount
    end
end

local function process_mainframe_energy_io(properties)
    -- checking if template has changed
    mainframe_io_template_change(properties)

    -- making sure uplink is connected to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting buffer for the energy and checking its existance
    local key = ("energy_output" and properties.is_output) or "energy_input"
    local buffer = cluster[key]
    if not buffer then return end

    local entity = properties.entity
    local flow_limit = storage.entity_params[entity.name].flow_limit
    if properties.is_output then
        -- moving energy from vcluster to entity
        local available_amount = math.floor(buffer.current)
        if available_amount <= 0 then return end
        local available_space = entity.electric_buffer_size - entity.energy
        local transfered = math.min(flow_limit, available_space, available_amount)
        entity.energy = entity.energy + transfered
        buffer.current = buffer.current - transfered
    else
        -- moving energy from entity to vcluster
        local available_space = math.floor(buffer.maximum - buffer.current)
        if available_space <= 0 then return end
        local transfered = math.min(available_space, flow_limit, entity.energy)
        entity.energy = entity.energy - transfered
        buffer.current = buffer.current + transfered
    end
end

-------------------------------------------------------------------------------
-- VIRTUALIZATION MAINFRAME HANDLER
-------------------------------------------------------------------------------
-- Virtualization mainframes allow "running" compiled templates.
-- By running I mean transforming inputs into outputs at rates defined in template.
-- But this comes at a price. Before mainframe can operate, it has to be provided
-- with buildings specified in the template. VM is a fancy requester chest.

-- Virtualization mainframe can have the following properties in entity registry:
-- entity LuaEntity: reference to entity
-- unit_number uint64: unit number of this entity (not really relevant while entity is valid)
-- selected_template string: selected template for a given entity if any (user input)
-- active_template string: name of template currently in operation (constructing or running)
-- operational bool: true if mainframe has constructed a template and can operate
-- building_requests table: contains buildings that are being requested for template construction
--      2-level hmap: table[name][quality] = value
-- contained_buildings table: all buildings that are currently "contained" in the mainframe
-- cluster table: reference to virtualization cluster that has this mainframe as a member


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

-- On-tick processor of a virtualization mainframe
local function process_virtualization_mainframe(properties)
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

-------------------------------------------------------------------------------
-- MAIN PART: SUBSCRIBING TO BUILD EVENTS AND ON-TICK PROCESSOR
-------------------------------------------------------------------------------

-- maps entity names to their on-tick handlers
local entity_router = {
    [PREFIX .. "template-item-io"] = process_template_item_io,
    [PREFIX .. "template-fluid-io"] = process_template_fluid_io,
    [PREFIX .. "template-energy-io"] = process_template_energy_io,
    [PREFIX .. "mainframe-item-io"] = process_mainframe_item_io,
    [PREFIX .. "mainframe-fluid-io"] = process_mainframe_fluid_io,
    [PREFIX .. "mainframe-energy-io"] = process_mainframe_energy_io,
    [PREFIX .. "virtualization-mainframe"] = process_virtualization_mainframe,
}

-- Used to subscibe to all "build events" allowing 
function Helper.subscribe_to_build_events()
    -- all events that can be triggered when entity is built
    local build_events = {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity,
        defines.events.on_space_platform_built_entity,
        defines.events.script_raised_revive
    }

    -- function that is called when entity is built
    local function on_entity_built(event)
        local entity = event.entity
        if not entity or not entity.valid then return end
        register_entity(entity, event.tags)
    end

    -- creating filter based on entity_router
    local build_filter = {}
    for building_name, _ in pairs(entity_router) do
        table.insert(build_filter, {filter = "name", name = building_name})
    end

    -- subsribing to all "build events"
    for _, event in ipairs(build_events) do
        script.on_event(event, on_entity_built, build_filter)
    end
end

-- Used for on-tick entity processing
function Helper.entity_processor(event)
    local reg = storage.entity_registry
    -- processing every 60-th element each tick
    local offset = event.tick % 60
    for i = #reg.array - offset, 1, -60 do
        local properties = reg.array[i]
        local entity = properties.entity
        if entity.valid then
            local handler = entity_router[entity.name]
            handler(properties)
        else
            -- auto garbage collection
            unregister_entity(properties.unit_number)
        end
    end
end

return Helper