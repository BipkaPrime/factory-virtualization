-- This file is used for managing virtualization clusters.

--------------------------------------------------------------------------------------------
-- VIRTUALIZATION CLUSTER KEYS
--------------------------------------------------------------------------------------------
-- surface_index int: index of a surface this cluster is located at. Used for cluster deletion
--      in case last member was invalid.
-- research_producer bool: true if template is type 2
-- input/output tables: store current, required and maximum counts for all inputs/outputs. These store
--      items, fluid and energy. For fluids key is fluid name, for items: name//quality
--      for energy: electric_energy. For example:
--[[  
input = {
    "iron-gear//rare" = {50, 150, 5000},
    "steel-plate//normal" = {500, 100, 500},
    "water" = {100, 200, 1000},
    "electric_energy" = {500, 200, 2000}
}
First number defines currently available amount, second number amount needed to perform 1 operation.
Third number is the maximum amount that can fit. That maximum buffer size is recalculated every time
that number of members in the cluster changes. Keys for input/output tables are defined at the moment
of cluster creation based on the template and never change.
--]]
-- member_count int: number of members in the cluster
-- members table: key is unit_number, value is {} containing information like pos_x, pos_y of entity
-- sum_x float: weighted sum of x coordinates of all members
-- sum_y float: weighted sum of y coordinates of all members
-- total_weight float: sum of weights of all members

local misc = require("scripts.misc")

local Helper = {}


-- Helps in creation of a new vcluster. Convers 2-level hmap input_table 
-- containing item flows in the form table[name][quality] = count to the form
-- used in vluster IO tables. Adds data to output table.
local function add_items(input_table, output_table)
    if not input_table then return end
    for name, q_counts in pairs(input_table) do
        for quality, count in pairs(q_counts) do
            local key = name .. "//" .. quality
            output_table[key] = {0, count, 0}
        end
    end
end

-- Helps in creation of a new vcluster. Convers hmap input_table
-- containing fluids in the form table[name] = count to the form 
-- used in vcluster IO tables. Adds data to output table.
local function add_fluids(input_table, output_table)
    if not input_table then return end
    for name, count in pairs(input_table) do
        output_table[name] = {0, count, 0}
    end
end

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
        input = {},
        output = {},
        member_count = 0,
        members = {},
        sum_x = 0,
        sum_y = 0,
        total_weight = 0,
    }
    -- now we add all important data from template to vcluster
    local cluster = storage.vclusters[template_name][surface_index]
    cluster.research_producer = (template.type == 2)
    -- collecting inputs
    local t_input = template.input
    if t_input then
        add_items(t_input.items, cluster.input)
        add_fluids(t_input.fluids, cluster.input)
        -- adding input for energy
        local area = template.area
        local energy_drain = misc.template_area_to_power(area)
        cluster.input.electric_energy = {0, (t_input.energy or 0) + energy_drain, 0}
    end
    -- collecting outputs
    local t_output = template.output
    if t_output then
        add_items(t_output.items, cluster.output)
        add_fluids(t_output.fluids, cluster.output)
        if t_output.energy then
            cluster.output.electric_energy = {0, t_output.energy, 0}
        end
    end
    return cluster
end


-- Recalculates buffer sizes for a given cluster
local function update_buffer_size(cluster)
    local member_count = cluster.member_count
    local input = cluster.input
    for _, buffer in pairs(input) do
        buffer[3] = 2 * member_count * buffer[2]
    end
    local output = cluster.output
    for _, buffer in pairs(output) do
        buffer[3] = 2 * member_count * buffer[2]
    end
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
    local position = entity.position
    cluster.sum_x = cluster.sum_x + position.x
    cluster.sum_y = cluster.sum_y + position.y
    cluster.total_weight = cluster.total_weight + 1
    cluster.member_count = cluster.member_count + 1
    local members = cluster.members
    members[entity.unit_number] = {
        x = position.x,
        y = position.y,
        weight = 1
    }
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

    -- updating cluster table
    local unit_number = properties.unit_number
    local members = cluster.members
    local member_data = members[unit_number]
    cluster.sum_x = cluster.sum_x - member_data.x
    cluster.sum_y = cluster.sum_y - member_data.y
    cluster.total_weight = cluster.total_weight - member_data.weight
    cluster.member_count = cluster.member_count - 1
    members[unit_number] = nil

    -- cleanup: deleting cluster if it has no members
    if cluster.member_count == 0 then
        local template_name = properties.active_template
        local surface_index = cluster.surface_index
        storage.vclusters[template_name][surface_index] = nil
        if not next(storage.vclusters[template_name]) then
            storage.vclusters[template_name] = nil
        end
        return
    end
    update_buffer_size(cluster)
end

return Helper