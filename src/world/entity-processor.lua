--[[
This mod introduces several entities that must have data associated with them in storage,
they also need to be tracked and updated once in a while. This file is used for that.
Entity registry is located at storage.entity_registry is structured as follows:
storage.entity_registry = {
    tick_buckets: table, contains 60 gap-free arrays with entity properties 
    next_bucket_id: number, index of bucket where the next element should be added
    lookup: table, maps unit number of an entity to its properties
}
To have the ability of deleting an element in O(1), properties must contain data
to locate itself in the structure. In out case id of the bucket it's located in
and its index.

Only alive entities (not ghosts) can have properties in entity registry.
However, entity processor provides functionality to manipulate entity tags 
for ghosts, where entity properties are stored before entity is built.
When entity is constructed/revived, ghost tags migrate to entity registry.
--]]

local VSurfaceManager = require("src.world.vsurface-manager")
local ClusterProcessor = require("src.simulation.cluster-processor")
local VEnvProcessor = require("src.simulation.venv-processor")
local TemplateCompiler = require("src.simulation.template-compiler")


---@alias BufferKeyString string "name//quality" for items; "name" for fluids; "electric_energy" for energy

---Table describing one item stack
---@class ItemBuffer
---@field [1] string name of this item
---@field [2] string quality of this item
---@field [3] number number of items contained

---Table describing selected item
---@class ItemSelection
---@field [1] string prototype name of selected item
---@field [2] string prototype name of selected quality

---Table describing properties of one entity in the entity registry
---@class EntityProperties
---@field [1] number mandatory. Index of the bucket that contains these properties
---@field [2] number mandatory. Index at which these properties are found in the bucket
---@field [3] LuaEntity mandatory. Reference to entity that owns these properties
---@field [4] number mandatory. Unit number of entity that owns these properties
---@field [5] string mandatory. Name of entity that owns these properties
---@field [6] boolean mandatory. True if entity is located on a vsurface
---@field [7] boolean user-input. True if this entity is an output
---@field [8] ItemSelection|false user-input. Table describing selected item
---@field [9] string|false user-input. Name of selected fluid
---@field [10] string|false user-input. Name of first selected template
---@field [11] string|false user-input. Name of second selected template
---@field [12] "item"|"fluid"|"energy"|false user-input. Selected mode of operation
---@field [13] BufferKeyString|false internal. String used for access to cluster/venv tables
---@field [14] ClusterData|false internal. Reference to cluster associated with first selected template
---@field [15] ClusterData|false internal. Reference to cluster associated with second selected template
---@field [16] LuaInventory|false internal. Inventory object of this entity 
---@field [17] number|false internal. Maximum flow limit of this entity
---@field [18] number|false internal. Last second flow of this entity
---@field [19] boolean internal. True if this entity is an operational mainframe
---@field [20] table<BufferKeyString, ItemBuffer>|false internal. requests of this mainframe
---@field [21] table<BufferKeyString, ItemBuffer>|false internal. contents of this mainframe

---Mandatory: all entities have these in properties
local INDEX_BUCKET_ID               = 1
local INDEX_PROPERTIES_INDEX        = 2
local INDEX_ENTITY                  = 3
local INDEX_UNIT_NUMBER             = 4
local INDEX_ENTITY_NAME             = 5
local INDEX_VSURFACE_FLAG           = 6
---User-controlled: these have set and get functions
local INDEX_OUTPUT_FLAG             = 7
local INDEX_SELECTED_ITEM           = 8
local INDEX_SELECTED_FLUID          = 9
local INDEX_FIRST_TEMPLATE          = 10
local INDEX_SECOND_TEMPLATE         = 11
local INDEX_MODE                    = 12
---Internal: these can only be assigned by processor
local INDEX_BUFFER_KEY              = 13
local INDEX_FIRST_CLUSTER           = 14
local INDEX_SECOND_CLUSTER          = 15
local INDEX_INVENTORY               = 16
local INDEX_FLOW_LIMIT              = 17
local INDEX_LS_FLOW                 = 18
local INDEX_OPERATIONAL             = 19
local INDEX_BUILDING_REQUESTS       = 20
local INDEX_BUILDING_CONTENTS       = 21


local PREFIX = "FV-"
local EntityProcessor = {}

-------------------------------------------------------------------------------
-- TEMPLATE IO PROCESSING
-------------------------------------------------------------------------------
---Template IOs help in creation of templates. They serve as inputs and outputs
---of items, fluids and electric energy on virtualization surfaces.


---Updates given template item io
---@param properties EntityProperties
local function process_template_item_io(properties)
    -- does not operate on any surfaces except vsufaces
    if not properties[INDEX_VSURFACE_FLAG] then return end

    -- does not operate without selected item
    local item = properties[INDEX_SELECTED_ITEM]
    if not item then return end
    ---@cast item ItemSelection

    -- assuming inventory was cached earlier
    local inventory = properties[INDEX_INVENTORY]
    local flow_limit = properties[INDEX_FLOW_LIMIT]
    local is_output = properties[INDEX_OUTPUT_FLAG]
    local delta = 0
    -- removing or adding selected item to physical inventory
    if is_output then
        delta = inventory.remove{
            name = item[1],
            quality = item[2],
            count = flow_limit
        }
    else
        delta = inventory.insert{
            name = item[1],
            quality = item[2],
            count = flow_limit
        }
    end
    properties[INDEX_LS_FLOW] = delta
    ---@type string assuming buffer key was created at the moment of item selection
    local buffer_key = properties[INDEX_BUFFER_KEY]
    local entity = properties[INDEX_ENTITY]
    local surface_index = entity.surface_index
    -- storing delta in venv if surface is compiling
    VEnvProcessor.add_io_count(surface_index, buffer_key, delta, is_output)
end

---Updates given template fluid io
---@param properties EntityProperties
local function process_template_fluid_io(properties)
    -- does not operate on any surfaces except vsufaces
    if not properties[INDEX_VSURFACE_FLAG] then return end

    -- does not operate without selected fluid
    local fluid_name = properties[INDEX_SELECTED_FLUID]
    if not fluid_name then return end

    local flow_limit = properties[INDEX_FLOW_LIMIT]
    local is_output = properties[INDEX_OUTPUT_FLAG]
    local entity = properties[INDEX_ENTITY]
    local delta = 0
    -- removing or adding selected fluid to physical inventory
    if is_output then
        delta = entity.extract_fluid{
            name = fluid_name,
            amount = flow_limit
        }
    else
        delta = entity.insert_fluid{
            name = fluid_name,
            amount = flow_limit
        }
    end
    properties[INDEX_LS_FLOW] = delta
    -- storing delta in venv if surface is compiling
    local surface_index = entity.surface_index
    local buffer_key = properties[INDEX_BUFFER_KEY]
    VEnvProcessor.add_io_count(surface_index, buffer_key, delta, is_output)
end

---Updates given template energy io
---@param properties EntityProperties
local function process_template_energy_io(properties)
    -- does not operate on any surfaces except vsufaces
    if not properties[INDEX_VSURFACE_FLAG] then return end

    local entity = properties[INDEX_ENTITY]
    local is_output = properties[INDEX_OUTPUT_FLAG]
    local flow_limit = properties[INDEX_FLOW_LIMIT]
    local current_energy = entity.energy
    local delta = 0
    -- removing or adding energy to this IO
    if is_output then
        delta = math.min(current_energy, flow_limit)
        entity.energy = math.max(current_energy - delta, 0)
    else
        local max_energy = entity.electric_buffer_size
        delta = math.min(max_energy - current_energy, flow_limit)
        entity.energy = math.min(current_energy + delta, max_energy)
    end
    properties[INDEX_LS_FLOW] = delta
    -- storing delta in venv if surface is compiling
    local surface_index = entity.surface_index
    local buffer_key = properties[INDEX_BUFFER_KEY]
    VEnvProcessor.add_io_count(surface_index, buffer_key, delta, is_output)
end

-------------------------------------------------------------------------------
-- CLUSTER IO PROCESSING
-------------------------------------------------------------------------------
---Cluster IOs are used for transfering items to/from vclusters.

---Updates given cluster item io
---@param properties EntityProperties
local function process_cluster_item_io(properties)
    -- does not operate on vsurfaces
    if properties[INDEX_VSURFACE_FLAG] then return end

    -- does not operate without selected item
    local item = properties[INDEX_SELECTED_ITEM]
    if not item then return end
    ---@cast item ItemSelection

    -- does not operate without connection to a cluster
    local cluster = properties[INDEX_FIRST_CLUSTER]
    if not cluster then return end

    local inventory = properties[INDEX_INVENTORY]
    local flow_limit = properties[INDEX_FLOW_LIMIT]
    local is_output = properties[INDEX_OUTPUT_FLAG]
    ---@type string assuming buffer key was generated
    local buffer_key = properties[INDEX_BUFFER_KEY]
    if is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available <= 1 then return end

        -- moving items from cluster to entity inventory
        local inserted_count = inventory.insert{
            name = item[1],
            quality = item[2],
            count = math.min(flow_limit, available)
        }
        properties[INDEX_LS_FLOW] = inserted_count
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, inserted_count)
    else
        local available_space = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available_space <= 1 then return end

        -- moving items from physical inventory to cluster
        local removed_count = inventory.remove{
            name = item[1],
            quality = item[2],
            count = math.min(flow_limit, available_space)
        }
        properties[INDEX_LS_FLOW] = removed_count
        ClusterProcessor.add_to_buffer(cluster, buffer_key, removed_count)
    end
end

---Updates given cluster fluid io
---@param properties EntityProperties
local function process_cluster_fluid_io(properties)
    -- does not operate on vsurfaces
    if properties[INDEX_VSURFACE_FLAG] then return end

    -- does not operate without selected fluid
    local fluid_name = properties[INDEX_SELECTED_FLUID]
    if not fluid_name then return end

    -- does not operate without connection to a cluster
    local cluster = properties[INDEX_FIRST_CLUSTER]
    if not cluster then return end

    local entity = properties[INDEX_ENTITY]
    local is_output = properties[INDEX_OUTPUT_FLAG]
    local flow_limit = properties[INDEX_FLOW_LIMIT]
    ---@type string assuming buffer key was generated
    local buffer_key = properties[INDEX_BUFFER_KEY]
    if is_output then
        -- getting available products
        local available = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available <= 0 then return end

        -- moving fluid from cluster to physical inventory
        local inserted_amount = entity.insert_fluid{
            name = fluid_name,
            amount = math.min(flow_limit, available)
        }
        properties[INDEX_LS_FLOW] = inserted_amount
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, inserted_amount)
    else
        -- getting available space
        local available = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available <= 0 then return end

        -- moving fluid from physical inventory to cluster
        local removed_amount = entity.extract_fluid{
            name = fluid_name,
            amount = math.min(flow_limit, available)
        }
        properties[INDEX_LS_FLOW] = removed_amount
        ClusterProcessor.add_to_buffer(cluster, buffer_key, removed_amount)
    end
end

---Updates given cluster energy io
---@param properties EntityProperties
local function process_cluster_energy_io(properties)
    -- does not operate on vsurfaces
    if properties[INDEX_VSURFACE_FLAG] then return end

    -- does not operate without connection to a cluster
    local cluster = properties[INDEX_FIRST_CLUSTER]
    if not cluster then return end

    local flow_limit = properties[INDEX_FLOW_LIMIT]
    local entity = properties[INDEX_ENTITY]
    local is_output = properties[INDEX_OUTPUT_FLAG]
    local current_energy = entity.energy
    ---@type string assuming buffer key was generated
    local buffer_key = properties[INDEX_BUFFER_KEY]
    if is_output then
        -- getting available products
        local available_amount = ClusterProcessor.get_output_capacity(cluster, buffer_key)
        if available_amount <= 0 then return end

        -- moving energy from cluster to entity
        local max_energy = entity.electric_buffer_size
        local available_space = max_energy - current_energy
        local transfered = math.min(flow_limit, available_amount, available_space)
        entity.energy = math.min(entity.energy + transfered, max_energy)
        properties[INDEX_LS_FLOW] = transfered
        ClusterProcessor.remove_from_buffer(cluster, buffer_key, transfered)
    else
        -- getting available space in cluster input
        local available_space = ClusterProcessor.get_input_space(cluster, buffer_key)
        if available_space <= 0 then return end

        -- moving energy from entity to cluster
        local transfered = math.min(available_space, flow_limit, current_energy)
        entity.energy = math.max(current_energy - transfered, 0)
        properties[INDEX_LS_FLOW] = transfered
        ClusterProcessor.add_to_buffer(cluster, buffer_key, transfered)
    end
end

-------------------------------------------------------------------------------
-- MAINFRAME PROCESSING
-------------------------------------------------------------------------------
---Virtualization mainframes serve as crafting power providers for virtualization clusters.
---VM is a fancy requester chest. On-tick handler does the following:
---Requests construction materials for selected template and makes it operational when necessery

---Maps entity name to building cost multiplier
local building_cost_multiplier = {
    [PREFIX .. "virtualization-mainframe-mk1"] = 1,
    [PREFIX .. "virtualization-mainframe-mk2"] = 10,
    [PREFIX .. "virtualization-mainframe-mk3"] = 100,
}

---Returns all buildings that were used for template construction
---to physical inventory of vmainframe
---@param properties EntityProperties
local function return_buldings_to_inventory(properties)
    -- return if nothing is contained inside
    local contents = properties[INDEX_BUILDING_CONTENTS]
    if not contents or not next(contents) then return end
    ---@cast contents table<BufferKeyString, ItemBuffer>

    local entity = properties[INDEX_ENTITY]
    local inventory = entity.get_inventory(defines.inventory.chest)
    ---Assuming mainframe prototype has an inventory
    ---@cast inventory LuaInventory

    -- returning everything to inventory
    -- TODO: make sure everything fits
    for _, buffer in pairs(contents) do
        if buffer[3] > 0 then
            inventory.insert{
                name = buffer[1],
                quality = buffer[2],
                count = buffer[3]
            }
        end
    end
    properties[INDEX_BUILDING_CONTENTS] = {}
end

---Prepares for construction of new template: copies template building cost to building
---requests, makes sure contained buildings table has sections for all requesting items.
---@param properties EntityProperties
local function prepare_new_template_construction(properties)
    local template_name = properties[INDEX_FIRST_TEMPLATE]
    local build_cost = TemplateCompiler.get_building_cost(template_name)
    local entity_name = properties[INDEX_ENTITY_NAME]
    local multiplier = building_cost_multiplier[entity_name]

    ---@type table<BufferKeyString, ItemBuffer>
    local requests = {}
    ---@type table<BufferKeyString, ItemBuffer>
    local contents = {}
    -- processing all items from building cost of new template
    for key, count in pairs(build_cost) do
        -- assuming here that building cost only includes items
        local name, quality = key:match("^(.+)//(.+)$")
        requests[key] = {name, quality, count * multiplier}
        contents[key] = {name, quality, 0}
    end
    properties[INDEX_BUILDING_REQUESTS] = requests
    properties[INDEX_BUILDING_CONTENTS] = contents
end

---Clears logistic requests of a given vmainframe
---@param properties EntityProperties
---@return LuaLogisticPoint
local function clear_logistic_requests(properties)
    local entity = properties[INDEX_ENTITY]
    ---@type LuaLogisticPoint assuming mainframe has it
    local log_point = entity.get_requester_point()

    log_point.trash_not_requested = true
    local section_count = log_point.sections_count
    for i = section_count, 1, -1 do
        log_point.remove_section(i)
    end
    return log_point
end

---Adds everything from requests table to logistic requests of a given VM
---@param properties EntityProperties
local function set_logistic_requests(properties)
    local requests = properties[INDEX_BUILDING_REQUESTS]
    if not requests or not next(requests) then return end
    ---@cast requests table<BufferKeyString, ItemBuffer>

    local log_point = clear_logistic_requests(properties)
    -- creating one logistic section
    log_point.add_section()
    local log_section = log_point.get_section(1)

    -- requesting all construction materials
    local curr_slot = 1
    for _, buffer in pairs(requests) do
        local filter = {
            value = {name = buffer[1], quality = buffer[2]},
            min = buffer[3],
            max = buffer[3],
        }
        log_section.set_slot(curr_slot, filter)
        curr_slot = curr_slot + 1
    end
end

---Scans mainframe inventory and withdraws anything that is in building requests
---@param properties EntityProperties
local function withdraw_building_materials(properties)
    local requests = properties[INDEX_BUILDING_REQUESTS]
    if not requests or not next(requests) then return end
    ---@cast requests table<BufferKeyString, ItemBuffer>

    local entity = properties[INDEX_ENTITY]
    local inventory = entity.get_inventory(defines.inventory.chest)
    ---Assuming mainframe prototype has an inventory
    ---@cast inventory LuaInventory

    -- iterating over inventory contents
    local inv_contents = inventory.get_contents()
    for _, item in ipairs(inv_contents) do
        local name, quality = item.name, item.quality
        local available_count = item.count

        local key = name .. "//" .. quality
        local buffer = requests[key]
        -- if buffer is not found, we skip it
        if not buffer then goto continue end

        local demand = buffer[3]
        local removed_count = inventory.remove{
            name = name,
            quality = quality,
            count = math.min(demand, available_count)
        }

        -- updating item requests
        buffer[3] = buffer[3] - removed_count
        if buffer[3] == 0 then requests[key] = nil end

        -- updating contained buildings
        local contained_buffer = properties[INDEX_BUILDING_CONTENTS][key]
        contained_buffer[3] = contained_buffer[3] + removed_count

        ::continue::
    end
end

---On-tick processor for virtualization mainframes
---@param properties EntityProperties
local function process_mainframe(properties)
    -- does not operate on vsurfaces
    if properties[INDEX_VSURFACE_FLAG] then return end

    -- does not do anything if already operational
    if properties[INDEX_OPERATIONAL] then return end

    -- handling building requests (only if mainframe is not operational)
    withdraw_building_materials(properties)
    set_logistic_requests(properties)
    local requests = properties[INDEX_BUILDING_REQUESTS]
    local cluster = properties[INDEX_FIRST_CLUSTER]
    if cluster and (not requests or not next(requests)) then
        local entity = properties[INDEX_ENTITY]
        ClusterProcessor.enable_crafting_power(entity, cluster)
        clear_logistic_requests(properties)
        properties[INDEX_OPERATIONAL] = true
    end
end

-------------------------------------------------------------------------------
-- INTER-CLUSTER BRIDGE PROCESSING
-------------------------------------------------------------------------------
---Cluster bridges transfer item/fluid/energy from output of one cluster to
---input of another cluster. For each cluster bridge following fields can be selected:
---source template, destination template, mode of operation (item/fluid/energy),
---item to transfer for items, fluid to transfer for fluids.

---Maps entity names to their flow limits
local bridge_flow_limits = {
    [PREFIX .. "inter-cluster-bridge-mk1"] = {
        item = 1e6,
        fluid = 1e6,
        energy = 1e12,
    },
    [PREFIX .. "inter-cluster-bridge-mk2"] = {
        item = 1e9,
        fluid = 1e9,
        energy = 1e15,
    },
    [PREFIX .. "inter-cluster-bridge-mk3"] = {
        item = 1e12,
        fluid = 1e12,
        energy = 1e18,
    },
}

---Caches flow limit for inter-cluster bridge based on tier and operation mode.
---@param properties EntityProperties
local function cache_flow_limit_cluster_bridge(properties)
    local entity_name = properties[INDEX_ENTITY_NAME]
    local mode = properties[INDEX_MODE]
    local flow_limit = bridge_flow_limits[entity_name][mode]
    properties[INDEX_FLOW_LIMIT] = flow_limit
end

---On-tick updater for inter cluster bridge
---@param properties EntityProperties
local function process_bridge(properties)
    -- does not operate on vsurfaces
    if properties[INDEX_VSURFACE_FLAG] then return end

    -- does not operate without connection to source cluster
    local source_cluster = properties[INDEX_FIRST_CLUSTER]
    if not source_cluster then return end

    -- does not operate without connection to destination cluster
    local destination_cluster = properties[INDEX_SECOND_CLUSTER]
    if not destination_cluster then return end

    -- does not operate without cached buffer key
    local buffer_key = properties[INDEX_BUFFER_KEY]
    if not buffer_key then return end


    local flow_limit = properties[INDEX_FLOW_LIMIT]
    local output_limit = ClusterProcessor.get_output_capacity(source_cluster, buffer_key)
    local input_limit = ClusterProcessor.get_input_space(destination_cluster, buffer_key)
    local transfered = math.min(flow_limit, output_limit, input_limit)
    properties[INDEX_LS_FLOW] = transfered
    if transfered <= 0 then return end

    ClusterProcessor.remove_from_buffer(source_cluster, buffer_key, transfered)
    ClusterProcessor.add_to_buffer(destination_cluster, buffer_key, transfered)
end

-------------------------------------------------------------------------------
-- HANDLER ROUTER AND BUILD EVENT FILTER
-------------------------------------------------------------------------------

---Maps entity names recognized by this registry to their on-tick handlers
local entity_router = {
    [PREFIX .. "template-item-io-mk1"] = process_template_item_io,
    [PREFIX .. "template-item-io-mk2"] = process_template_item_io,
    [PREFIX .. "template-item-io-mk3"] = process_template_item_io,
    [PREFIX .. "template-fluid-io-mk1"] = process_template_fluid_io,
    [PREFIX .. "template-fluid-io-mk2"] = process_template_fluid_io,
    [PREFIX .. "template-fluid-io-mk3"] = process_template_fluid_io,
    [PREFIX .. "template-energy-io-mk1"] = process_template_energy_io,
    [PREFIX .. "template-energy-io-mk2"] = process_template_energy_io,
    [PREFIX .. "template-energy-io-mk3"] = process_template_energy_io,
    [PREFIX .. "cluster-item-io-mk1"] = process_cluster_item_io,
    [PREFIX .. "cluster-item-io-mk2"] = process_cluster_item_io,
    [PREFIX .. "cluster-item-io-mk3"] = process_cluster_item_io,
    [PREFIX .. "cluster-fluid-io-mk1"] = process_cluster_fluid_io,
    [PREFIX .. "cluster-fluid-io-mk2"] = process_cluster_fluid_io,
    [PREFIX .. "cluster-fluid-io-mk3"] = process_cluster_fluid_io,
    [PREFIX .. "cluster-energy-io-mk1"] = process_cluster_energy_io,
    [PREFIX .. "cluster-energy-io-mk2"] = process_cluster_energy_io,
    [PREFIX .. "cluster-energy-io-mk3"] = process_cluster_energy_io,
    [PREFIX .. "virtualization-mainframe-mk1"] = process_mainframe,
    [PREFIX .. "virtualization-mainframe-mk2"] = process_mainframe,
    [PREFIX .. "virtualization-mainframe-mk3"] = process_mainframe,
    [PREFIX .. "inter-cluster-bridge-mk1"] = process_bridge,
    [PREFIX .. "inter-cluster-bridge-mk2"] = process_bridge,
    [PREFIX .. "inter-cluster-bridge-mk3"] = process_bridge,
}

---Filter used to subscribe to build events
EntityProcessor.build_filter = {}
for name, _ in pairs(entity_router) do
    table.insert(EntityProcessor.build_filter, {filter = "name", name = name})
end

-------------------------------------------------------------------------------
-- DECLARATION OF COPYABLE PROPERTIES
-------------------------------------------------------------------------------

---Copyable fields of template item io
local template_item_io_copyable = {
    INDEX_OUTPUT_FLAG,
    INDEX_SELECTED_ITEM
}

---Copyable fields of template fluid io
local template_fluid_io_copyable = {
    INDEX_OUTPUT_FLAG,
    INDEX_SELECTED_FLUID,
}

---Copyable fields of template energy io
local template_energy_io_copyable = {
    INDEX_OUTPUT_FLAG,
}

---Copyable fields of cluster item io
local cluster_item_io_copyable = {
    INDEX_OUTPUT_FLAG,
    INDEX_SELECTED_ITEM,
    INDEX_FIRST_TEMPLATE,
}

---Copyable fields of cluster fluid io
local cluster_fluid_io_copyable = {
    INDEX_OUTPUT_FLAG,
    INDEX_SELECTED_FLUID,
    INDEX_FIRST_TEMPLATE,
}

---Copyable fields of cluster energy io
local cluster_energy_io_copyable = {
    INDEX_OUTPUT_FLAG,
    INDEX_FIRST_TEMPLATE,
}

---Copyable fields of virtualization mainframe
local virtualization_mainframe_copyable = {
    INDEX_FIRST_TEMPLATE,
}

---Copyable fields of inter-cluster bridge
local inter_cluster_bridge_copyable = {
    INDEX_SELECTED_ITEM,
    INDEX_SELECTED_FLUID,
    INDEX_FIRST_TEMPLATE,
    INDEX_SECOND_TEMPLATE,
    INDEX_MODE,
}

---Maps entity names to their copyable properties
local entity_copyable_fields = {
    [PREFIX .. "template-item-io-mk1"] = template_item_io_copyable,
    [PREFIX .. "template-item-io-mk2"] = template_item_io_copyable,
    [PREFIX .. "template-item-io-mk3"] = template_item_io_copyable,
    [PREFIX .. "template-fluid-io-mk1"] = template_fluid_io_copyable,
    [PREFIX .. "template-fluid-io-mk2"] = template_fluid_io_copyable,
    [PREFIX .. "template-fluid-io-mk3"] = template_fluid_io_copyable,
    [PREFIX .. "template-energy-io-mk1"] = template_energy_io_copyable,
    [PREFIX .. "template-energy-io-mk2"] = template_energy_io_copyable,
    [PREFIX .. "template-energy-io-mk3"] = template_energy_io_copyable,
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk1"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk2"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk3"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_energy_io_copyable,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_energy_io_copyable,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_energy_io_copyable,
    [PREFIX .. "virtualization-mainframe-mk1"] = virtualization_mainframe_copyable,
    [PREFIX .. "virtualization-mainframe-mk2"] = virtualization_mainframe_copyable,
    [PREFIX .. "virtualization-mainframe-mk3"] = virtualization_mainframe_copyable,
    [PREFIX .. "inter-cluster-bridge-mk1"] = inter_cluster_bridge_copyable,
    [PREFIX .. "inter-cluster-bridge-mk2"] = inter_cluster_bridge_copyable,
    [PREFIX .. "inter-cluster-bridge-mk3"] = inter_cluster_bridge_copyable,
}

-------------------------------------------------------------------------------
-- FIELD SETTING HOOKS
-------------------------------------------------------------------------------

---Associates a new first cluster with given entity
---@param properties EntityProperties
local function change_first_cluster(properties)
    -- removing entity from old cluster
    ClusterProcessor.remove_from_cluster(
        properties[INDEX_FIRST_CLUSTER],
        properties[INDEX_UNIT_NUMBER]
    )
    -- adding entity to new cluster
    local cluster = ClusterProcessor.add_to_cluster(
        properties[INDEX_ENTITY],
        properties[INDEX_FIRST_TEMPLATE]
    )
    properties[INDEX_FIRST_CLUSTER] = cluster or false
end

---Associates a new second cluster with given entity
---@param properties EntityProperties
local function change_second_cluster(properties)
    -- removing entity from old cluster
    ClusterProcessor.remove_from_cluster(
        properties[INDEX_SECOND_CLUSTER],
        properties[INDEX_UNIT_NUMBER]
    )
    -- adding entity to new cluster
    local cluster = ClusterProcessor.add_to_cluster(
        properties[INDEX_ENTITY],
        properties[INDEX_SECOND_TEMPLATE]
    )
    properties[INDEX_SECOND_CLUSTER] = cluster or false
end

---Generates a universal buffer key for given entity
---@param properties EntityProperties
local function generate_universal_buffer_key(properties)
    local selected_item = properties[INDEX_SELECTED_ITEM]
    if selected_item then
        local name = selected_item[1]
        local quality = selected_item[2]
        properties[INDEX_BUFFER_KEY] = name .. "//" .. quality
        return
    end
    local selected_fluid = properties[INDEX_SELECTED_FLUID]
    if selected_fluid then
        properties[INDEX_BUFFER_KEY] = selected_fluid
        return
    end
    local mode = properties[INDEX_MODE]
    if mode == "energy" then
        properties[INDEX_BUFFER_KEY] = "electric_energy"
        return
    end
end

---List of functions to perform when setting a field for template item io
local template_item_io_field_setting = {
    [INDEX_SELECTED_ITEM] = {generate_universal_buffer_key},
}

---List of functions to perform when setting a field for cluster item io
local cluster_item_io_field_setting = {
    [INDEX_SELECTED_ITEM] = {generate_universal_buffer_key},
    [INDEX_FIRST_TEMPLATE] = {change_first_cluster},
}

---List of functions to perform when setting a field for cluster fluid io
local cluster_fluid_io_field_setting = {
    [INDEX_FIRST_TEMPLATE] = {change_first_cluster},
}

---List of functions to perform when setting a field for cluster energy io
local cluster_energy_io_field_setting = {
    [INDEX_FIRST_TEMPLATE] = {change_first_cluster},
}

---List of functions to perform when setting a field for virtualization mainframe
local virtualization_mainframe_field_setting = {
    [INDEX_FIRST_TEMPLATE] = {
        change_first_cluster,
        return_buldings_to_inventory,
        prepare_new_template_construction,
    },
}

---List of functions to perform when setting a field for inter-cluster bridge
local inter_cluster_bridge_field_setting = {
    [INDEX_SELECTED_ITEM] = {generate_universal_buffer_key},
    [INDEX_SELECTED_FLUID] = {generate_universal_buffer_key},
    [INDEX_MODE] = {
        generate_universal_buffer_key,
        cache_flow_limit_cluster_bridge,
    },
    [INDEX_FIRST_TEMPLATE] = {change_first_cluster},
    [INDEX_SECOND_TEMPLATE] = {change_second_cluster},
}

---Maps entity names to functions to perform when setting a field in properties
local field_setting_hooks = {
    [PREFIX .. "template-item-io-mk1"] = template_item_io_field_setting,
    [PREFIX .. "template-item-io-mk2"] = template_item_io_field_setting,
    [PREFIX .. "template-item-io-mk3"] = template_item_io_field_setting,
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_field_setting,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_field_setting,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_field_setting,
    [PREFIX .. "cluster-fluid-io-mk1"] = cluster_fluid_io_field_setting,
    [PREFIX .. "cluster-fluid-io-mk2"] = cluster_fluid_io_field_setting,
    [PREFIX .. "cluster-fluid-io-mk3"] = cluster_fluid_io_field_setting,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_energy_io_field_setting,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_energy_io_field_setting,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_energy_io_field_setting,
    [PREFIX .. "virtualization-mainframe-mk1"] = virtualization_mainframe_field_setting,
    [PREFIX .. "virtualization-mainframe-mk2"] = virtualization_mainframe_field_setting,
    [PREFIX .. "virtualization-mainframe-mk3"] = virtualization_mainframe_field_setting,
    [PREFIX .. "inter-cluster-bridge-mk1"] = inter_cluster_bridge_field_setting,
    [PREFIX .. "inter-cluster-bridge-mk2"] = inter_cluster_bridge_field_setting,
    [PREFIX .. "inter-cluster-bridge-mk3"] = inter_cluster_bridge_field_setting,
}

-------------------------------------------------------------------------------
-- REGISTRATION HOOKS
-------------------------------------------------------------------------------

---Caches LuaInventory of given entity to properties. Entity is assumed to be valid
---@param properties EntityProperties
local function cache_inventory_object(properties)
    local entity = properties[INDEX_ENTITY]
    --- assuming entity has a chest inventory
    properties[INDEX_INVENTORY] = entity.get_inventory(defines.inventory.chest)
end

---Caches buffer key for energy IO
---@param properties EntityProperties
local function cache_energy_buffer_key(properties)
    properties[INDEX_BUFFER_KEY] = "electric_energy"
end

---Maps entity names to their flow limits
local single_mode_flow_limits = {
    [PREFIX .. "template-item-io-mk1"] = 100,
    [PREFIX .. "template-item-io-mk2"] = 1000,
    [PREFIX .. "template-item-io-mk3"] = 10000,
    [PREFIX .. "template-fluid-io-mk1"] = 1000,
    [PREFIX .. "template-fluid-io-mk2"] = 10000,
    [PREFIX .. "template-fluid-io-mk3"] = 100000,
    [PREFIX .. "template-energy-io-mk1"] = 1e9,
    [PREFIX .. "template-energy-io-mk2"] = 1e10,
    [PREFIX .. "template-energy-io-mk3"] = 1e11,
    [PREFIX .. "cluster-item-io-mk1"] = 100,
    [PREFIX .. "cluster-item-io-mk2"] = 1000,
    [PREFIX .. "cluster-item-io-mk3"] = 10000,
    [PREFIX .. "cluster-fluid-io-mk1"] = 1000,
    [PREFIX .. "cluster-fluid-io-mk2"] = 10000,
    [PREFIX .. "cluster-fluid-io-mk3"] = 100000,
    [PREFIX .. "cluster-energy-io-mk1"] = 1e9,
    [PREFIX .. "cluster-energy-io-mk2"] = 1e10,
    [PREFIX .. "cluster-energy-io-mk3"] = 1e11,
}

---Caches flow limit of an entity
---@param properties EntityProperties
local function cache_flow_limit_single_mode(properties)
    local entity_name = properties[INDEX_ENTITY_NAME]
    properties[INDEX_FLOW_LIMIT] = single_mode_flow_limits[entity_name]
end

---List of functions to perform when registering template item io
local template_item_io_registration = {
    cache_inventory_object,
    cache_flow_limit_single_mode,
}

---List of functions to perform when registering template fluid io
local template_fluid_io_registration = {
    cache_flow_limit_single_mode,
}

---List of functions to perform when registering template energy io
local template_energy_io_registration = {
    cache_energy_buffer_key,
    cache_flow_limit_single_mode
}

---List of functions to perform when registering cluster item io
local cluster_item_io_registration = {
    cache_inventory_object,
    cache_flow_limit_single_mode,
}

---List of functions to perform when registering cluster fluid io
local cluster_fluid_io_registration = {
    cache_flow_limit_single_mode,
}

---List of functions to perform when registering cluster energy io
local cluster_energy_io_registration = {
    cache_energy_buffer_key,
    cache_flow_limit_single_mode,
}

---Maps entity names to list of functions to perform on registration
local registration_hooks = {
    [PREFIX .. "template-item-io-mk1"] = template_item_io_registration,
    [PREFIX .. "template-item-io-mk2"] = template_item_io_registration,
    [PREFIX .. "template-item-io-mk3"] = template_item_io_registration,
    [PREFIX .. "template-energy-io-mk1"] = template_energy_io_registration,
    [PREFIX .. "template-energy-io-mk2"] = template_energy_io_registration,
    [PREFIX .. "template-energy-io-mk3"] = template_energy_io_registration,
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_registration,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_registration,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_registration,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_energy_io_registration,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_energy_io_registration,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_energy_io_registration,
}

-------------------------------------------------------------------------------
-- UNREGISTRATION HOOKS
-------------------------------------------------------------------------------

---Removes entity from the first cluster it's associated with
---@param properties EntityProperties
local function remove_from_first_cluster(properties)
    ClusterProcessor.remove_from_cluster(
        properties[INDEX_FIRST_CLUSTER],
        properties[INDEX_UNIT_NUMBER]
    )
end

---Removes entity from the second cluster it's associated with
---@param properties EntityProperties
local function remove_from_second_cluster(properties)
    ClusterProcessor.remove_from_cluster(
        properties[INDEX_SECOND_CLUSTER],
        properties[INDEX_UNIT_NUMBER]
    )
end

---List of functions to perform when removing cluster item io from registry
local cluster_item_io_unregistration = {
    remove_from_first_cluster,
}

---List of functions to perform when removing cluster fluid io from registry
local cluster_fluid_io_unregistration = {
    remove_from_first_cluster,
}

---List of functions to perform when removing cluster energy io from registry
local cluster_energy_io_unregistration = {
    remove_from_first_cluster,
}

---List of functions to perform when removing virtualization mainframe from registry
local virtualization_mainframe_unregistration = {
    remove_from_first_cluster,
}

---List of functions to perform when removing inter-cluster bridge from registry
local inter_cluster_bridge_unregistration = {
    remove_from_first_cluster,
    remove_from_second_cluster,
}

---Maps entity names to functions to perform when removing entity from registry
local unregistration_hooks = {
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_unregistration,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_unregistration,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_unregistration,
    [PREFIX .. "cluster-fluid-io-mk1"] = cluster_fluid_io_unregistration,
    [PREFIX .. "cluster-fluid-io-mk2"] = cluster_fluid_io_unregistration,
    [PREFIX .. "cluster-fluid-io-mk3"] = cluster_fluid_io_unregistration,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_energy_io_unregistration,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_energy_io_unregistration,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_energy_io_unregistration,
    [PREFIX .. "virtualization-mainframe-mk1"] = virtualization_mainframe_unregistration,
    [PREFIX .. "virtualization-mainframe-mk2"] = virtualization_mainframe_unregistration,
    [PREFIX .. "virtualization-mainframe-mk3"] = virtualization_mainframe_unregistration,
    [PREFIX .. "inter-cluster-bridge-mk1"] = inter_cluster_bridge_unregistration,
    [PREFIX .. "inter-cluster-bridge-mk2"] = inter_cluster_bridge_unregistration,
    [PREFIX .. "inter-cluster-bridge-mk3"] = inter_cluster_bridge_unregistration,
}

-------------------------------------------------------------------------------
-- REGISTRY OPERATIONS: ADD/DELETE/LOOKUP
-------------------------------------------------------------------------------

---Adds given entity to registry. Is called when build event is triggered.
---@param entity LuaEntity assumed to be valid
---@param tags table|nil build event tags
function EntityProcessor.register_entity(entity, tags)
    local registry = storage.entity_registry
    local lookup = registry.lookup
    ---@type number assuming entity has unit number
    local unit_number = entity.unit_number
    -- entity with this unit number is already registered
    if lookup[unit_number] then return end

    -- calculating mandatory properties
    local bucket_id = registry.next_bucket_id
    registry.next_bucket_id = (bucket_id % 60) + 1
    local bucket = registry.tick_buckets[bucket_id]
    local properties_index = #bucket + 1
    local entity_name = entity.name
    local vsurface_flag = not not VSurfaceManager.get_vsurface_data(
        entity.surface_index
    )

    -- creating new properties table
    local properties = {
        -- mandatory properties
        [INDEX_BUCKET_ID] = bucket_id,
        [INDEX_PROPERTIES_INDEX] = properties_index,
        [INDEX_ENTITY] = entity,
        [INDEX_UNIT_NUMBER] = unit_number,
        [INDEX_ENTITY_NAME] = entity_name,
        [INDEX_VSURFACE_FLAG] = vsurface_flag,
        -- user-controlled properties
        [INDEX_OUTPUT_FLAG] = false,
        [INDEX_SELECTED_ITEM] = false,
        [INDEX_SELECTED_FLUID] = false,
        [INDEX_FIRST_TEMPLATE] = false,
        [INDEX_SECOND_TEMPLATE] = false,
        [INDEX_MODE] = false,
        -- internal properties
        [INDEX_BUFFER_KEY] = false,
        [INDEX_FIRST_CLUSTER] = false,
        [INDEX_SECOND_CLUSTER] = false,
        [INDEX_INVENTORY] = false,
        [INDEX_FLOW_LIMIT] = false,
        [INDEX_LS_FLOW] = false,
        [INDEX_OPERATIONAL] = false,
        [INDEX_BUILDING_REQUESTS] = false,
        [INDEX_BUILDING_CONTENTS] = false,
    }

    -- adding table to bucket and lookup
    bucket[properties_index] = properties
    lookup[unit_number] = properties

    -- copying user-controlled fields from tags
    if tags then
        local relevant_tags = tags[PREFIX]
        if relevant_tags then
            local copyable = entity_copyable_fields[entity_name]
            for _, field in ipairs(copyable) do
                properties[field] = relevant_tags[field]
                -- field setting hooks for given entity
                local hooks = field_setting_hooks[entity_name]
                if hooks then
                    local field_hooks = hooks[field]
                    if field_hooks then
                        -- calling all field hooks
                        for _, hook in ipairs(field_hooks) do
                            hook(properties)
                        end
                    end
                end
            end
        end
    end

    -- performing necessery on-registration actions
    local hooks = registration_hooks[entity_name]
    if hooks then
        for _, hook in ipairs(hooks) do
            hook(properties)
        end
    end
end

---Removes entity from registry. Used for automatic garbage collection.
---@param properties EntityProperties unique entity identifier
local function unregister_entity(properties)
    local registry = storage.entity_registry
    local buckets = registry.tick_buckets

    -- performing unregistration hooks
    local entity_name = properties[INDEX_ENTITY_NAME]
    local hooks = unregistration_hooks[entity_name]
    if hooks then
        for _, hook in ipairs(hooks) do
            hook(properties)
        end
    end

    -- finding the last element added to the registry and removing it
    local last_bucket_id = (registry.next_bucket_id - 2) % 60 + 1
    local last_bucket = buckets[last_bucket_id]
    local last_element = last_bucket[#last_bucket]
    last_bucket[#last_bucket] = nil
    registry.next_bucket_id = last_bucket_id

    -- rewriting the element we want to delete with last element
    local bucket_id = properties[INDEX_BUCKET_ID]
    local index = properties[INDEX_PROPERTIES_INDEX]
    buckets[bucket_id][index] = last_element
    last_element[INDEX_BUCKET_ID] = bucket_id
    last_element[INDEX_PROPERTIES_INDEX] = index

    -- removing element we are deleting from lookup table
    local unit_number = properties[INDEX_UNIT_NUMBER]
    registry.lookup[unit_number] = nil
end

---Gets a reference to entity properties from registry
---@param unit_number number unique entity identifier
---@return EntityProperties|nil properties entity data from registry
local function get_entity_properties(unit_number)
    return storage.entity_registry.lookup[unit_number]
end

-------------------------------------------------------------------------------
-- ENTITY DATA SETTERS: PUBLIC API (GUI CALLS)
-------------------------------------------------------------------------------

---Abstract setter. Sets specified property for a given entity or entity-ghost
---@param entity LuaEntity entity for which property should be set
---@param index number index in properties that will be set
---@param value nil|boolean|table|string value to write in properties[field]
---@param ignore_hooks boolean|nil true to ignore field setting hooks
local function set_entity_property(entity, index, value, ignore_hooks)
    if not entity.valid then return end
    if entity.name == "entity-ghost" then
        -- entity is a ghost: data stored in tags
        local tags = entity.tags or {}
        tags[PREFIX] = tags[PREFIX] or {}
        tags[PREFIX][index] = value
        entity.tags = tags
    else
        -- entity is not a ghost: properties are in registry
        local properties = get_entity_properties(entity.unit_number)
        if not properties then return end
        -- we need to write false if value == nil
        properties[index] = value or false
        if ignore_hooks then return end
        local entity_hooks = field_setting_hooks[entity.name]
        if not entity_hooks then return end
        local hooks = entity_hooks[index]
        if not hooks then return end
        for _, hook in ipairs(hooks) do
            hook(properties)
        end
    end
end

---Sets output flag for given entity or entity-ghost
---@param entity LuaEntity
---@param is_output boolean|nil
function EntityProcessor.set_output_flag(entity, is_output)
    set_entity_property(entity, INDEX_OUTPUT_FLAG, is_output)
end

---Sets selected item for given entity or entity-ghost
---@param entity LuaEntity
---@param name string|nil name of selected item
---@param quality string|nil quality of selected item
function EntityProcessor.set_selected_item(entity, name, quality)
    local item_data = (name and quality and {name, quality}) or nil
    set_entity_property(entity, INDEX_SELECTED_ITEM, item_data)
end

---Sets selected fluid for given entity or entity-ghost
---@param entity LuaEntity
---@param fluid_name string|nil name of the fluid, or nil to clear
function EntityProcessor.set_selected_fluid(entity, fluid_name)
    set_entity_property(entity, INDEX_SELECTED_FLUID, fluid_name)
end

---Sets first template for given entity or entity-ghost
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear
function EntityProcessor.set_first_template(entity, template_name)
    set_entity_property(entity, INDEX_FIRST_TEMPLATE, template_name)
end

---Sets second template name for given entity or entity-ghost
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear 
function EntityProcessor.set_second_template(entity, template_name)
    set_entity_property(entity, INDEX_SECOND_TEMPLATE, template_name)
end

---Sets mode of operation for given entity
---@param entity LuaEntity
---@param mode "item"|"fluid"|"energy" mode of operation
function EntityProcessor.set_mode(entity, mode)
    -- when changing mode we also want to cleanup unused information
    -- for instance, when item mode is chosen, selected fluid is cleared
    if mode ~= "item" then
        set_entity_property(entity, INDEX_SELECTED_ITEM, nil, true)
    end
    if mode ~= "fluid" then
        set_entity_property(entity, INDEX_SELECTED_FLUID, nil, true)
    end
    set_entity_property(entity, INDEX_MODE, mode)
end

-------------------------------------------------------------------------------
-- ENTITY DATA GETTERS: PUBLIC API (GUI CALLS)
-------------------------------------------------------------------------------

---Abstract getter. Gets specified property for a given entity.
---@param entity LuaEntity entity for which data should be retrieved
---@param index number index in properties that is retrieved
---@return any property for table returns reference, not a copy
local function get_entity_property(entity, index)
    if not entity.valid then return end
    if entity.name == "entity-ghost" then
        -- entity is a ghost: properties are stored in tags
        local tags = entity.tags
        if not tags then return end
        local relevant_tags = tags[PREFIX]
        if not relevant_tags then return end
        return relevant_tags[index]
    else
        -- entity is not a ghost: properties in registry
        local properties = get_entity_properties(entity.unit_number)
        if not properties then return end
        return properties[index]
    end
end

---Gets output flag for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return boolean is_output
function EntityProcessor.get_output_flag(entity)
    return get_entity_property(entity, INDEX_OUTPUT_FLAG)
end

---Gets selected item for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil name, string|nil quality  
function EntityProcessor.get_selected_item(entity)
    local selected_item = get_entity_property(entity, INDEX_SELECTED_ITEM)
    if not selected_item then return end
    return selected_item[1], selected_item[2]
end

---Gets selected fluid for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil fluid_name
function EntityProcessor.get_selected_fluid(entity)
    return get_entity_property(entity, INDEX_SELECTED_FLUID)
end

---Gets first template for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil template_name
function EntityProcessor.get_first_template(entity)
    return get_entity_property(entity, INDEX_FIRST_TEMPLATE)
end

---Gets second template for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil template_name
function EntityProcessor.get_second_template(entity)
    return get_entity_property(entity, INDEX_SECOND_TEMPLATE)
end

---Gets mode of operation for a given entity
---@param entity LuaEntity entity for which data should be retrieved
---@return "item"|"fluid"|"energy"|false mode
function EntityProcessor.get_mode(entity)
    return get_entity_property(entity, INDEX_MODE)
end

-------------------------------------------------------------------------------
-- COPY-PASTE
-------------------------------------------------------------------------------

---Adds tags to entities when player creates blueprint
---@param event EventData.on_player_setup_blueprint
function EntityProcessor.setup_blueprint_tags(event)
    local blueprint = event.stack
    if not blueprint then return end
    -- maps blueprint entity index to "real world" entity
    local mapping = event.mapping.get()

    for b_entity_index, entity in ipairs(mapping) do
        if not entity or not entity.valid then goto continue end
        -- skipping entities that are not recognized by this registry
        local entity_name = entity.name
        if not entity_router[entity_name] then goto continue end

        -- if registry does not have entity properties we have to skip it
        local properties = get_entity_properties(entity.unit_number)
        if not properties then goto continue end

        -- creating a shallow copy with all copyable properties
        local properties_copy = {}
        local copyable_fields = entity_copyable_fields[entity_name]
        for _, field in ipairs(copyable_fields) do
            properties_copy[field] = properties[field]
        end
        blueprint.set_blueprint_entity_tag(b_entity_index, PREFIX, properties_copy)

        ::continue::
    end
end

-- TODO: improve user experience???
-- on_blueprint_settings_pasted
-- on_entity_cloned
-- on_entity_settings_pasted
-- on_player_configured_blueprint
-- on_redo_applied (maybe?)
-- on_undo_applied (maybe?)

-------------------------------------------------------------------------------
-- MAIN PROCESSOR
-------------------------------------------------------------------------------

---On-tick entity processor. Updates one bucket per tick
---@param event EventData.on_tick
function EntityProcessor.process_entities(event)
    local bucket_id = (event.tick % 60) + 1
    local bucket = storage.entity_registry.tick_buckets[bucket_id]

    for i = #bucket, 1, -1 do
        local properties = bucket[i]
        if properties[INDEX_ENTITY].valid then
            local entity_name = properties[INDEX_ENTITY_NAME]
            local handler = entity_router[entity_name]
            handler(properties)
        else
            -- deleting invalid entity from registry
            unregister_entity(properties)
        end
    end
end

return EntityProcessor