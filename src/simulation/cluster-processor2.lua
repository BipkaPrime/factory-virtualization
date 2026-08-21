


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
---@field name string|nil only present for items and fluids
---@field quality string|nil only present for items


---Contains data for one cluster member
---@class ClusterMemberData
---@field x_pos number x-coordinate of this entity
---@field y_pos number y-coordinate of this entity
---@field weight number weight of this entity
---@field member_key BufferKeyString name//quality of this entity
---@field crafting_power number|nil amount of crafting power entity is contributing
---@field storage_capacity number|nil amount of storage this entity is contributing
---@field buffer ClusterBufferEntry|nil buffer to which entity is contributing
---storage capacity. Only (and always) present if "storage_capacity" is present


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
---Fields related to cluster members (always change when member is added/removed)
---@field members table<integer, ClusterMemberData> key is entity.unit_number.
---contains data for all cluster members
---@field member_counts table<BufferKeyString, integer> counts of all members
---@field sum_x number weighted sum of x-coordinates of all members
---@field sum_y number weighted sum of y coordinates of all members
---@field total_weight number sum of weights of all members
---@field sum_squares number weighted sum of squares (x^2 + y^2)
---of all member positions
---@field decentralization_loss number multiplier of energy per craft
---of this cluster
---
---Related to assigned template, member states, assigned/modified during processing
---@field template_uuid string|nil identifier of template assigned to this cluster
---@field input table<BufferKeyString, ClusterBufferEntry> cluster input buffer
---@field output table<BufferKeyString, ClusterBufferEntry> cluster output buffer
---@field energy_per_craft number electric energy consumption per craft, calculated
---before applying decentralization loss.
---@field crafting_power number maximum number of crafts cluster can produce per second
---@field last_cycle_crafts number crafts performed in the last crafting cycle


---@class ClusterStorage
---@field array ClusterData[] used for on_tick processing
---@field lookup table<string, ClusterData> maps uuids to cluster data
---@field name_to_uuid table<string, string> maps cluster display names to uuids
---@field uuid_to_name table<string, string> maps cluster uuids to display names


local ClusterProcessor = {}


-------------------------------------------------------------------------------
---------------------------- CREATE RENAME DELETE  ----------------------------
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

---@param cluster_name string|nil cluster display name (user input)
---@param surface_name string|nil user input
---@return boolean status true if cluster can be created
---@return LocalisedString|nil reason why cluster cannot be created
function ClusterProcessor.can_create_cluser(cluster_name, surface_name)
    -- checking that cluster name is provided
    if not cluster_name or not string.find(cluster_name, "%S", 1, false) then
        return false, "Cluster name is missing"
    end
    -- checking that surface name is procided
    if not surface_name then
        return false, "Surface name is missing"
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

    -- checking that provided name points to existing surface
    local surface = game.get_surface(surface_name)
    if not surface then
        return false, "[Cluster manager] [color=red]Error:[/color] creation failed, surface not found"
    end
    local surface_index = surface.index

    -- searching for a name that is not occupied
    ---@type ClusterStorage
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
        sum_x = 0,
        sum_y = 0,
        total_weight = 0,
        sum_squares = 0,
        decentralization_loss = 0,
        input = {},
        output = {},
        energy_per_craft = 0,
        crafting_power = 0,
        last_cycle_crafts = 0,
    }

    -- adding cluster to the data structure
    array[array_index] = cluster_data
    clusters.lookup[cluster_uuid] = cluster_data
    name_to_uuid[unique_name] = cluster_uuid
    clusters.uuid_to_name[cluster_uuid] = unique_name
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
        return false, "Old name is missing"
    end
    -- checking that new name is not empty
    if not new_name or not string.find(new_name, "%S", 1, false) then
        return false, "New cluster name cannot be empty"
    end
    -- checking that names are different
    if new_name == old_name then
        return false, "New cluster name cannot be the same as the old one"
    end
    -- checking that new name is not occupied
    local name_to_uuid = storage.clusters.name_to_uuid
    if name_to_uuid[new_name] then
        return false, "Cluster with provided new name already exists"
    end
    -- checking that cluster with old name exists in storage
    if not name_to_uuid[old_name] then
        return false, "Cluster data associated with old name not found"
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
    ---@type ClusterStorage
    local clusters = storage.clusters
    local name_to_uuid = clusters.name_to_uuid
    local cluster_uuid = name_to_uuid[old_name]
    name_to_uuid[new_name] = cluster_uuid
    name_to_uuid[old_name] = nil
    clusters.uuid_to_name[cluster_uuid] = new_name
    return true
end

---Deletes provided cluster from storage
---@param cluster_name string|nil cluster display name
---@return boolean status true if deletion was successful
---@return LocalisedString|nil reason error string if deletion failed
function ClusterProcessor.delete_cluster(cluster_name)
    -- checking that cluster name is provided
    if not cluster_name then
        return false, "[Cluster manager] [color=red]Error:[/color] deletion failed: cluster name not provided"
    end

    -- checking that cluster exists in storage
    ---@type ClusterStorage
    local clusters = storage.clusters
    local name_to_uuid = clusters.name_to_uuid
    local cluster_uuid = name_to_uuid[cluster_name]
    if not cluster_uuid then
        return false, "[Cluster manager] [color=red]Error:[/color] deletion failed: cluster data not found"
    end

    -- Data is found: erasing it from all tables
    --TODO: FINISH

end


