--[[
Virtualization clusters (also reffered to as clusters) are simulated "factories".
Their purpose is to produce (craft) things from other things. Currently clusters
can consume and produce items, fluids and electric energy. The rate of production and
consumption is defined by production template that cluster is based upon.

Clusters are formed from entities (buildings) added by this mod. For example,
cluster item IOs transfer items between physical factorio world and cluster internal
buffer (which is virtual and exists as a table in storage). Virtualization mainframes
provide crafting power to the cluster. If cluster has X crafting power, that means
it can perform X crafts per second. Cluster storage units provide size to cluster
internal buffers. There are other buildings that can be cluster members too.

Clusters are formed from entities (that can be cluster members) placed on the same
surface and having the same template selected. Clusters are created when first member
(entity) is added to them. Clusters are deleted when last remaining member is removed
from them. These operations are performed automatically. Cluster processor fully relies
on entity processor for managing members of clusters. Only entity processor makes calls
to add/remove/modify members.

Cluster energy consumption also depends on how far apart cluster members are from
its center. The idea behind this is to encourage players to build compact clusters.
It's called the "decentralization loss". It's applied multiplicatively to cluster energy
required per craft.

Decentralization loss is handled as follows. When building is added to the cluster it has
a weight associated with it. Center of a cluster is a weighted average of coordinates of
all its members. Loss for one cluster member is calculated using the formula:
BASE_COST*(dist(center, member_pos))^2. Total loss is the weighted average of losses
for each cluster member.Total value of decentralization loss can be calculated in O(1)
time if following values are known: total cluster weight, coordinates of cluster center,
weighted sum of (x^2 + y^2) for all members.
For this reason each cluster will contain following fields:
sum_x number: weighted sum of x-coordinates of all members
sum_y number: weighted sum of y-coordinates of all members
total_weight number: sum of weights of all members
sum_squares number: weighted sum of squares (x^2 + y^2) of all member positions

All clusters are located at storage.clusters, which consists of 2 parts:
storage.clusters = {
    array: ClusterData[],
    lookup: table<string, ClusterData>,
}
Array stores all existing clusters and used for on-tick processing.
Lookup maps cluster identifier (string) with corresponding ClusterData.
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
---@field cs_flow number amount that entered(input buffer)/exited(output buffer) from the time of last craft
---@field type "item"|"fluid"|"energy"
---@field name string|nil only present for items and fluids
---@field quality string|nil only present for items

---Table describing one cluster member
---@class ClusterMemberData
---@field x_pos number x-coordinate of this entity
---@field y_pos number y-coordinate of this entity
---@field weight number weight of this entity
---@field key BufferKeyString name//quality of this entity
---@field crafting_power number|nil amount of crafting potential entity is contributing
---@field storage_capacity number|nil amount of storage this entity is contributing
---@field buffer ClusterBufferEntry|nil buffer to which entity is contributing storage capacity

---Table describing one virtualization cluster
---@class ClusterData
---@field index number position of this cluster in the data structure
---@field cluster_id ClusterIdString template_name//surface_index
---@field template_name string name of template for this cluster
---@field surface_index number unique surface identifier
---@field input table<BufferKeyString, ClusterBufferEntry> cluster input buffer
---@field output table<BufferKeyString, ClusterBufferEntry> cluster output buffer
---@field member_counts table<BufferKeyString, number> count of all cluster members
---@field members table<number, ClusterMemberData> key is entity.unit_number. contains data of all members
---@field crafting_power number maximum number of crafts cluster can produce per second
---@field sum_x number weighted sum of x-coordinates of all members
---@field sum_y number weighted sum of y coordinates of all members
---@field total_weight number sum of weights of all members
---@field sum_squares number weighted sum of squares (x^2 + y^2) of all member positions
---@field decentralization_loss number multiplier of energy per craft of this cluster
---@field base_energy_per_craft number base electric energy consumption per craft
---@field last_cycle_crafts number crafts performed in the last crafting cycle
---@field item_statistics LuaFlowStatistics|nil for player force and cluster surface (will be cached when crafting)
---@field fluid_statistics LuaFlowStatistics|nil for player force and cluster surface (will be cached when crafting)

local TemplateStorage = require("src.simulation.template-storage")


local ClusterProcessor = {}

-------------------------------------------------------------------------------
-- CLUSTER CREATION/DELETION
-------------------------------------------------------------------------------

---Adds new cluster to storage
---@param cluster ClusterData cluster data
---@param cluster_id ClusterIdString unique cluster identifier
local function add_cluster(cluster, cluster_id)
    local clusters = storage.clusters
    local array = clusters.array
    local lookup = clusters.lookup
    local index = #array + 1
    array[index] = cluster
    cluster.index = index
    lookup[cluster_id] = cluster
end

---Deletes the cluster from storage given its cluster id.
---@param cluster_id ClusterIdString unique cluster identifier
local function delete_cluster(cluster_id)
    local clusters = storage.clusters
    local array = clusters.array
    local lookup = clusters.lookup

    -- rewriting element we want to delete with the last one
    local cluster = lookup[cluster_id]
    local index = cluster.index
    local last_cluster = array[#array]
    array[index] = last_cluster
    last_cluster.index = index

    -- cleaning up both tables
    array[#array] = nil
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

---Adds all required data from template to cluster
---@param cluster ClusterData new cluster data
---@param template TemplateData compiled template
local function add_template_data(cluster, template)
    cluster.input = create_buffer(template.input)
    cluster.output = create_buffer(template.output)

    -- electric_energy is a mandatory entry in the input buffer
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
    local surface_index = entity.surface_index
    local cluster_id = template_name .. "//" .. surface_index
    local cluster = storage.clusters.lookup[cluster_id]
    if cluster then return cluster end

    -- if cluster does not exist we need to create a new one
    ---@type ClusterData
    local new_cluster = {
        index = 0,
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
        decentralization_loss = 0,
        base_energy_per_craft = 0,
        last_cycle_crafts = 0,
    }
    add_template_data(new_cluster, template)
    add_cluster(new_cluster, cluster_id)
    return new_cluster
end

-------------------------------------------------------------------------------
-- CLUSTER GETTERS FOR GUI
-------------------------------------------------------------------------------

---Gets all clusters that exist on a given surface
---@param surface_index number unique surface identifier
---@return string[] template_names
function ClusterProcessor.get_surface_clusters(surface_index)
    local array = storage.clusters.array
    local result = {}
    for _, cluster in ipairs(array) do
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
    local array = storage.clusters.array
    local surfaces = game.surfaces
    local result = {}
    for _, cluster in ipairs(array) do
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
    local array = storage.clusters.array
    local surfaces = game.surfaces

    ---Creating hmap first to avoid duplicates
    ---@type table<string, true>
    local result = {}
    for _, cluster in ipairs(array) do
        local surface = surfaces[cluster.surface_index]
        if surface then
            result[surface.name] = true
        end
    end

    -- converting hmap to flat array
    local output = {}
    for name, _ in pairs(result) do
        table.insert(output, name)
    end
    return output
end

---@param template_name string unique template identifier
---@param surface_name string name of cluster surface
---@return ClusterData|nil
function ClusterProcessor.get_cluster_by_names(template_name, surface_name)
    local surface = game.get_surface(surface_name)
    if not surface then return end
    local cluster_id = template_name .. "//" .. tostring(surface.index)
    return storage.clusters.lookup[cluster_id]
end

-------------------------------------------------------------------------------
-- PUBLIC API FOR INTERACTION WITH CLUSTER BUFFER ENTRIES
-------------------------------------------------------------------------------

---Retrieves a buffer entry from a given cluster by key
---@param cluster ClusterData cluster from which buffer entry is returned
---@param buffer_key BufferKeyString buffer entry identifier
---@param io_mode "input"|"output" determines which buffer is accessed
---@return ClusterBufferEntry|nil
function ClusterProcessor.get_buffer_entry(cluster, buffer_key, io_mode)
    return cluster[io_mode][buffer_key]
end

---Gets available space in provided buffer entry
---@param buffer_entry ClusterBufferEntry
---@return number avilable_space
function ClusterProcessor.get_available_space(buffer_entry)
    return buffer_entry.maximum - buffer_entry.current
end

---Gets current amount stored in provided buffer entry
---@param buffer_entry ClusterBufferEntry
---@return number current_amount
function ClusterProcessor.get_current_amount(buffer_entry)
    return buffer_entry.current
end

---Adds provided amount to current amount in the buffer entry
---@param buffer_entry ClusterBufferEntry
---@param amount number number to add
function ClusterProcessor.add_to_buffer_entry(buffer_entry, amount)
    buffer_entry.current = buffer_entry.current + amount
    buffer_entry.cs_flow = buffer_entry.cs_flow + amount
end

---Removes provided amount from buffer entry
---@param buffer_entry ClusterBufferEntry
---@param amount number number to remove
function ClusterProcessor.remove_from_buffer_entry(buffer_entry, amount)
    buffer_entry.current = buffer_entry.current - amount
    buffer_entry.cs_flow = buffer_entry.cs_flow + amount
end

---Removes overflow from provided cluster buffer entry
---@param buffer_entry ClusterBufferEntry
---@param max_amount number maximum amount that can be voided
---@param threshold number from 0 to 1. Defines what is considered an overflow
---@return number voided_amount number of voided items
function ClusterProcessor.void_overflow(buffer_entry, max_amount, threshold)
    local current_amount = buffer_entry.current
    ---Calculating target delta: how much should be voided from current amount in
    ---order to make buffer fullness be equal to threshold.
    local target_delta = current_amount - buffer_entry.maximum * threshold
    -- Accounting to max_amount and rounding delta ensuring that
    -- only whole amount can be voided
    local delta = math.floor(math.min(target_delta, max_amount))
    -- can not void if delta is not positive
    if delta < 1 then return 0 end
    buffer_entry.current = buffer_entry.current - delta
    return delta
end

-------------------------------------------------------------------------------
-- CLUSTER UPDATE OPERATIONS: ADD/REMOVE MEMBER, ADD STORAGE CAPACITY, ETC.
-------------------------------------------------------------------------------

local decentralization_loss_base = 0.0001

---Updates decentralization loss for a given cluster.
---Also updates input energy buffer per_craft field.
---@param cluster ClusterData
local function update_decentralization_loss(cluster)
    local weight = cluster.total_weight -- total weight of the cluster (assumed to be positive)
    local sum_x = cluster.sum_x -- weighted sum of x-coordinates for all members
    local sum_y = cluster.sum_y -- weighted sum of y-coordinates for all members
    local sum_squares = cluster.sum_squares -- weighted sum of (x^2 + y^2) of all members

    -- sum of weight*(dist(member_pos, cluster_center))^2 for all members
    local total_distance_squared = sum_squares - (sum_x^2 + sum_y^2) / weight
    total_distance_squared = math.max(0, total_distance_squared)
    -- calculated value for decentralization loss
    local loss = decentralization_loss_base * total_distance_squared / weight
    cluster.decentralization_loss = loss

    -- correcting cluster energy consumption
    local base_cost = cluster.base_energy_per_craft
    cluster.input.electric_energy.per_craft = base_cost * (1 + loss)
end

---Adds an entity to a cluster. Cluster_id is decided automatically
---based on template name and surface entity is located on.
---@param entity LuaEntity assumed to be valid
---@param template_name string unique template identifier
---@param weight number weight of this entity in the cluster, must be positive 
---@return ClusterData|nil cluster cluster that this entity was assigned to
function ClusterProcessor.add_to_cluster(entity, template_name, weight)
    -- getting template and checking that it exists
    local template = TemplateStorage.get_template(template_name)
    if not template then return end

    -- getting appropriate cluster for entity
    local cluster = get_or_create_cluster(template, template_name, entity)

    -- avoiding duplicates: if entity is already in this cluster, return cluster
    ---@type number assuming entity has a unit number
    local unit_number = entity.unit_number
    if cluster.members[unit_number] then return cluster end

    -- updating member coordinate related data
    local position = entity.position
    local x, y = position.x, position.y
    local name = entity.name
    cluster.sum_x = cluster.sum_x + x * weight
    cluster.sum_y = cluster.sum_y + y * weight
    cluster.sum_squares = cluster.sum_squares + weight * (x * x + y * y)
    cluster.total_weight = cluster.total_weight + weight

    -- updating member counts
    local key = name .. "//" .. entity.quality.name
    cluster.member_counts[key] = (cluster.member_counts[key] or 0) + 1

    -- adding member data
    ---@type ClusterMemberData
    cluster.members[unit_number] = {
        x_pos = x,
        y_pos = y,
        weight = weight,
        key = key,
    }
    update_decentralization_loss(cluster)
    return cluster
end

---Adds storage capacity associated with given unit number. For this function to work
---entity with given unit number must be present in the cluster.
---@param cluster ClusterData cluster for which capacity is added
---@param unit_number number unit number of entity for which capacity is assigned
---@param buffer_entry ClusterBufferEntry entry of the buffer that gets capacity increase
---@param amount number amount of capacity increase
---@return boolean status true if capacity was successfully added
function ClusterProcessor.add_storage_capacity(cluster, unit_number, buffer_entry, amount)
    local member_data = cluster.members[unit_number]
    if not member_data then return false end
    -- if entity already has associated capacity, return
    if member_data.buffer then return false end

    -- adding capacity to buffer and saving it in member data
    buffer_entry.maximum = buffer_entry.maximum + amount
    member_data.storage_capacity = amount
    member_data.buffer = buffer_entry
    return true
end

---Removes storage capacity associated with given unit number from the cluster
---@param cluster ClusterData cluster for which capacity is removed
---@param unit_number number unique entity identifier
function ClusterProcessor.remove_storage_capacity(cluster, unit_number)
    local member_data = cluster.members[unit_number]
    if not member_data then return end

    -- checking for a buffer associated with this entity
    local buffer = member_data.buffer
    if not buffer then return end

    -- removing capacity from the buffer and from member data
    buffer.maximum = buffer.maximum - member_data.storage_capacity
    member_data.storage_capacity = nil
    member_data.buffer = nil
end

---Adds crafting power associated with given unit number. For this function to work
---entity with given unit number must be present in the cluster.
---@param cluster ClusterData cluster for which crafting power is added
---@param unit_number number unique entity identifier
---@param amount number how much crafting power is added
function ClusterProcessor.add_crafting_power(cluster, unit_number, amount)
    local member_data = cluster.members[unit_number]
    if not member_data then return end
    -- member is already providing crafting power
    if member_data.crafting_power then return end
    member_data.crafting_power = amount
    cluster.crafting_power = cluster.crafting_power + amount
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

    -- correcting cluster buffer capacity
    ClusterProcessor.remove_storage_capacity(cluster, unit_number)

    -- correcting cluster crafting power
    local crafting_power = (member_data.crafting_power or 0)
    cluster.crafting_power = cluster.crafting_power - crafting_power

    cluster.members[unit_number] = nil
    -- correcting decentralization loss
    update_decentralization_loss(cluster)
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

---Saves item and fluid production statistics to cluster
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
    local array = storage.clusters.array
    local offset = (event.tick % 60) + 1
    for i = offset, #array, 60 do
        local cluster = array[i]
        perform_craft(cluster)
    end
end

return ClusterProcessor