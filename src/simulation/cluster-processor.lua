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
Cluster is identified by a unique string "template_name//surface_index".

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
--]]

---@alias ClusterIdString string template_name//surface_index

---Table describing one stored type in cluster buffer.
---@class ClusterBufferEntry
---@field current number currently stored amount
---@field per_craft number amount required per 1 craft
---@field maximum number largest amount that can be stored
---@field ls_possible_crafts number number of crafts this buffer could allow at the time of last craft
---@field ls_input_flow number amount that entered the buffer in the last second
---@field ls_output_flow number amount that left the buffer in the last second
---@field cs_flow number amount that entered (input buffer)/exited (output buffer) from the time of last craft
---@field type "item"|"fluid"|"energy"
---@field name string|nil only present for items and fluids
---@field quality string|nil only present for items

---Table describing one cluster member
---@class ClusterMemberData
---@field x_pos number x-coordinate of this entity
---@field y_pos number y-coordinate of this entity
---@field weight number weight of this entity
---@field key BufferKeyString "name//quality" of this entity
---@field crafting_power number|nil amount of crafting potential entity is contributing
---@field storage_capacity number|nil amount of storage capacity this entity is providing

---Table describing one virtualization cluster
---@class ClusterData
---@field cluster_id string "template_name//surface_index"
---@field template_name string name of template for this cluster
---@field surface_index number unique surface identifier
---@field input table<BufferKeyString, ClusterBufferEntry> cluster input buffer
---@field output table<BufferKeyString, ClusterBufferEntry> cluster output buffer
---@field member_counts table<BufferKeyString, number> counts of all cluster members
---@field members table<number, ClusterMemberData> key is entity.unit_number. contains data of all members
---@field crafting_power number maximum number of crafts cluster can produce per second
---@field storage_capacity number used as per_craft multiplier to calculate maximum buffer capacity
---@field sum_x number weighted sum of x-coordinates of all members
---@field sum_y number weighted sum of y coordinates of all members
---@field total_weight number sum of weights of all members
---@field sum_squares number weighted sum of squares (x^2 + y^2) of all member positions
---@field total_energy_tax number additional energy required per craft of this cluster
---@field base_energy_per_craft number base electric energy consumption per craft
---@field last_cycle_crafts number crafts performed in the last crafting cycle
---@field item_statistics LuaFlowStatistics|nil for player force and cluster surface (will be cached when crafting)
---@field fluid_statistics LuaFlowStatistics|nil for player force and cluster surface (will be cached when crafting)

local TemplateCompiler = require("src.simulation.template-compiler")

local ClusterProcessor = {}

local PREFIX = "FV-"

---Maps entity names to their weights.
---Contains all buildings which can be a part of a cluster.
local entity_weights = {
    [PREFIX .. "cluster-item-io-mk1"] = 1,
    [PREFIX .. "cluster-item-io-mk2"] = 10,
    [PREFIX .. "cluster-item-io-mk3"] = 100,
    [PREFIX .. "cluster-fluid-io-mk1"] = 1,
    [PREFIX .. "cluster-fluid-io-mk2"] = 10,
    [PREFIX .. "cluster-fluid-io-mk3"] = 100,
    [PREFIX .. "cluster-energy-io-mk1"] = 1,
    [PREFIX .. "cluster-energy-io-mk2"] = 10,
    [PREFIX .. "cluster-energy-io-mk3"] = 100,
    [PREFIX .. "virtualization-mainframe-mk1"] = 10,
    [PREFIX .. "virtualization-mainframe-mk2"] = 100,
    [PREFIX .. "virtualization-mainframe-mk3"] = 1000,
    [PREFIX .. "inter-cluster-bridge-mk1"] = 5,
    [PREFIX .. "inter-cluster-bridge-mk2"] = 50,
    [PREFIX .. "inter-cluster-bridge-mk3"] = 500,
}

---Maps entity names to amount of crafting power they provide
local entity_crafting_power = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1,
    [PREFIX .. "virtualization-mainframe-mk2"] = 10,
    [PREFIX .. "virtualization-mainframe-mk3"] = 100,
}

---Maps entity names to amount of storage capacity they provide
local entity_storage_capacity = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1,
    [PREFIX .. "virtualization-mainframe-mk2"] = 1,
    [PREFIX .. "virtualization-mainframe-mk3"] = 1,
}

-- multiplayer of energy tax on distance from cluster center
local energy_tax_rate = 1e-3

-------------------------------------------------------------------------------
-- VCLUSTER CREATION
-------------------------------------------------------------------------------

---Retrieves vcluster data from storage.
---@param cluster_id ClusterIdString unique cluster identifier
---@return ClusterData|nil cluster
local function get_cluster(cluster_id)
    local reg = storage.vclusters
    local index = reg.lookup[cluster_id]
    if not index then return end
    return reg.array[index]
end

---Adds new vcluster to storage
---@param cluster ClusterData cluster data
---@param cluster_id ClusterIdString unique cluster identifier
local function add_cluster(cluster, cluster_id)
    local array = storage.vclusters.array
    local lookup = storage.vclusters.lookup
    table.insert(array, cluster)
    lookup[cluster_id] = #array
end

---Deletes cluster from storage
---@param cluster_id ClusterIdString unique cluster identifier
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

---Creates cluster buffer from template io_flow
---@param io_flow table<BufferKeyString, number> io flow counts
---@return table<BufferKeyString, ClusterBufferEntry> buffer
local function create_buffer(io_flow)
    local buffer = {}
    for key, flow in pairs(io_flow) do
        local entry = {
            current = 0,
            per_craft = flow,
            maximum = 0,
            ls_input_flow = 0,
            ls_output_flow = 0,
            cs_flow = 0,
            ls_possible_crafts = 0,
        }
        if key:find("//", 1, true) then
            -- item key "name//quality"
            entry.name, entry.quality = key:match("^(.+)//(.+)$")
            entry.type = "item"
        elseif key == "electric_energy" then
            -- energy key 
            entry.type = "energy"
        else
            -- fluid key "name"
            entry.name = key
            entry.type = "fluid"
        end
        buffer[key] = entry
    end
    return buffer
end

---Adds all required data from template to vcluster
---@param cluster ClusterData new cluster data
---@param template TemplateData compiled template
local function add_template_data(cluster, template)
    cluster.input = create_buffer(template.input)
    cluster.output = create_buffer(template.output)

    -- electric_energy is a mandatory field in input
    if not cluster.input.electric_energy then
        cluster.input.electric_energy = {
            current = 0,
            per_craft = 0,
            maximum = 0,
            ls_input_flow = 0,
            ls_output_flow = 0,
            cs_flow = 0,
            ls_possible_crafts = 0,
            type = "energy",
        }
    end

    -- adding template energy drain to energy input
    local energy_drain = template.energy_drain
    local energy_input = cluster.input.electric_energy
    energy_input.per_craft = energy_input.per_craft + energy_drain
    -- saving base energy cost per craft (energy input + energy drain)
    cluster.base_energy_per_craft = energy_input.per_craft
end

---Gets an existing virtualization cluster from storage or creates one.
---@param template TemplateData necessery data for creation like inputs/outputs per second
---@param template_name string unique template identifier
---@param entity LuaEntity entity for which cluster is created. Assumed to be valid
---@return ClusterData cluster existing or created cluster
local function get_or_create_cluster(template, template_name, entity)
    -- retrieving vcluster from storage if it exists
    local cluster_id = template_name .. "//" .. entity.surface_index
    local cluster = get_cluster(cluster_id)
    if cluster then return cluster end

    -- if cluster does not exist we create a new one
    ---@type ClusterData
    local new_cluster = {
        cluster_id = cluster_id,
        template_name = template_name,
        surface_index = entity.surface_index,
        input = {},
        output = {},
        member_counts = {},
        members = {},
        crafting_power = 0,
        storage_capacity = 0,
        sum_x = 0,
        sum_y = 0,
        total_weight = 0,
        sum_squares = 0,
        total_energy_tax = 0,
        base_energy_per_craft = 0,
        last_cycle_crafts = 0,
    }
    add_template_data(new_cluster, template)
    add_cluster(new_cluster, cluster_id)
    return new_cluster
end

-------------------------------------------------------------------------------
-- API for GUI
-------------------------------------------------------------------------------

---Gets all clusters that exist on a given surface
---@param surface_index number unique surface identifier
---@return string[] template_names
function ClusterProcessor.get_surface_clusters(surface_index)
    local clusters = storage.vclusters.array
    local result = {}
    for _, cluster in pairs(clusters) do
        if cluster.surface_index == surface_index then
            table.insert(result, cluster.template_name)
        end
    end
    return result
end

---Gets all clusters that exist on a given surface
---@param surface_name string
---@return string[] template_names
function ClusterProcessor.get_surface_clusters_by_name(surface_name)
    local surface = game.get_surface(surface_name)
    if not surface then return {} end
    return ClusterProcessor.get_surface_clusters(surface.index)
end

---Gets all clusters that were created using given template
---@param template_name string unique cluster identifier
---@return string[] surface_names 
function ClusterProcessor.get_template_clusters(template_name)
    local clusters = storage.vclusters.array
    local surfaces = game.surfaces
    local result = {}
    for _, cluster in pairs(clusters) do
        if cluster.template_name == template_name then
            local surface = surfaces[cluster.surface_index]
            if surface then
                table.insert(result, surface.name)
            end
        end
    end
    return result
end

---Gets names of all surfaces that have at least one cluster
---@return string[] surface_names
function ClusterProcessor.get_all_surfaces()
    local clusters = storage.vclusters.array
    local surfaces = game.surfaces
    local result = {}
    for _, cluster in pairs(clusters) do
        local surface = surfaces[cluster.surface_index]
        if surface then
            table.insert(result, surface.name)
        end
    end
    return result
end

---@param template_name string unique template identifier
---@param surface_name string name of cluster surface
---@return ClusterData|nil
function ClusterProcessor.get_cluster_by_names(template_name, surface_name)
    local surface = game.get_surface(surface_name)
    if not surface then return end
    local cluster_id = template_name .. "//" .. tostring(surface.index)
    return get_cluster(cluster_id)
end

-------------------------------------------------------------------------------
-- VCLUSTER BUFFER IO
-------------------------------------------------------------------------------

---Gets input buffer space for provided key
---If buffer is not found returns 0
---@param cluster ClusterData
---@param key BufferKeyString buffer identifier
---@return number available_space
function ClusterProcessor.get_input_space(cluster, key)
    local buffer = cluster.input[key]
    if not buffer then return 0 end
    return buffer.maximum - buffer.current
end

---Gets output buffer capacity for provided key
---If buffer is not found returns 0
---@param cluster ClusterData
---@param key BufferKeyString buffer identifier
---@return number available_amount
function ClusterProcessor.get_output_capacity(cluster, key)
    local buffer = cluster.output[key]
    if not buffer then return 0 end
    return buffer.current
end

---Adds provided amount to input buffer. Key must exist in the buffer
---@param cluster ClusterData
---@param key BufferKeyString buffer identifier
---@param amount number number of items to add
function ClusterProcessor.add_to_buffer(cluster, key, amount)
    local buffer = cluster.input[key]
    buffer.current = buffer.current + amount
    buffer.cs_flow = buffer.cs_flow + amount
end

---Removes provided amount from output buffer. Key must exist in the buffer
---@param cluster ClusterData
---@param key BufferKeyString buffer identifier
---@param amount number number of items to remove
function ClusterProcessor.remove_from_buffer(cluster, key, amount)
    local buffer = cluster.output[key]
    buffer.current = buffer.current - amount
    buffer.cs_flow = buffer.cs_flow + amount
end

-------------------------------------------------------------------------------
-- VCLUSTER UPDATE OPERAIONS: ADD/REMOVE MEMBER, UPDATE BUFFER SIZE, ETC.
-------------------------------------------------------------------------------

---Updates maximum buffer size of given table of buffers
---@param buffer ClusterBufferEntry[] buffer to be updated
---@param multiplier number buffer size multiplier
local function update_buffers_table(buffer, multiplier)
    for _, entry in pairs(buffer) do
        entry.maximum = math.ceil(entry.per_craft * multiplier) + 1
    end
end

---Recalculates size of io buffers for a given cluster.
---@param cluster ClusterData
local function update_buffers(cluster)
    local multiplier = cluster.storage_capacity
    update_buffers_table(cluster.input, multiplier)
    update_buffers_table(cluster.output, multiplier)
end

---Updates total energy tax for a given cluster. Also updates input energy
---buffer per_craft field. Should be called before resizing buffers.
---@param cluster ClusterData
local function update_total_energy_tax(cluster)
    local weight = cluster.total_weight

    -- calculating weighted average of coordinates (center of cluster)
    local center_x = cluster.sum_x / weight
    local center_y = cluster.sum_y / weight

    -- calculating total tax
    local correction = weight * (center_x * center_x + center_y * center_y)
    cluster.total_energy_tax = energy_tax_rate * (cluster.sum_squares - correction)

    -- correcting cluster energy consumption
    local base_cost = cluster.base_energy_per_craft
    local energy_tax = cluster.total_energy_tax
    cluster.input.electric_energy.per_craft = base_cost + energy_tax
end

---Adds an entity to a virtualization cluster. Cluster_id is decided automatically
---based on template name and surface entity is located on.
---@param entity LuaEntity assumed to be valid
---@param template_name string|nil unique template identifier
---@return ClusterData|nil: cluster that this entity was assigned to
function ClusterProcessor.add_to_cluster(entity, template_name)
    -- getting template and checking that it exists
    if not template_name then return end
    local template = TemplateCompiler.get_template(template_name)
    if not template then return end

    -- getting appropriate cluster for entity
    local cluster = get_or_create_cluster(template, template_name, entity)

    -- avoiding duplicates: if entity is already in this cluster, return it
    if cluster.members[entity.unit_number] then return cluster end

    -- updating member coordinate related data
    local x, y = entity.position.x, entity.position.y
    local name = entity.name
    local weight = entity_weights[name]
    cluster.sum_x = cluster.sum_x + x * weight
    cluster.sum_y = cluster.sum_y + y * weight
    cluster.sum_squares = cluster.sum_squares + weight * (x * x + y * y)
    cluster.total_weight = cluster.total_weight + weight

    -- adding entity storage capacity to cluster storage capacity
    local storage_capacity = entity_storage_capacity[name]
    cluster.storage_capacity = cluster.storage_capacity + (storage_capacity or 0)

    -- updating member counts
    local key = name .. "//" .. entity.quality.name
    cluster.member_counts[key] = (cluster.member_counts[key] or 0) + 1

    -- adding member data
    ---@type ClusterMemberData
    cluster.members[entity.unit_number] = {
        x_pos = x,
        y_pos = y,
        weight = weight,
        key = key,
        storage_capacity = storage_capacity,
    }
    update_total_energy_tax(cluster)
    update_buffers(cluster)
    return cluster
end

---Removes an entity from cluster given its unit_number.
---Entity can be invalid when this function is called.
---@param cluster ClusterData|nil
---@param unit_number number unique entity identifier
function ClusterProcessor.remove_from_cluster(cluster, unit_number)
    if not cluster then return end
    local member_data = cluster.members[unit_number]
    -- if entity is not found in the cluster, return
    if not member_data then return end
    cluster.members[unit_number] = nil

    -- correcting member counts
    local member_counts = cluster.member_counts
    local key = member_data.key
    member_counts[key] = member_counts[key] - 1
    if member_counts[key] == 0 then member_counts[key] = nil end

    -- cleanup: deleting cluster if it has no members left
    if not next(member_counts) then
        delete_cluster(cluster.cluster_id)
        return
    end

    -- correcting coordinate sums and total weight
    local x, y, weight = member_data.x_pos, member_data.y_pos, member_data.weight
    cluster.sum_x = cluster.sum_x - x * weight
    cluster.sum_y = cluster.sum_y - y * weight
    cluster.sum_squares = cluster.sum_squares - weight * (x * x + y * y)
    cluster.total_weight = cluster.total_weight - weight

    -- correcting cluster storage capacity
    local storage_capacity = (member_data.storage_capacity or 0)
    cluster.storage_capacity = cluster.storage_capacity - storage_capacity

    -- correcting cluster crafting power
    local crafting_power = (member_data.crafting_power or 0)
    cluster.crafting_power = cluster.crafting_power - crafting_power

    -- correcting buffers and total energy tax
    update_total_energy_tax(cluster)
    update_buffers(cluster)
end

---Enabled crafting power of a given entity in the cluster.
---In order for this function to work, entity should already be in provided cluster.
---@param entity LuaEntity
---@param cluster ClusterData|nil
function ClusterProcessor.enable_crafting_power(entity, cluster)
    if not cluster or not entity.valid then return end

    -- checking that entity has crafting power and is a member of this cluster
    ---@type ClusterMemberData
    local member_data = cluster.members[entity.unit_number]
    local crafting_power = entity_crafting_power[entity.name]
    if not member_data or not crafting_power then return end

    -- member is already providing crafting power
    if member_data.crafting_power then return end

    -- adding crafting power to member data and cluster data
    member_data.crafting_power = crafting_power
    cluster.crafting_power = cluster.crafting_power + crafting_power
end

-------------------------------------------------------------------------------
-- VCLUSTER CRAFTING PROCESSOR 
-------------------------------------------------------------------------------

---Helps with processing crafts inside clusters. Calculates
---amount of crafts that can be made with input ingredients.
---@param cluster ClusterData
local function get_input_crafts(cluster)
    local max_crafts = 1e9
    for _, entry in pairs(cluster.input) do
        local curr_crafts = math.floor(entry.current / entry.per_craft)
        entry.ls_possible_crafts = curr_crafts
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    return max_crafts
end

---Helps with processing crafts inside clusters. Calculates
---amount of crafts that can fit in the output.
---@param cluster ClusterData
local function get_output_crafts(cluster)
    local max_crafts = 1e9
    for _, entry in pairs(cluster.output) do
        local curr_crafts = math.floor((entry.maximum - entry.current) / entry.per_craft)
        entry.ls_possible_crafts = curr_crafts
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    return max_crafts
end

---Saves item and fluid production statistics to cluster.
---@param cluster ClusterData
---@return boolean status true if everything is ok
local function cache_production_statistics(cluster)
    local surface_index = cluster.surface_index
    if not game.surfaces[surface_index] then return false end

    ---@type LuaForce assuming player force exists
    local player_force = game.forces["player"]
    cluster.item_statistics = player_force.get_item_production_statistics(surface_index)
    cluster.fluid_statistics = player_force.get_fluid_production_statistics(surface_index)
    return true
end

---Reflects cluster crafing in production statistics
---@param cluster ClusterData
---@param entry ClusterBufferEntry
---@param count number positive to add to "produced", negative to add to "consumed"
local function add_to_statistics(cluster, entry, count)
    local entry_type = entry.type
    if entry_type == "energy" then return end
    if entry_type == "item" then
        -- adding to item statistics
        local item_id = {
            name = entry.name,
            quality = entry.quality
        }
        ---@type LuaFlowStatistics
        local statistics = cluster.item_statistics
        statistics.on_flow(item_id, count)
    else
        -- adding to fluid statistics
        ---@type string
        local fluid_id = entry.name
        ---@type LuaFlowStatistics
        local statistics = cluster.fluid_statistics
        statistics.on_flow(fluid_id, count)
    end
end

---Removes inputs from cluster input buffer
---@param cluster ClusterData
---@param craft_count number number of crafts that should be performed
local function withdraw_inputs(cluster, craft_count)
    for _, entry in pairs(cluster.input) do
        local consumed = entry.per_craft * craft_count
        entry.current = entry.current - consumed
        add_to_statistics(cluster, entry, -consumed)
        -- keeping track of io flow
        entry.ls_input_flow = entry.cs_flow
        entry.cs_flow = 0
        entry.ls_output_flow = consumed
    end
end

---Adds outputs to cluster output buffer
---@param cluster ClusterData
---@param craft_count number number of crafts that should be performed
local function generate_outputs(cluster, craft_count)
    for _, entry in pairs(cluster.output) do
        local produced = entry.per_craft * craft_count
        entry.current = entry.current + produced
        add_to_statistics(cluster, entry, produced)
        -- keeping track of io flow
        entry.ls_output_flow = entry.cs_flow
        entry.cs_flow = 0
        entry.ls_input_flow = produced
    end
end

---Performs a craft for a vcluster.
---@param cluster ClusterData
local function perform_craft(cluster)
    local item_stat = cluster.item_statistics
    if not item_stat or not item_stat.valid then
        local status = cache_production_statistics(cluster)
        if not status then return end
    end

    -- calculating how many crafts can be performed
    local crafts = math.max(
        0,
        math.min(
            cluster.crafting_power,
            get_input_crafts(cluster),
            get_output_crafts(cluster)
        )
    )

    cluster.last_cycle_crafts = crafts
    withdraw_inputs(cluster, crafts)
    generate_outputs(cluster, crafts)
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