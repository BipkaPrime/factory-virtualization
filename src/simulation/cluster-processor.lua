--[[
Virtualization mainframes and mainframe-IOs placed on the same surface and 
having the same template selected form a "Virtualization Cluster".
It's basically a simulated factory consisting of multiple members. Mainframes connected to a
cluster provide crafing power, mainframe IOs connected to a cluster move items/fluid/energy
between factorio world and simulated factory. Technically virtualization cluster is a table in storage.
All virtualization clusters are located at storage.vclusters which consist of 2 parts:
storage.vclusters = {
    array = {},
    lookup = {},
}
Array is 1-indexed and contain all vclusters (which are tables).
Lookup maps cluster identifier (string) with index of that cluster in array.
Cluster is identified by a unique string "template_name//surface_name".

Clusters are created when first member is added to them. Clusters are deleted when last remaining
member is removed from them. These operations are performed automatically.
Cluster processor fully relies on entity processor for managing members of clusters. Only
entity processor makes calls to add/remove entity.

To stop players from abusing cluster global mechanic, we introduce and energy tax based on how far
cluster members are from it's center. Tax for one building is calculated like this:
BASE_COST*(dist(center, building_pos))^2, where center is a weighted average for coordinates of all members.
Total tax should be equal to the sum of above expression for all members.
It turns out that this sum can be calculated in O(1) time if we have access to the following values:
center coordinates, total weight, weighted sum of (x^2 + y^2) for all members.

--------------------------------------------------------------------------------------------
VIRTUALIZATION CLUSTER KEYS
--------------------------------------------------------------------------------------------
cluster_id string: "template_name//surface_name"
research_producer bool: true if this cluster produces research

input table: buffers for input ingredients (items, fluids and energy)
output table: buffers for output products (items, fluids and energy)
Input and output tables are hmaps. For items key is "name//quality", for fluids key is "name", for energy
key is "electric_energy". Value is corresponding buffer.
Each buffer is a table containing following fields:
buffer = {
    current = integer,
    per_craft = integer,
    maximum = integer,
    type = string, "item"/"fluid"/"energy"
    name = string, items only
    quality = string, items only
}
Current defines currently available amount, per_craft defines amount needed to perform 1 craft,
maximum defines the maximum amount that can fit in the buffer. Maximum buffer size is recalculated
every time when number of operational VMs in the cluster changes.

member_counts table: key is entity name (string), value is entity count (int)
members table: key is unit_number, value is a table with member data of that entity
member_data = {
    x = float, x-coordinate of this entity
    y = float, y-coordinate of this entity
    weight = float, weight of this entity
    name = string, name of this entity,
    operational = bool, true if this entity is an operational vm
}
members table is used for deletion of an invalid entity from the cluster

operational_vms integer: number of operational virtualization mainframes in the cluster
sum_x float: weighted sum of x coordinates of all members
sum_y float: weighted sum of y coordinates of all members
total_weight float: sum of weights of all members
sum_squares float: weighted sum of squares of all member positions (x^2 + y^2) * weight
total_energy_tax float: additional energy required per craft of this cluster
base_energy_per_craft float: base electric energy consumption per craft
last_cycle_crafts integer/nil: number of crafts performed in the last crafting cycle
--]]

local TemplateCompiler = require("src.simulation.template-compiler")

local ClusterProcessor = {}

local PREFIX = "FV-"

-- key: entity.name (string); value: entity weight (float).
-- contains all building names which can be a part of a cluster.
local entity_weights = {
    [PREFIX .. "mainframe-item-io"] = 1,
    [PREFIX .. "mainframe-fluid-io"] = 1,
    [PREFIX .. "mainframe-energy-io"] = 1,
    [PREFIX .. "virtualization-mainframe"] = 4,
}

-- multiplayer of energy tax on distance from cluster center
local energy_tax_rate = 1e-3

-------------------------------------------------------------------------------
-- VCLUSTER CREATION
-------------------------------------------------------------------------------

---Retrieves vcluster data from storage.
---@param cluster_id string unique string identifier if a cluster "template_name//surface_name"
---@return table|nil cluster
local function get_cluster(cluster_id)
    local reg = storage.vclusters
    local index = reg.lookup[cluster_id]
    if not index then return end
    return reg.array[index]
end

---Adds new vcluster to storage
---@param cluster table cluster data
---@param cluster_id string unique cluster identifier
local function add_cluster(cluster, cluster_id)
    local array = storage.vclusters.array
    local lookup = storage.vclusters.lookup
    table.insert(array, cluster)
    lookup[cluster_id] = #array
end

---Deletes cluster from storage
---@param cluster_id string unique cluster identifier "template_name//surface_name"
local function delete_cluster(cluster_id)
    local array = storage.vclusters.array
    local lookup = storage.vclusters.lookup
    local index = lookup[cluster_id]

    -- rewriting element we want to delete with the last one
    local last_cluster = array[#array]
    array[index] = last_cluster
    lookup[last_cluster.cluster_id] = index

    -- removing last element from both tables 
    table.remove(array)
    lookup[cluster_id] = nil
end

---Creates vcluster buffer from template io_flow
---@param io_flow table<string, number> io flow counts
---@return table<string, table> buffer
local function create_buffer(io_flow)
    buffer = {}
    for key, flow in pairs(io_flow) do
        buffer[key] = {
            current = 0,
            per_craft = flow,
            maximum = 0,
        }
        if key:find("//", 1, true) then
            -- item key "name//quality"
            buffer[key].name, buffer[key].quality = key:match("^(.+)//(.+)$")
            buffer[key].type = "item"
        elseif key == "electric_energy" then
            -- energy key 
            buffer[key].type = "energy"
        else
            -- fluid key "name"
            buffer[key].name = key
            buffer[key].type = "fluid"
        end
    end
    return buffer
end

---Adds all important data from template to vcluster
---@param cluster table new cluster data
---@param template table compiled template
local function add_template_data(cluster, template)
    cluster.research_producer = template.research_template
    cluster.input = create_buffer(template.input)
    cluster.output = create_buffer(template.output)
end


---Gets an existing virtualization cluster from storage or creates one.
---@param template table necessery data for creation like inputs/outputs per second
---@param template_name string unique template identifier 
---@param entity LuaEntity entity for which cluster is created. Assumed to be valid
local function get_or_create_cluster(template, template_name, entity)
    local surface_name = entity.surface.name

    -- retrieving vcluster from storage if it exists
    local cluster_id = template_name .. "//" .. surface_name
    local cluster = get_cluster(cluster_id)
    if cluster then return cluster end

    -- if cluster does not exist we create a new one
    local new_cluster = {
        cluster_id = cluster_id,
        member_counts = {},
        members = {},
        operational_vms = 0,
        sum_x = 0,
        sum_y = 0,
        total_weight = 0,
        sum_squares = 0,
        total_energy_tax = 0,
        base_energy_per_craft = 0,
    }
    add_template_data(new_cluster, template)
    add_cluster(new_cluster, cluster_id)
    return new_cluster
end

-------------------------------------------------------------------------------
-- VCLUSTER BUFFER IO
-------------------------------------------------------------------------------

---Gets input buffer space for provided key
---If buffer is not found returns 0
---@param cluster table cluster data
---@param key string buffer identifier
---@return number
function ClusterProcessor.get_input_space(cluster, key)
    local buffer = cluster.input[key]
    if not buffer then return 0 end
    return buffer.maximum - buffer.current
end

---Gets output buffer capacity for provided key
---If buffer is not found returns 0
---@param cluster table cluster data
---@param key string buffer identifier
---@return number
function ClusterProcessor.get_output_capacity(cluster, key)
    local buffer = cluster.output[key]
    if not buffer then return 0 end
    return buffer.current
end

---Adds provided amount to input buffer. Key must exist in the buffer
---@param cluster table cluster data
---@param key string buffer identifier
---@param amount number number of items to add
function ClusterProcessor.process_buffer_input(cluster, key, amount)
    local buffer = cluster.input[key]
    buffer.current = buffer.current + amount
end

---Removes provided amount from output buffer. Key must exist in the buffer
---@param cluster table cluster data
---@param key string buffer identifier
---@param amount number number of items to remove
function ClusterProcessor.process_buffer_output(cluster, key, amount)
    local buffer = cluster.output[key]
    buffer.current = buffer.current - amount
end

-------------------------------------------------------------------------------
-- VCLUSTER UPDATE OPERAIONS: ADD/REMOVE MEMBER, ETC.
-------------------------------------------------------------------------------

---Updates maximum buffer size of given table of buffers
---@param buffers table buffers to be updated
---@param mult number buffer multiplier
local function update_buffers_table(buffers, mult)
    for _, buffer in pairs(buffers) do
        buffer.maximum = buffer.per_craft * mult
    end
end

---Recalculates buffer sizes for a given cluster.
---Buffer sizes depend on number of operational vmainframes.
---@param cluster table cluster data
local function update_buffers(cluster)
    local multiplier = (cluster.operational_vms or 0) * 2
    update_buffers_table(cluster.input, multiplier)
    update_buffers_table(cluster.output, multiplier)
end


---Updates total energy tax for a given cluster. Also updates input energy
---buffer per_craft field. Should be called before resizing buffers.
---@param cluster table cluster data
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
    cluster.total_energy_tax = energy_tax_rate * (cluster.sum_squares - correction)

    -- correcting cluster energy consumption
    local base_cost = cluster.base_energy_per_craft
    local energy_tax = cluster.total_energy_tax
    cluster.input.electric_energy.per_craft = base_cost + energy_tax
end

---Adds an entity to a virtualization cluster. Сluster_id is decided automatically
---based on template name and surface entity is located on. This function is only called
---by entity processor when selected_template changes.
---@param entity LuaEntity assumed to be valid
---@param template_name string|nil unique template identifier
---@return table|nil: cluster that was assigned to this entity if any
function ClusterProcessor.add_to_cluster(entity, template_name)
    -- getting template and checking that it exists
    if not template_name then return end
    local template = TemplateCompiler.get_template(template_name)
    if not template then return end

    -- getting appropriate cluster for entity
    local cluster = get_or_create_cluster(template, template_name, entity)
    if not cluster then return end

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
        name = name,
    }
    update_total_energy_tax(cluster)
    update_buffers(cluster)
    return cluster
end

---Removes an entity from cluster given its unit_number.
---Entity can be invalid when this function is called.
---@param cluster table|nil cluster data
---@param unit_number integer unique entity identifier
function ClusterProcessor.remove_from_cluster(cluster, unit_number)
    if not cluster then return end
    local member_data = cluster.members[unit_number]
    cluster.members[unit_number] = nil

    -- correcting member counts
    local m_counts = cluster.member_counts
    local name = member_data.name
    m_counts[name] = m_counts[name] - 1
    if m_counts[name] == 0 then m_counts[name] = nil end

    -- cleanup: deleting cluster if it has no members left
    if not next(cluster.member_counts) then
        delete_cluster(cluster.cluster_id)
        return
    end

    -- correcting coordinate sums and total weight
    local x, y, weight = member_data.x, member_data.y, member_data.weight
    cluster.sum_x = cluster.sum_x - x * weight
    cluster.sum_y = cluster.sum_y - y * weight
    cluster.sum_squares = cluster.sum_squares - weight * (x * x + y * y)
    cluster.total_weight = cluster.total_weight - weight

    -- correcting operational VMs count
    local operational = member_data.operational
    if operational then cluster.operational_vms = cluster.operational_vms - 1 end

    -- correcting buffers and total energy tax
    update_total_energy_tax(cluster)
    update_buffers(cluster)
end

---Marks given entity as an operational VM inside a cluster.
---Also adjusts creating potential and buffer sizes.
---@param cluster table|nil cluster data
---@param unit_number integer unique entity identifier
function ClusterProcessor.set_mainframe_operational(cluster, unit_number)
    if not cluster then return end
    local member_data = cluster.members[unit_number]
    if member_data.operational then return end
    member_data.operational = true

    -- updating crafting potential and buffer sizes
    cluster.operational_vms = cluster.operational_vms + 1
    update_buffers(cluster)
end

-------------------------------------------------------------------------------
-- VCLUSTER CRAFTING PROCESSOR 
-------------------------------------------------------------------------------

---Helps with processing crafts inside clusters. Calculates
---amount of crafts that can be made with input ingredients.
---@param cluster table cluster data
local function get_input_crafts(cluster)
    local max_crafts = 1e9
    for _, buffer in pairs(cluster.input) do
        local curr_crafts = math.floor(buffer.current / buffer.per_craft)
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    return max_crafts
end

---Helps with processing crafts inside clusters. Calculates
---amount of crafts that can fit in the output.
---@param cluster table cluster data
local function get_output_crafts(cluster)
    local max_crafts = 1e9
    for _, buffer in pairs(cluster.output) do
        local curr_crafts = math.floor((buffer.maximum - buffer.current) / buffer.per_craft)
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    return max_crafts
end

---Performs a craft for a vcluster.
---@param cluster table cluster data
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

        -- adding products to output
        for _, buffer in pairs(cluster.output) do
            buffer.current = buffer.current + buffer.per_craft * max_crafts
            -- TODO: add to statistics
        end

        cluster.last_cycle_crafts = max_crafts
    end
end

---On-tick cluster processor
---@param event EventData.on_tick
function ClusterProcessor.process_clusters(event)
    local array = storage.vclusters.array
    local offset = (event.tick % 60) + 1
    for i = offset, #array, 60 do
        local cluster = array[i]
        perform_craft(cluster)
    end
end

return ClusterProcessor