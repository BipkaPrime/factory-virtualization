--[[
Virtualization clusters (also reffered to as clusters) are simulated "factories".
Their purpose is to produce (craft) things from other things. Currently clusters
can consume and produce items, fluids and electric energy. The rate of production and
consumption is defined by template assigned to the cluster.

Clusters are formed from entities (buildings) added by this mod. For example,
cluster item IOs transfer items between physical factorio world and cluster internal
buffer (which is virtual and exists as a table in storage). Virtualization mainframes
provide crafting power to the cluster. If cluster has X crafting power, that means
it can perform X crafts per second. Cluster storage units provide size to cluster
internal buffers. There are other buildings that can be cluster members too.

Clusters are somewhat alike radio frequencies. Creation/rename/deletion of a cluster
is requested by the player (and only by the player). Cluster is bound to a specific
surface on creation (surface is specified by the player). 

This file contains following logic:
1. Cluster management (create/rename/delete cluster)
2. Cluster member management (add/remove member; add/remove member crafting power; etc)
3. Cluster logistics requests (add to input/remove from output, etc)
4. Other general requests (check cluster exist, get all optimal clusters, etc.)
5. On-tick cluster processor.

Cluster-processor relies on entity-processor in cluster member management.
Note that any cluster member can either be operational (meaning that everything
is ok with this entity and it can operate) or not operational. This is also controlled
by entity processor. Operational criteria is different among different entities.
This inevitably leads to significant interconnection between cluster processor and
entity processor.

Cluster energy consumption (apart from template energy "per_craft") also depends on
how far apart cluster members are from its center. The idea behind this is to
encourage players to build compact clusters. It's called the "decentralization loss".
It's applied multiplicatively to cluster energy required per craft.

Decentralization loss is handled as follows. When building is added to the cluster it has
a weight associated with it. Center of a cluster is a weighted average of coordinates of
all its members. Loss for one cluster member is calculated using the formula:
BASE_COST*(dist(center, member_pos))^2. Total loss is the weighted average of losses
for each cluster member. Total value of decentralization loss can be calculated in O(1)
time if following values are known: total cluster weight, coordinates of cluster center,
weighted sum of (x^2 + y^2) for all members. For this reason each cluster
contains fields: "sum_x", "sum_y", "total_weight", "sum_squares".

All cluster data is located at storage.clusters (see ClusterStorage class).
--]]


---Describes one stored type (item/fluid/energy) in cluster buffer.
---@class ClusterBufferEntry
---@field current number currently stored amount
---@field per_craft number amount required per 1 craft
---@field maximum number largest amount that can be stored
---@field ls_possible_crafts number number of crafts this entry could allow
---at the time of last craft
---@field ls_input_flow number amount that entered the buffer in the last second
---@field ls_output_flow number amount that left the buffer in the last second
---@field cs_flow number amount that entered(input buffer)/exited(output buffer)
---from the time of last craft
---@field type "item"|"fluid"|"energy"
---@field item_id table|nil {name = name, quality = quality} only present for items
---@field fluid_name string|nil only present for fluids

---@class MemberBufferCapacity
---@field io_mode "input"|"output" where capacity is assigned
---@field buffer_key BufferKeyString where specifically capacity is assigned
---@field amount number how much capacity is assigned

---Contains data for one cluster member
---@class ClusterMemberData
---@field x_pos number x-coordinate of this entity
---@field y_pos number y-coordinate of this entity
---@field weight number weight of this entity
---@field name string name of this entity
---@field crafting_power number|nil amount of crafting power entity is contributing
---@field buffer_capacity MemberBufferCapacity|nil

---Contains status (operational?) statistics over one building name in the cluster 
---@class MemberCountsEntry
---@field total integer total number of buildings in this cluster
---@field operational integer number of operational buildings in this cluster
---@field problems table<integer, true> key is unit_number, contains all buildings
---that are included in total, but are not operational

---Describes one virtualization cluster
---@class ClusterData
---@field array_index integer position of this cluster in the data structure
---@field cluster_uuid string unique cluster identifier. Assigned at creation
---@field surface_index integer identifier of the surface cluster is bound to
---@field item_statistics LuaFlowStatistics for player force on the surface
---cluster is bound to
---@field fluid_statistics LuaFlowStatistics for player force on the surface
---cluster is bound to
---
---Fields directly related to cluster members (add/remove/status change)
---@field members table<integer, ClusterMemberData> key is entity.unit_number.
---contains data for all cluster members
---@field member_counts table<string, MemberCountsEntry> member status statistics
---@field total_members integer total number of members in this cluster
---@field operational_members integer number of operational members in this cluster
---@field sum_x number weighted sum of x-coordinates of all members
---@field sum_y number weighted sum of y coordinates of all members
---@field total_weight number sum of weights of all members
---@field sum_squares number weighted sum of squares (x^2 + y^2)
---of all member positions
---@field decentralization_loss number multiplier of energy per craft
---of this cluster
---@field crafting_power number maximum number of crafts cluster can produce per second
---@field power_contributors table<integer, true> unit numbers of all members with
---assigned crafting power
---@field buffer_capacity table<"input"|"output", table<BufferKeyString, integer>>
---contains maximum buffer capacity added to this cluster. Controlled by
---adding/removing member buffer capacity
---
---Fields related to assigned template or changed during processing 
---@field template_uuid string|nil identifier of template assigned to this cluster
---@field build_cost table<BufferKeyString, number> items for template construction
---@field input table<BufferKeyString, ClusterBufferEntry> cluster input buffer
---@field output table<BufferKeyString, ClusterBufferEntry> cluster output buffer
---@field energy_per_craft number electric energy consumption per craft, calculated
---before applying decentralization loss.
---@field ls_crafts number crafts performed in the last crafting cycle

---@class ClusterStorage
---@field array ClusterData[] used for on_tick processing
---@field lookup table<string, ClusterData> maps uuids to cluster data
---@field name_to_uuid table<string, string> maps cluster display names to uuids
---@field uuid_to_name table<string, string> maps cluster uuids to display names


local TCCManager = require("src.simulation.tcc-manager")
local VSurfaceManager = require("src.world.vsurface-manager")


local ClusterProcessor = {}


-------------------------------------------------------------------------------
----------------------------- CLUSTER MANAGEMENT ------------------------------
-------------------------------------------------------------------------------

---Generates uuid for cluster for internal use.
---@param cluster_name string cluster display name that is shown to player
---@return string uuid unique cluster identifier
local function generate_cluster_uuid(cluster_name)
    local uuid = string.format(
        "%s/%d/%.9f",
        cluster_name,
        game.tick,
        math.random()
    )
    return uuid
end

---Collects names of all surfaces where the new cluster can be created
---@return string[] names
function ClusterProcessor.get_cluster_location_options()
    local result = {}
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        if not VSurfaceManager.is_vsurface(surface_index) then
            table.insert(result, surface.name)
        end
    end
    return result
end

---@param cluster_name string|nil cluster display name (user input)
---@param surface_name string|nil user input
---@return boolean status true if cluster can be created
---@return LocalisedString|nil reason why cluster cannot be created
function ClusterProcessor.can_create_cluser(cluster_name, surface_name)
    -- checking that cluster name is provided
    if not cluster_name or not string.find(cluster_name, "%S", 1, false) then
        return false, {"cluster-processor.cluster-name-missing"}
    end
    -- checking that surface name is provided
    if not surface_name then
        return false, {"cluster-processor.surface-name-missing"}
    end
    return true
end

---Creates a new cluster. Cluster creation is a player request.
---@param cluster_name string|nil cluster display name (user input)
---@param surface_name string|nil user input
---@return boolean status true if cluster was successfully created
---@return LocalisedString|nil reason why cluster was not created 
function ClusterProcessor.create_cluster(cluster_name, surface_name)
    local status, reason = ClusterProcessor.can_create_cluser(
        cluster_name,
        surface_name
    )
    if not status then return status, reason end
    ---@cast cluster_name string
    ---@cast surface_name string

    -- checking that provided name points to an existing surface
    local surface = game.get_surface(surface_name)
    if not surface then
        return false, {"cluster-processor.creation-error-surface-not-found"}
    end
    local surface_index = surface.index

    -- searching for a name that is not occupied
    local clusters = storage.clusters
    local name_to_uuid = clusters.name_to_uuid
    local unique_name = cluster_name
    local suffix = 1
    while name_to_uuid[unique_name] do
        unique_name = string.format("%s (%d)", cluster_name, suffix)
        suffix = suffix + 1
    end

    -- generating cluster uuid and saving template to storage
    local cluster_uuid = generate_cluster_uuid(unique_name)
    local player_force = game.forces["player"]
    local array = clusters.array
    local array_index = #array + 1
    ---@type ClusterData
    local cluster_data = {
        array_index = array_index,
        cluster_uuid = cluster_uuid,
        surface_index = surface_index,
        item_statistics = player_force.get_item_production_statistics(surface),
        fluid_statistics = player_force.get_fluid_production_statistics(surface),
        members = {},
        member_counts = {},
        total_members = 0,
        operational_members = 0,
        sum_x = 0,
        sum_y = 0,
        total_weight = 0,
        sum_squares = 0,
        decentralization_loss = 0,
        crafting_power = 0,
        power_contributors = {},
        buffer_capacity = {input = {}, output = {}},
        build_cost = {},
        input = {},
        output = {},
        energy_per_craft = 0,
        ls_crafts = 0,
    }

    -- adding cluster to the data structure
    array[array_index] = cluster_data
    clusters.lookup[cluster_uuid] = cluster_data
    name_to_uuid[unique_name] = cluster_uuid
    clusters.uuid_to_name[cluster_uuid] = unique_name
    return true
end

---Removes assigned crafting power from all members
---@param cluster ClusterData
local function drop_crafting_power(cluster)
    local contributors = cluster.power_contributors
    cluster.power_contributors = {}
    cluster.crafting_power = 0
    for unit_number, _ in pairs(contributors) do
        cluster.members[unit_number].crafting_power = nil
    end
end

---Attempts to remove assigned template from given cluster.
---Template drop is a player request.
---@param cluster_name string|nil cluster display name
---@return boolean status true if template drop was successful
---@return LocalisedString|nil reason error string if drop failed
function ClusterProcessor.drop_assigned_template(cluster_name)
    -- checking that cluster name is provided
    if not cluster_name then
        return false, {"cluster-processor.drop-error-no-name"}
    end
    -- checking that cluster exists in storage
    local clusters = storage.clusters
    local name_to_uuid = clusters.name_to_uuid
    local cluster_uuid = name_to_uuid[cluster_name]
    if not cluster_uuid then
        return false, {"cluster-processor.drop-error-data-not-found"}
    end

    -- Everything is ok: dropping assigned template
    local cluster = clusters.lookup[cluster_uuid]
    cluster.template_uuid = nil
    cluster.build_cost = {}
    cluster.input = {}
    cluster.output = {}
    cluster.energy_per_craft = 0
    drop_crafting_power(cluster)
    return true
end

---Checks if cluster can be renamed
---@param old_name string|nil
---@param new_name string|nil
---@return boolean status true if cluster can be renamed
---@return LocalisedString|nil reason why cluster cannot be renamed
function ClusterProcessor.can_rename_cluster(old_name, new_name)
    -- checking that old name is provided
    if not old_name then
        return false, {"cluster-processor.old-name-missing"}
    end
    -- checking that new name is not empty
    if not new_name or not string.find(new_name, "%S", 1, false) then
        return false, {"cluster-processor.new-name-empty"}
    end
    -- checking that names are different
    if new_name == old_name then
        return false, {"cluster-processor.names-not-different"}
    end
    -- checking that new name is not occupied
    local name_to_uuid = storage.clusters.name_to_uuid
    if name_to_uuid[new_name] then
        return false, {"cluster-processor.new-name-occupied"}
    end
    -- checking that cluster with old name exists in storage
    if not name_to_uuid[old_name] then
        return false, {"cluster-processor.old-name-no-data"}
    end
    return true
end

---Renames a cluster. Cluster rename is a player request.
---@param old_name string|nil
---@param new_name string|nil
---@return boolean status true if cluster was renamed
---@return LocalisedString|nil reason why cluster cannot be renamed
function ClusterProcessor.rename_cluster(old_name, new_name)
    local status, reason = ClusterProcessor.can_rename_cluster(
        old_name,
        new_name
    )
    if not status then return status, reason end
    ---@cast old_name string
    ---@cast new_name string

    -- everything is ok: renaming the cluster
    local clusters = storage.clusters
    local name_to_uuid = clusters.name_to_uuid
    local cluster_uuid = name_to_uuid[old_name]
    name_to_uuid[new_name] = cluster_uuid
    name_to_uuid[old_name] = nil
    clusters.uuid_to_name[cluster_uuid] = new_name
    return true
end

---Attempts to deletes provided cluster from storage.
---Cluster deletion is a player request.
---@param cluster_name string|nil cluster display name
---@return boolean status true if deletion was successful
---@return LocalisedString|nil reason error string if deletion failed
function ClusterProcessor.delete_cluster(cluster_name)
    -- checking that cluster name is provided
    if not cluster_name then
        return false, {"cluster-processor.deletion-error-no-name"}
    end

    -- checking that cluster exists in storage
    local clusters = storage.clusters
    local name_to_uuid = clusters.name_to_uuid
    local cluster_uuid = name_to_uuid[cluster_name]
    if not cluster_uuid then
        return false, {"cluster-processor.deletion-error-no-data"}
    end

    -- Data is found: erasing it from all tables
    local lookup = clusters.lookup
    local cluster_data = lookup[cluster_uuid]
    -- deleting cluster from the array: replacing it with last element
    local array = clusters.array
    local array_index = cluster_data.array_index
    local last_element = array[#array]
    array[array_index] = last_element
    last_element.array_index = array_index
    array[#array] = nil
    -- deleting cluster data from all other tables
    lookup[cluster_uuid] = nil
    name_to_uuid[cluster_name] = nil
    clusters.uuid_to_name[cluster_uuid] = nil
    -- deleting template routing associated with this cluster
    TCCManager.remove_cluster_routing(cluster_uuid)

    return true
end

-------------------------------------------------------------------------------
-------------------------- CLUSTER MEMBER MANAGEMENT --------------------------
-------------------------------------------------------------------------------

local dc_loss_base = 1e-6

---Updates "input.electic_energy" buffer entry if it exists in the cluster
---@param cluster ClusterData
local function update_cluster_energy_demand(cluster)
    local entry = cluster.input.electric_energy
    if not entry then return end
    local base_energy = cluster.energy_per_craft
    local loss_mult = cluster.decentralization_loss
    entry.per_craft = base_energy * (1 + loss_mult)
end

---Updates decentralization loss for a given cluster.
---@param cluster ClusterData
local function update_decentralization_loss(cluster)
    local weight = cluster.total_weight
    if weight == 0 then
        cluster.decentralization_loss = 0
    else
        -- weighted sum of x-coordinates for all members
        local sum_x = cluster.sum_x
        -- weighted sum of y-coordinates for all members
        local sum_y = cluster.sum_y
        -- weighted sum of (x^2 + y^2) of all members
        local sum_squares = cluster.sum_squares
        -- sum of weight*(dist(member_pos, cluster_center))^2 for all members
        local total_distance_squared = sum_squares - (sum_x^2 + sum_y^2) / weight
        cluster.decentralization_loss = dc_loss_base * total_distance_squared / weight
    end
    update_cluster_energy_demand(cluster)
end

---Adds given entity to cluster. Intended use case: during on-tick processing
---of entity in the entity-processor.
---@param entity LuaEntity assumed to be valid (checked in entity-processor)
---@param cluster_uuid string unique cluster identifier
---@param weight number weight of this entity (used in cluster center calculation)
---@return boolean status true if entity was added successfully or found in cluster.
function ClusterProcessor.add_member_to_cluster(entity, cluster_uuid, weight)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return false end
    -- checking that entity surface matches with cluster surface
    if entity.surface_index ~= cluster.surface_index then return false end

    ---@type integer assuming entity has a unit number
    local unit_number = entity.unit_number
    -- checking for duplicates: entity can already be in this cluster
    if cluster.members[unit_number] then return true end

    -- Everything is ok: adding entity to cluster
    local position = entity.position
    local x, y = position.x, position.y
    local entity_name = entity.name

    -- Assembling and adding member data
    ---@type ClusterMemberData
    local member_data = {
        x_pos = x,
        y_pos = y,
        weight = weight,
        name = entity_name,
    }
    cluster.members[unit_number] = member_data

    -- Adding entity to member counts
    local member_counts = cluster.member_counts
    -- initializing the table for entity name if it does not exist
    if not member_counts[entity_name] then
        member_counts[entity_name] = {
            total = 0,
            operational = 0,
            problems = {}
        }
    end
    local count_entry = member_counts[entity_name]
    count_entry.total = count_entry.total + 1
    count_entry.problems[unit_number] = true

    -- Updating other related cluster fields
    cluster.total_members = cluster.total_members + 1
    cluster.sum_x = cluster.sum_x + x * weight
    cluster.sum_y = cluster.sum_y + y * weight
    cluster.total_weight = cluster.total_weight + weight
    cluster.sum_squares = cluster.sum_squares + weight * (x * x + y * y)

    -- Correcting decentralization loss
    update_decentralization_loss(cluster)
    return true
end

---Removes entity from cluster given its unit number. Entity can already be invalid
---when this function is called. Intended use case: deinitialization of an entity
---in the entity-processor.
---@param cluster_uuid string unique cluster identifier
---@param unit_number integer unique entity identifier
function ClusterProcessor.remove_member_from_cluster(cluster_uuid, unit_number)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end

    -- accesing data associated with given unit number
    local member_data = cluster.members[unit_number]
    -- member data not found: cluster does not contain this entity
    if not member_data then return end

    -- Removing crafting power and buffer capacity assigned to this member
    ClusterProcessor.remove_member_crafting_power(cluster_uuid, unit_number)
    ClusterProcessor.remove_member_buffer_capacity(cluster_uuid, unit_number)

    -- Removing data from members table
    cluster.members[unit_number] = nil

    -- Removing unit number from member counts
    local entity_name = member_data.name
    local member_counts = cluster.member_counts
    local count_entry = member_counts[entity_name]
    -- correcting total entry count
    count_entry.total = count_entry.total - 1
    -- correcting operational count
    local problems = count_entry.problems
    local is_operational = not problems[unit_number]
    if is_operational then
        count_entry.operational = count_entry.operational - 1
    end
    -- removing unit number from problems
    problems[unit_number] = nil
    -- cleaning up: removing entry if total is 0
    if count_entry.total == 0 then
        member_counts[entity_name] = nil
    end

    -- Correcting total cluster member counts
    cluster.total_members = cluster.total_members - 1
    if is_operational then
        cluster.operational_members = cluster.operational_members - 1
    end

    -- Correcting decentralization loss related fields
    local x, y, weight = member_data.x_pos, member_data.y_pos, member_data.weight
    if cluster.total_members == 0 then
        -- this is needed to avoid float inaccuracies
        cluster.sum_x = 0
        cluster.sum_y = 0
        cluster.total_weight = 0
        cluster.sum_squares = 0
    else
        cluster.sum_x = cluster.sum_x - x * weight
        cluster.sum_y = cluster.sum_y - y * weight
        cluster.total_weight = cluster.total_weight - weight
        cluster.sum_squares = cluster.sum_squares - weight * (x * x + y * y)
    end
    update_decentralization_loss(cluster)
end

---Marks unit number operational in the given cluster. Intended use case: during
---initialization or on-tick processing in the entity-processor.
---@param cluster_uuid string unique cluster identifier
---@param unit_number integer unique entity identifier
function ClusterProcessor.mark_member_operational(cluster_uuid, unit_number)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end

    -- accesing data associated with given unit number
    local member_data = cluster.members[unit_number]
    -- member data not found: cluster does not contain this entity
    if not member_data then return end

    -- Updating member state statistics
    local entity_name = member_data.name
    local count_entry = cluster.member_counts[entity_name]
    local problems = count_entry.problems
    -- entity is already marked operational: return
    if not problems[unit_number] then return end
    problems[unit_number] = nil
    count_entry.operational = count_entry.operational + 1
    cluster.operational_members = cluster.operational_members + 1
end

---Marks unit number not operational in the given cluster. Intended use case:
---during on-tick processing in the entity-processor.
---@param cluster_uuid string unique cluster identifier
---@param unit_number integer unique entity identifier
function ClusterProcessor.mark_member_not_operational(cluster_uuid, unit_number)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end

    -- accesing data associated with given unit number
    local member_data = cluster.members[unit_number]
    -- member data not found: cluster does not contain this entity
    if not member_data then return end

    -- Updating member state statistics
    local entity_name = member_data.name
    local count_entry = cluster.member_counts[entity_name]
    local problems = count_entry.problems
    -- entity is already marked as not operational: return
    if problems[unit_number] then return end
    problems[unit_number] = true
    count_entry.operational = count_entry.operational - 1
    cluster.operational_members = cluster.operational_members - 1
end

---Assignes crafting power to the given unit number. Intended use case:
---during on-tick processing in the entity-processor.
---@param cluster_uuid string unique cluster identifier
---@param unit_number integer unique entity identifier
---@param amount number how much crafting power should be added
function ClusterProcessor.assign_member_crafting_power(cluster_uuid, unit_number, amount)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end
    local member_data = cluster.members[unit_number]
    -- member data not found: cluster does not contain this entity
    if not member_data then return end
    -- member already has assigned crafting power: return
    if member_data.crafting_power then return end
    member_data.crafting_power = amount
    cluster.crafting_power = cluster.crafting_power + amount
    cluster.power_contributors[unit_number] = true
end

---Removes crafting power assigned to the given unit number. Intended use case:
---during on-tick processing in the entity-processor.
---@param cluster_uuid string unique cluster identifier
---@param unit_number integer unique entity identifier
function ClusterProcessor.remove_member_crafting_power(cluster_uuid, unit_number)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end
    local member_data = cluster.members[unit_number]
    -- member data not found: cluster does not contain this entity
    if not member_data then return end
    -- member does not have assigned crafting power: return
    if not member_data.crafting_power then return end
    cluster.crafting_power = cluster.crafting_power - member_data.crafting_power
    -- avoiding potential float inaccuracies
    if cluster.crafting_power < 1e-6 then cluster.crafting_power = 0 end
    member_data.crafting_power = nil
    cluster.power_contributors[unit_number] = nil
end

---Assignes buffer capacity to the given unit number. Intended use case:
---during on-tick processing in the entity-processor.
---@param cluster_uuid string unique cluster identifier
---@param unit_number integer unique entity identifier
---@param buffer_key BufferKeyString buffer entry identifier
---@param io_mode "input"|"output"
---@param amount number amount of buffer capacity to add
function ClusterProcessor.assign_member_buffer_capacity(
    cluster_uuid,
    unit_number,
    buffer_key,
    io_mode,
    amount
)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end
    local member_data = cluster.members[unit_number]
    -- member data not found: cluster does not contain this entity
    if not member_data then return end
    -- member already has assigned buffer capacity: return
    if member_data.buffer_capacity then return end

    -- Assigning buffer capacity to member
    member_data.buffer_capacity = {
        io_mode = io_mode,
        buffer_key = buffer_key,
        amount = amount
    }
    -- Assigning buffer capacity to cluster (updating buffer_capacity field)
    local io_section = cluster.buffer_capacity[io_mode]
    if io_section[buffer_key] then
        io_section[buffer_key] = io_section[buffer_key] + amount
    else
        io_section[buffer_key] = amount
    end
    -- Updating capacity of real cluster buffer if entry exists
    local buffer_entry = cluster[io_mode][buffer_key]
    if buffer_entry then buffer_entry.maximum = io_section[buffer_key] end
end

---Removes buffer capacity assigned to the given unit number. Intended use case:
---during on-tick processing in the entity-processor.
---@param cluster_uuid string unique cluster identifier
---@param unit_number integer unique entity identifier
function ClusterProcessor.remove_member_buffer_capacity(cluster_uuid, unit_number)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end
    local member_data = cluster.members[unit_number]
    -- member data not found: cluster does not contain this entity
    if not member_data then return end
    local assigned_capacity = member_data.buffer_capacity
    -- member does not have assigned buffer capacity: return
    if not assigned_capacity then return end
    member_data.buffer_capacity = nil

    -- removing buffer capacity from cluster (updating buffer_capacity field)
    local io_mode = assigned_capacity.io_mode
    local buffer_key = assigned_capacity.buffer_key
    local io_section = cluster.buffer_capacity[io_mode]
    io_section[buffer_key] = io_section[buffer_key] - assigned_capacity.amount
    if io_section[buffer_key] < 1e-6 then io_section[buffer_key] = nil end

    -- removing capacity from real buffer entry if it exists
    local buffer_entry = cluster[io_mode][buffer_key]
    if buffer_entry then buffer_entry.maximum = io_section[buffer_key] or 0 end
end

-------------------------------------------------------------------------------
------------------------- CLUSTER LOGISTICS REQUESTS --------------------------
-------------------------------------------------------------------------------

---Gets a buffer entry from the cluster if it exists.
---@param cluster_uuid string unique cluster identifier
---@param buffer_key BufferKeyString buffer entry identifier
---@param io_mode "input"|"output" which buffer should be checked
---@return ClusterBufferEntry|nil
function ClusterProcessor.get_buffer_entry(cluster_uuid, buffer_key, io_mode)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end
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
    -- Accounting for max_amount and rounding delta ensuring that
    -- only whole amount can be voided
    local delta = math.floor(math.min(target_delta, max_amount))
    -- can not void if delta is not positive
    if delta < 1 then return 0 end
    buffer_entry.current = buffer_entry.current - delta
    return delta
end

-------------------------------------------------------------------------------
------------------------ CLUSTER INFORMATION REQUESTS -------------------------
-------------------------------------------------------------------------------

---Decides if given cluster is ok or requires attention
---@param cluster ClusterData
---@return boolean status true if cluster is ok
local function is_cluster_optimal(cluster)
    local total_members = cluster.total_members
    -- checking that cluster has members and all are operational
    if total_members == 0 or total_members > cluster.operational_members then
        return false
    end
    local crafting_power = cluster.crafting_power
    -- checking that cluster has crafting power and using it
    if crafting_power == 0 or crafting_power > cluster.ls_crafts then
        return false
    end
    return true
end

---Gets cluster data from storage by name
---@param cluster_name string|nil
---@return ClusterData|nil
local function get_cluster_by_name(cluster_name)
    if not cluster_name then return end
    local clusters = storage.clusters
    local uuid = clusters.name_to_uuid[cluster_name]
    if not uuid then return end
    return clusters.lookup[uuid]
end

------------------------------ GENERAL REQUESTS -------------------------------

---Collects names of all clusters that match with given query.
---@param query string|nil search query
---@return string[]
function ClusterProcessor.get_all_clusters(query)
    local has_query = query and string.find(query, "%S", 1, false)
    local result = {}
    for _, name in pairs(storage.clusters.uuid_to_name) do
        ---@diagnostic disable-next-line
        if not has_query or string.find(name, query, 1, true) then
            table.insert(result, name)
        end
    end
    return result
end

---Collects names of all clusters that match with given query.
---Collects either all optimal clusters or all suboptimal
---@param query string|nil search query
---@param is_optimal boolean true to get all optimal clusters
---@return string[]
function ClusterProcessor.get_all_clusters_by_status(query, is_optimal)
    local clusters = storage.clusters
    local lookup = clusters.lookup
    local has_query = query and string.find(query, "%S", 1, false)
    local result = {}
    for uuid, name in pairs(clusters.uuid_to_name) do
        ---@diagnostic disable-next-line
        if not has_query or string.find(name, query, 1, true) then
            local cluster = lookup[uuid]
            if is_cluster_optimal(cluster) == is_optimal then
                table.insert(result, name)
            end
        end
    end
    return result
end

---Collects names of all clusters bound to given surface. Intended use case:
---getting cluster selection options in entity GUIs.
---@param surface_index integer unique surface identifier
---@param query string|nil search query cluster names are matched against
---@return string[]
function ClusterProcessor.get_surface_clusters(surface_index, query)
    local clusters = storage.clusters
    local lookup = clusters.lookup
    local has_query = query and string.find(query, "%S", 1, false)

    local result = {}
    for uuid, name in pairs(clusters.uuid_to_name) do
        ---@diagnostic disable-next-line
        if not has_query or string.find(name, query, 1, true) then
            if lookup[uuid].surface_index == surface_index then
                table.insert(result, name)
            end
        end
    end
    return result
end

-------------------------- REQUESTS BY DISPLAY NAME ---------------------------

---Gets cluster uuid by cluster name
---@param cluster_name string|nil cluster display name
---@return string|nil cluster_uuid
function ClusterProcessor.get_cluster_uuid(cluster_name)
    if not cluster_name then return end
    return storage.clusters.name_to_uuid[cluster_name]
end

---Checks if given cluster exists in storage and is optimal
---@param cluster_name string|nil cluster display name
---@return boolean status true if cluster is found and optimal
function ClusterProcessor.is_cluster_optimal(cluster_name)
    local cluster = get_cluster_by_name(cluster_name)
    if not cluster then return false end
    return is_cluster_optimal(cluster)
end

---Checks if given cluster exists in storage and is suboptimal
---@param cluster_name string|nil cluster display name
---@return boolean status true if cluster is found and suboptimal
function ClusterProcessor.is_cluster_suboptimal(cluster_name)
    local cluster = get_cluster_by_name(cluster_name)
    if not cluster then return false end
    return not is_cluster_optimal(cluster)
end

---Gets total and operational numbers of members for a given cluster
---@param cluster_name string|nil
---@return integer total, integer operational
function ClusterProcessor.get_total_member_counts(cluster_name)
    local cluster = get_cluster_by_name(cluster_name)
    if not cluster then return 0, 0 end
    return cluster.total_members, cluster.operational_members
end

---@class NamedMemberCount
---@field name string name of entity
---@field total integer total number of members with this name
---@field operational integer number of operational members with this name

---Gets total and operational counts for all cluster members
---@return NamedMemberCount[]
function ClusterProcessor.get_member_counts(cluster_name)
    local cluster = get_cluster_by_name(cluster_name)
    if not cluster then return {} end

    ---@type NamedMemberCount[]
    local result = {}
    local member_counts = cluster.member_counts
    for name, counts in pairs(member_counts) do
        result[#result + 1] = {
            name = name,
            total = counts.total,
            operational = counts.operational
        }
    end
    return result
end

---Gets surface and position of not operational member of given cluster
---@param cluster_name string|nil display name of cluster
---@param entity_name string name of problematic entity
---@return integer|nil surface_index
---@return number|nil pos_x
---@return number|nil pos_y
function ClusterProcessor.get_not_operational_position(cluster_name, entity_name)
    local cluster = get_cluster_by_name(cluster_name)
    -- cluster not found or name was not provided
    if not cluster then return end
    local entry = cluster.member_counts[entity_name]
    -- no cluster members with provided name found
    if not entry then return end
    local unit_number = next(entry.problems)
    -- no problems found
    if not unit_number then return end
    local member_data = cluster.members[unit_number]
    return cluster.surface_index, member_data.x_pos, member_data.y_pos
end

---Gets surface index of given cluster
---@param cluster_name string|nil display name of cluster
---@return string surface_name
function ClusterProcessor.get_cluster_surface_name(cluster_name)
    local cluster = get_cluster_by_name(cluster_name)
    -- cluster not found or name was not provided
    if not cluster then return "None" end
    local surface = game.get_surface(cluster.surface_index)
    if not surface then return "None" end
    return surface.name
end

---Gets template_uuid assigned to given cluster
---@param cluster_name string|nil cluster display name
---@return string|nil template_uuid unique template identifier
function ClusterProcessor.get_assigned_template_by_name(cluster_name)
    local cluster = get_cluster_by_name(cluster_name)
    if not cluster then return end
    return cluster.template_uuid
end

---Gets cluster energy demand and decentralization loss multiplier
---@param cluster_name string|nil cluster display name
---@return number max_energy_per_craft before applying the loss
---@return number decentr_mult decentalization cost multiplier
function ClusterProcessor.get_cluster_energy_demand(cluster_name)
    local cluster = get_cluster_by_name(cluster_name)
    if not cluster then return 0, 1 end
    local max_energy = cluster.energy_per_craft * cluster.crafting_power
    local mult = cluster.decentralization_loss + 1
    return max_energy, mult
end

---Gets maximum crafting power and last second crafts for given cluster
---@param cluster_name string|nil cluster display name
---@return number max_power cluster crafting_power
---@return number utilization cluster ls_crafts
function ClusterProcessor.get_crafting_power_values(cluster_name)
    local cluster = get_cluster_by_name(cluster_name)
    if not cluster then return 0, 0 end
    return cluster.crafting_power, cluster.ls_crafts
end

------------------------------ REQUESTS BY UUID -------------------------------

---Gets cluster name by uuid
---@param cluster_uuid string|nil unique cluster identifier
---@return string|nil cluster_name display name
function ClusterProcessor.get_cluster_name(cluster_uuid)
    if not cluster_uuid then return end
    return storage.clusters.uuid_to_name[cluster_uuid]
end

---Converts an array of cluster uuids to an array of cluster names in place.
---Intended use case: control center gui in "templates" mode.
---@param cluster_uuids string[] this array is modified in-place
function ClusterProcessor.convert_to_cluster_names(cluster_uuids)
    local uuid_to_name = storage.clusters.uuid_to_name
    for i, uuid in ipairs(cluster_uuids) do
        local name = uuid_to_name[uuid]
        if name then cluster_uuids[i] = name end
    end
end

---Checks if cluster with given uuid exists. Intended use case: checking
---cluster existance during on-tick update in entity processor.
---@param cluster_uuid string unique cluster identifier
---@return boolean status true if cluster exists
function ClusterProcessor.does_cluster_exist(cluster_uuid)
    return not not storage.clusters.lookup[cluster_uuid]
end

---Gets build cost of template assigned to given cluster. Intended use case:
---during update of virtualization mainframe in entity processor
---@param cluster_uuid string unique cluster identifier
---@return table<BufferKeyString, number>
function ClusterProcessor.get_build_cost(cluster_uuid)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return {} end
    return cluster.build_cost
end

---Gets uuid of template assigned to given cluster. Intended use case:
---during update of virtualization mainframe in entity processor
---@param cluster_uuid string unique cluster identifier
---@return string|nil template_uuid unique template identifier
function ClusterProcessor.get_assigned_template(cluster_uuid)
    local cluster = storage.clusters.lookup[cluster_uuid]
    if not cluster then return end
    return cluster.template_uuid
end

-------------------------------------------------------------------------------
-------------------------- ON-TICK CLUSTER PROCESSOR --------------------------
-------------------------------------------------------------------------------

---Creates one cluster buffer entry. Helps in setting of assigned template.
---@param cluster ClusterData
---@param io_mode "input"|"output"
---@param buffer_key BufferKeyString
---@param per_craft number
local function create_buffer_entry(cluster, io_mode, buffer_key, per_craft)
    local entry = {
        current = 0,
        per_craft = per_craft,
        maximum = cluster.buffer_capacity[io_mode][buffer_key] or 0,
        ls_input_flow = 0,
        ls_output_flow = 0,
        cs_flow = 0,
        ls_possible_crafts = 0,
    }
    -- looking for "//" seperator in buffer key
    local start_idx, stop_idx = string.find(buffer_key, "//", 1, true)
    if start_idx then
        -- item key "name//quality"
        local name = string.sub(buffer_key, 1, start_idx - 1)
        local quality = string.sub(buffer_key, stop_idx + 1)
        entry.item_id = {name = name, quality = quality}
        entry.type = "item"
    elseif buffer_key == "electric_energy" then
        -- energy key 
        entry.type = "energy"
    else
        -- fluid key "name"
        entry.fluid_name = buffer_key
        entry.type = "fluid"
    end
    cluster[io_mode][buffer_key] = entry
end


---Used when template for given cluster needs to change.
---Called during on-tick cluster update if template change is detected.
---@param cluster ClusterData
---@param template TemplateData
local function set_assigned_template(cluster, template)
    cluster.build_cost = template.building_cost

    -- updating cluster input buffer
    cluster.input = {}
    for buffer_key, per_craft in pairs(template.input) do
        create_buffer_entry(cluster, "input", buffer_key, per_craft)
    end
    -- handling template energy drain and input energy per craft
    local energy_drain = template.energy_drain
    if not cluster.input.electric_energy then
        create_buffer_entry(cluster, "input", "electric_energy", 0)
    end
    local energy_input = cluster.input.electric_energy.per_craft
    cluster.energy_per_craft = energy_drain + energy_input
    update_cluster_energy_demand(cluster)

    -- updating cluster output buffer
    cluster.output = {}
    for buffer_key, per_craft in pairs(template.output) do
        create_buffer_entry(cluster, "output", buffer_key, per_craft)
    end

    drop_crafting_power(cluster)
end

---Helps with processing crafts inside clusters. Calculates
---amount of crafts that can be made with input ingredients.
---@param cluster ClusterData
local function get_input_crafts(cluster)
    local max_crafts = 1e9
    for _, entry in pairs(cluster.input) do
        local curr_crafts = entry.current / entry.per_craft
        entry.ls_possible_crafts = math.max(0, curr_crafts)
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
        local curr_crafts = (entry.maximum - entry.current) / entry.per_craft
        entry.ls_possible_crafts = math.max(0, curr_crafts)
        max_crafts = math.min(max_crafts, curr_crafts)
    end
    return max_crafts
end

---Helps with processing crafts inside clusters.
---Adds data to production statistics assuming LuaFlowStatistics is valid.
---@param cluster ClusterData
---@param entry ClusterBufferEntry
---@param count number positive to add to "produced", negative to add to "consumed"
local function add_to_statistics(cluster, entry, count)
    local entry_type = entry.type
    if entry_type == "energy" then return end
    if entry_type == "item" then
        -- adding to item statistics
        ---@type LuaFlowStatistics
        local statistics = cluster.item_statistics
        statistics.on_flow(entry.item_id, count)
    else
        -- adding to fluid statistics
        ---@type LuaFlowStatistics
        local statistics = cluster.fluid_statistics
        statistics.on_flow(entry.fluid_name, count)
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

---On-tick updater for one virtualization cluster
---@param cluster ClusterData
local function update_cluster(cluster)
    cluster.ls_crafts = 0
    -- checking template assigned to this cluster
    local template_uuid, template = TCCManager.get_assigned_template(
        cluster.cluster_uuid
    )
    -- only changing to new template if it exists (not nil)
    if template_uuid and template_uuid ~= cluster.template_uuid then
        ---@cast template TemplateData
        cluster.template_uuid = template_uuid
        set_assigned_template(cluster, template)
    end
    -- template is not assigned/inaccessible: cannot craft
    if not template_uuid then return end
    -- production statistics is inaccessible: cannot craft
    -- (surface was probably deleted or smth)
    if not cluster.item_statistics.valid then return end

    -- calculating how many crafts can be performed
    local max_crafts = math.min(
        cluster.crafting_power,
        get_input_crafts(cluster),
        get_output_crafts(cluster)
    )
    -- max_crafts is too small: cannot craft
    if max_crafts < 0.01 then return end
    withdraw_inputs(cluster, max_crafts)
    generate_outputs(cluster, max_crafts)
    cluster.ls_crafts = max_crafts
end

---@param event EventData.on_tick
function ClusterProcessor.on_tick(event)
    local array = storage.clusters.array
    local offset = (event.tick % 60) + 1
    for i = offset, #array, 60 do
        update_cluster(array[i])
    end
end

return ClusterProcessor