-- This file is used for managing virtualization clusters.

-- Virtualization mainframes and mainframe-IOs placed on the same surface and 
-- having the same template selected form a "Virtualization Cluster".
-- This cluster is associated with a table in storage.vclusters[template_name][surface_idx]
-- It stores everything needed for operation of the system.

--------------------------------------------------------------------------------------------
-- VIRTUALIZATION CLUSTER KEYS
--------------------------------------------------------------------------------------------
-- surface_index int: index of a surface this cluster is located at. Used for cluster deletion.
-- template_name string: name of template associated with this cluster. Used for cluster deletion.
-- deleted bool: true if cluster was deleted and should be removed from cluster processing
-- research_producer bool: true if template is type 2
-- input/output tables: ingredient/product buffers for items and fluids. For items key is name//quality;
--      for fluids key is fluid name. Value is a table containing data about the buffer:
--      Keys: current (float), per_craft (float), maximum (float), statistics (LuaFlowStatistics)
--[[
For example:
input = {
    "iron-gear//rare" = {current = 50, per_craft = 150, maximum = 5000, statistics = LuaFlowStatistics},
    "steel-plate//normal" = {current = 50, per_craft = 150, maximum = 5000, statistics = LuaFlowStatistics},
    "water" = {current = 50, per_craft = 150, maximum = 5000, statistics = LuaFlowStatistics},
}
First number defines currently available amount, second number amount needed to perform 1 operation.
Third number is the maximum amount that can fit. That maximum buffer size is recalculated every time
that number operational VMs in the cluster changes. Keys for input/output tables are defined at the moment
of cluster creation based on the template and never change.
--]]
-- energy_input table: input buffer for energy. Like fluid/item buffer except it does not contain statistics
-- energy_output table: output buffer for energy. Like fluid/item buffer except it does not contain statistics
-- member_counts table: key is entity name (string), value is entity count (int)
-- members table: key is unit_number, value is {} containing x, y, weight, name, operational_vm (bool) of an entity.
--                it's needed for deletion of an invalid entity from the cluster
-- operational_vms integer: number of operational virtualization mainframes in the cluster
-- sum_x float: weighted sum of x coordinates of all members
-- sum_y float: weighted sum of y coordinates of all members
-- total_weight float: sum of weights of all members
-- sum_squares float: weighted sum of squares of all member positions (x^2 + y^2) * weight
-- total_energy_tax float: sum of all energy taxes (for distance from center) for all entities
-- base_energy_per_craft float: base electric energy consumption per craft
-- last_cycle_crafts integer/nil: number of crafts performed in the last crafting cycle
-- force LuaForce: reference to force that owns this cluster

local misc = require("scripts.misc")

local Helper = {}

-------------------------------------------------------------------------------
-- VCLUSTER CREATION
-------------------------------------------------------------------------------

-- Helps in creation of a new vcluster. Convers 2-level hmap input_table 
-- containing item flows in the form table[name][quality] = count to the form
-- used in vluster IO tables. Adds data to output table.
local function add_items(input_table, output_table, statistics)
    if not input_table then return end
    for name, q_counts in pairs(input_table) do
        for quality, count in pairs(q_counts) do
            local key = name .. "//" .. quality
            output_table[key] = {
                current = 0,
                per_craft = count,
                maximum = 0,
                statistics = statistics,
            }
        end
    end
end

-- Helps in creation of a new vcluster. Convers hmap input_table
-- containing fluids in the form table[name] = count to the form 
-- used in vcluster IO tables. Adds data to output table.
local function add_fluids(input_table, output_table, statistics)
    if not input_table then return end
    for name, count in pairs(input_table) do
        output_table[name] = {
            current = 0,
            per_craft = count,
            maximum = 0,
            statistics = statistics,
        }
    end
end

-- key: entity.name (string); value: entity weight (float).
-- contains all building names which can be a part of a cluster.
local entity_weights = {
    [PREFIX .. "mainframe-item-io"] = 1,
    [PREFIX .. "mainframe-fluid-io"] = 1,
    [PREFIX .. "mainframe-energy-io"] = 1,
    [PREFIX .. "virtualization-mainframe"] = 4,
}
-- Gets an existing virtualization cluster from storage or creates one.
-- @returns table/nil: cluster or nil if one could not have been created
local function get_or_create_cluster(template_name, surface_index)
    -- safety checks: arguments provided, template exists
    if not template_name or not surface_index then return end
    local template = storage.compiled_templates[template_name]
    if not template then return end

    -- attempting to find the cluster and returning it if successfull
    storage.vclusters[template_name] = storage.vclusters[template_name] or {}
    if storage.vclusters[template_name][surface_index] then
        return storage.vclusters[template_name][surface_index]
    end

    -- creating the cluster if it was not found
    storage.vclusters[template_name][surface_index] = {
        surface_index = surface_index,
        template_name = template_name,
        research_producer = (template.type == 2),
        input = {},
        output = {},
        member_counts = {},
        members = {},
        operational_vms = 0,
        sum_x = 0,
        sum_y = 0,
        total_weight = 0,
        sum_squares = 0,
        total_energy_tax = 0,
    }
    local cluster = storage.vclusters[template_name][surface_index]

    -- getting cluster force and production statistics
    if storage.v_surfaces[surface_index] then
        cluster.force = game.forces["lab-technical"]
    else
        cluster.force = game.forces["player"]
    end
    local item_statistics = cluster.force.get_item_production_statistics(surface_index)
    local fluid_statistics = cluster.force.get_fluid_production_statistics(surface_index)

    -- collecting template inputs
    local t_input = template.input
    local energy_input = 0
    if t_input then
        add_items(t_input.items, cluster.input, item_statistics)
        add_fluids(t_input.fluids, cluster.input, fluid_statistics)
        energy_input = t_input.energy
    end

    -- adding input for energy
    local area = template.area
    local energy_drain = misc.template_area_to_power(area)
    cluster.energy_input = {
        current = 0,
        per_craft = energy_input + energy_drain,
        maximum = 0,
    }
    cluster.base_energy_per_craft = energy_input + energy_drain

    -- collecting template outputs
    local t_output = template.output
    if t_output then
        add_items(t_output.items, cluster.output, item_statistics)
        add_fluids(t_output.fluids, cluster.output, fluid_statistics)
        if t_output.energy then
            cluster.energy_output = {
                current = 0,
                per_craft = t_output.energy,
                maximum = 0,
            }
        end
    end
    -- adding created cluster to processing list
    table.insert(storage.cluster_list, cluster)
    return cluster
end

-------------------------------------------------------------------------------
-- VCLUSTER UPDATE OPERAIONS: ADD/REMOVE MEMBER, ETC.
-------------------------------------------------------------------------------

-- Recalculates buffer sizes for a given cluster.
-- Buffer sizes depend on number of operational vmainframes.
local function update_buffer_size(cluster)
    local multiplier = cluster.operational_vms or 0
    local input = cluster.input
    for _, buffer in pairs(input) do
        buffer.maximum = 2 * buffer.per_craft * multiplier
    end
    local output = cluster.output
    for _, buffer in pairs(output) do
        buffer.maximum = 2 * buffer.per_craft * multiplier
    end
    local energy_input = cluster.energy_input
    if energy_input then
        energy_input.maximim = 2 * energy_input.per_craft * multiplier
    end
    local energy_output = cluster.energy_output
    if energy_output then
        energy_output.maximim = 2 * energy_output.per_craft * multiplier
    end
end

-- To encourage players to build compact clusters, we introduce 
-- energy tax based on how far cluster members are from it's center.
-- Tax for one building is calculated like this:
-- BASE_COST*(dist(center, building_pos))^2, where center is a weighted
-- average for coordinates of all members.
-- Total tax should be equal to the sum of above expression for all members.
-- It turns out that this sum can be calculated in O(1) time if we have
-- access to the following values:
-- center coordinates, total weight, weighted sum of (x^2 + y^2) for all members.
local base_rate = 1e-5
local function update_total_energy_tax(cluster)
    -- if total weight of cluster is 0, tax is 0.
    if cluster.total_weight == 0 then
        cluster.total_energy_tax = 0
        return
    end
    -- calculating weighted average of coordinates (center of cluster)
    local center_x = cluster.sum_x / cluster.total_weight
    local center_y = cluster.sum_y / cluster.total_weight
    -- calculating total tax
    local correction = cluster.total_weight * (center_x * center_x + center_y * center_y)
    cluster.total_energy_tax = base_rate * (cluster.sum_squares - correction)
    -- correcting cluster energy consumption
    local base_cost = cluster.base_energy_per_craft
    local energy_tax = cluster.total_energy_tax
    cluster.energy_input.per_craft = base_cost + energy_tax
end

-- Adds an entity from entity registry to a virtualization cluster.
-- The cluster is decided automatically based on template name and
-- surface entity is located on. Entity is assumed to be valid.
-- This function is only called from on-tick registry processing
-- when selected_template changes.
-- @param properties table: entity properties from registry
function Helper.add_to_cluster(properties)
    -- checking that template is selected
    local template_name = properties.selected_template
    if not template_name then return end

    -- getting appropriate cluster for entity
    local entity = properties.entity
    local cluster = get_or_create_cluster(template_name, entity.surface_index)
    if not cluster then return end
    properties.cluster = cluster

    -- updating cluster table
    local x, y = entity.position.x, entity.position.y
    local name = entity.name
    local weight = entity_weights[name]
    cluster.member_counts[name] = (cluster.member_counts[name] or 0) + 1
    cluster.sum_x = cluster.sum_x + x * weight
    cluster.sum_y = cluster.sum_y + y * weight
    cluster.sum_squares = cluster.sum_squares + weight * (x * x + y * y)
    cluster.total_weight = cluster.total_weight + weight
    cluster.members[entity.unit_number] = {
        x = x,
        y = y,
        weight = weight,
        name = name
    }
    update_total_energy_tax(cluster)
    update_buffer_size(cluster)
end

-- Removes an entity from its virtualization cluster if it's associated with one.
-- Entity can be invalid when this function is called.
-- @param properties table: entity properties from registry
function Helper.remove_from_cluster(properties)
    -- removing cluster reference from entity properties
    local cluster = properties.cluster
    if not cluster then return end
    properties.cluster = nil

    -- getting member data from cluster members table
    local unit_number = properties.unit_number
    local member_data = cluster.members[unit_number]
    local x, y = member_data.x, member_data.y
    local weight, name = member_data.weight, member_data.name
    local operational_vm = member_data.operational_vm
    cluster.members[unit_number] = nil

    -- correcting member counts
    local m_counts = cluster.member_counts
    m_counts[name] = m_counts[name] - 1
    if m_counts[name] == 0 then m_counts[name] = nil end

    -- cleanup: deleting cluster if it has no members left
    if not next(cluster.member_counts) then
        cluster.deleted = true
        local template_name = cluster.template_name
        local surface_index = cluster.surface_index
        storage.vclusters[template_name][surface_index] = nil
        if not next(storage.vclusters[template_name]) then
            storage.vclusters[template_name] = nil
        end
        return
    end

    -- correcting coordinate sums and total weight
    cluster.sum_x = cluster.sum_x - x * weight
    cluster.sum_y = cluster.sum_y - y * weight
    cluster.sum_squares = cluster.sum_squares - weight * (x * x + y * y)
    cluster.total_weight = cluster.total_weight - weight
    -- correcting operational_vm count
    if operational_vm then cluster.operational_vms = cluster.operational_vms - 1 end
    -- correcting buffers and total energy tax
    update_total_energy_tax(cluster)
    update_buffer_size(cluster)
end

-- Marks a given virtualization mainframe operational inside
-- its virtualization cluster and adjusts crafting potential and buffers.
function Helper.set_mainframe_operational(properties)
    local cluster = properties.cluster
    if not cluster then return end

    -- marking mainframe operational
    local unit_number = properties.unit_number
    local member_data = cluster.members[unit_number]
    member_data.operational_vm = true

    -- updating crafting potential and buffer sizes
    cluster.operational_vms = cluster.operational_vms + 1
    update_buffer_size(cluster)
end

-------------------------------------------------------------------------------
-- VCLUSTER CRAFTING PROCESSOR 
-------------------------------------------------------------------------------

-- Helps with processing crafts inside clusters. Calculates
-- amount of crafts that can be made with input ingredients.
local function get_input_crafts(cluster)
    local max_crafts = 1e9
    for _, buffer in pairs(cluster.input) do
        local curr_crafts = math.floor(buffer.current / buffer.per_craft)
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    local energy = cluster.energy_input
    if energy then
        local curr_crafts = math.floor(energy.current / energy.per_craft)
        max_crafts = math.min(max_crafts, curr_crafts)
    end

    return max_crafts
end

-- Helps with processing crafts inside clusters. Calculates
-- amount of crafts that can fit in the output.
local function get_output_crafts(cluster)
    local max_crafts = 1e9
    for _, buffer in pairs(cluster.output) do
        local curr_crafts = math.floor((buffer.maximum - buffer.current) / buffer.per_craft)
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    local energy = cluster.energy_output
    if energy then
        local curr_crafts = math.floor(energy.maximum - energy.current / energy.per_craft)
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    return max_crafts
end

-- Performs a craft for a vcluster.
local function perform_craft(cluster)
    if not cluster.research_producer then
        -- cluster crafting potential
        local max_crafts = cluster.operational_vms
        if max_crafts == 0 then
           cluster.last_cycle_crafts = 0
           return
        end

        -- calculating buffers limitations
        local input_crafts = get_input_crafts(cluster)
        local output_crafts = get_output_crafts(cluster)
        max_crafts = math.min(max_crafts, input_crafts, output_crafts)
        if max_crafts <= 0 then
            cluster.last_cycle_crafts = 0
            return
        end

        -- removing ingredients from input
        for _, buffer in pairs(cluster.input) do
            buffer.current = buffer.current - buffer.per_craft * max_crafts
            -- TODO: add to statistics
        end
        local energy_in = cluster.energy_input
        if energy_in then
            energy_in.current = energy_in.current - energy_in.per_craft * max_crafts
        end

        -- adding products to output
        for _, buffer in pairs(cluster.output) do
            buffer.current = buffer.current + buffer.per_craft * max_crafts
            -- TODO: add to statistics
        end
        local energy_out = cluster.energy_output
        if energy_out then
            energy_out.current = energy_out.current + energy_out.per_craft * max_crafts
        end

        cluster.last_cycle_crafts = max_crafts
    end
end

-- On-tick cluster crafting processor
function Helper.process_clusters(event)
    local array = storage.cluster_list
    local offset = event.tick % 60
    for i = #array - offset, 1, -60 do
        local cluster = array[i]
        if cluster.deleted then
            -- moving cluster to the last position and deleting it
            local last_cluster = array[#array]
            array[i] = last_cluster
            array[#array] = nil
        else
            perform_craft(cluster)
        end
    end
end

return Helper