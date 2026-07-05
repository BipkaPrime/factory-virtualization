-- This file contains on-tick handlers for uplinks and downlinks.
-- All handlers here assume that entity is valid.

--------------------------------------------------------------------------------------------
-- UDLINK REGISTRY PROPERTIES
--------------------------------------------------------------------------------------------
-- entity LuaEntity: reference to entity
-- unit_number uint64: unit number of this entity (not really relevant while entity is valid)
-- selected_template string: selected template for a given entity if any (user input)
-- active_template string: name of template currently in operation
-- cluster table: reference to virtualization cluster that has this udlink as a member

local vcluster = require("scripts.entity-registry.vcluster")
local names = require("scripts.gui.names")

local Helper = {}

-- Checks if template change has occured and in case it did,
-- moves the entity to new virtualization cluster 
local function process_template_change(properties)
    if properties.selected_template ~= properties.active_template then
        vcluster.remove_from_cluster(properties)
        vcluster.add_to_cluster(properties)
        properties.active_template = properties.selected_template
    end
end

-- Processes item downlink that is a vsurface input.
local function vsurface_item_input(properties)
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local item = properties.selected_item
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local inserted_count = inventory.insert({
        name = item.name,
        quality = item.quality,
        count = flow_limit
    })
    -- checking if vsurface is compiling
    local venv = storage.compiling_surfaces[entity.surface_index]
    if not venv then return end
    local section = venv.input.items
    section[item.name] = section[item.name] or {}
    section[item.name][item.quality] = section[item.name][item.quality] or 0
    section[item.name][item.quality] = section[item.name][item.quality] + inserted_count
end

-- Processes item uplink that is a vsurface output.
local function vsurface_item_output(properties)
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local item = properties.selected_item
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local removed_count = inventory.remove({
        name = item.name,
        quality = item.quality,
        count = flow_limit
    })
    -- checking if vsurface is compiling
    local venv = storage.compiling_surfaces[entity.surface_index]
    if not venv then return end
    local section = venv.output.items
    section[item.name] = section[item.name] or {}
    section[item.name][item.quality] = section[item.name][item.quality] or 0
    section[item.name][item.quality] = section[item.name][item.quality] + removed_count
end

-- Processes fluid downlink that is a vsurface input.
local function vsurface_fluid_input(properties)
    local entity = properties.entity
    local fluid = properties.selected_fluid
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local inserted_amount = entity.insert_fluid({
        name = fluid.name,
        amount = flow_limit
    })
    -- checking if vsurface is compiling
    local venv = storage.compiling_surfaces[entity.surface_index]
    if not venv then return end
    local section = venv.input.fluids
    section[fluid.name] = section[fluid.name] or 0
    section[fluid.name] = section[fluid.name] + inserted_amount
end

-- Processes fluid uplink that is a vsurface output.
local function vsurface_fluid_output(properties)
    local entity = properties.entity
    local fluid = properties.selected_fluid
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local drained_amount = entity.extract_fluid({
        name = fluid.name,
        amount = flow_limit
    })
    -- checking if vsurface is compiling
    local venv = storage.compiling_surfaces[entity.surface_index]
    if not venv then return end
    local section = venv.output.fluids
    section[fluid.name] = section[fluid.name] or 0
    section[fluid.name] = section[fluid.name] + drained_amount
end

-- Processes energy downink that is a vsurface input.
local function vsurface_energy_input(properties)
    local entity = properties.entity
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local missing_energy = entity.electric_buffer_size - entity.energy
    local inserted_amount = math.min(missing_energy, flow_limit)
    entity.energy = entity.energy + inserted_amount
    -- checking if vsurface is compiling
    local venv = storage.compiling_surfaces[entity.surface_index]
    if not venv then return end
    venv.input.energy = venv.input.energy + inserted_amount
end

-- Processes energy uplink that is a vsurface output.
local function vsurface_energy_output(properties)
    local entity = properties.entity
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local drained_amount = math.min(entity.energy, flow_limit)
    entity.energy = entity.energy - drained_amount
    -- checking if vsurface is compiling
    local venv = storage.compiling_surfaces[entity.surface_index]
    if not venv then return end
    venv.output.energy = venv.output.energy + drained_amount
end

-- key: entity name, value: vsurface_io handler
local vsurface_io_router = {
    [names.prefix .. "item-uplink"] = vsurface_item_output,
    [names.prefix .. "item-downlink"] = vsurface_item_input,
    [names.prefix .. "fluid-uplink"] = vsurface_fluid_output,
    [names.prefix .. "fluid-downlink"] = vsurface_fluid_input,
    [names.prefix .. "energy-uplink"] = vsurface_energy_output,
    [names.prefix .. "energy-downlink"] = vsurface_energy_input,
}
-- Checks if vsurface_io flag is set and takes necessery actions if it is
local function process_vsurface_io(properties)
    if not properties.vsurface_io then return end
    local entity = properties.entity
    -- checking surface being a vsurface
    local surface_index = entity.surface_index
    if not storage.v_surfaces[surface_index] then
        properties.vsurface_io = nil
        return
    end
    local handler = vsurface_io_router[entity.name]
    if not handler then return end
    handler(properties)
end

-- Uploades item from a given item uplink to associated vcluster.
local function upload_item(properties)
    -- making sure uplink is connected to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting the buffer for the item and checking its existance
    local item = properties.selected_item
    local key = item.name .. "//" .. item.quality
    local buffer = cluster.input[key]
    if not buffer then return end

    -- moving items from inventory to virtual buffer
    local available_space = math.floor(buffer[3] - buffer[1])
    if available_space <= 0 then return end
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local removed_count = inventory.remove({
        name = item.name,
        quality = item.quality,
        count = math.min(flow_limit, available_space)
    })
    buffer[1] = buffer[1] + removed_count
end

-- Downloades item to a given item downlink from associated vcluster.
local function download_item(properties)
    -- making sure downlink is connected to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting the buffer for the item and checking its existance
    local item = properties.selected_item
    local key = item.name .. "//" .. item.quality
    local buffer = cluster.output[key]
    if not buffer then return end

    -- moving items from cluster to physical inventory
    local available_count = math.floor(buffer[1])
    if available_count <= 0 then return end

    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local inserted_count = inventory.insert({
        name = item.name,
        quality = item.quality,
        count = math.min(flow_limit, available_count)
    })
    buffer[1] = buffer[1] - inserted_count
end

-- Uploades fluid from a given fluid uplink to associated vcluster
local function upload_fluid(properties)
    -- making sure uplink is connected to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting the buffer for the fluid and checking its existance
    local fluid = properties.selected_fluid
    local key = fluid.name
    local buffer = cluster.input[key]
    if not buffer then return end

    -- moving fluid from physical inventory to vcluster
    local available_space = math.floor(buffer[3] - buffer[1])
    if available_space <= 0 then return end
    local entity = properties.entity
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local removed_amount = entity.extract_fluid({
        name = fluid.name,
        amount = math.min(flow_limit, available_space)
    })
    buffer[1] = buffer[1] + removed_amount
end

-- Downloades fluid to a given fluid downlink from associated vcluster
local function download_fluid(properties)
    -- making sure downlink is connected to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting the buffer for the fluid and checking its existance
    local fluid = properties.selected_fluid
    local key = fluid.name
    local buffer = cluster.output[key]
    if not buffer then return end

    -- moving fluid from vcluster to physical inventory
    local available_amount = math.floor(buffer[1])
    if available_amount <= 0 then return end
    local entity = properties.entity
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local inserted_amount = entity.insert_fluid({
        name = fluid.name,
        amount = math.min(flow_limit, available_amount)
    })
    buffer[1] = buffer[1] - inserted_amount
end

-- Uploades electric energy from a given energy uplink to vcluster
local function upload_energy(properties)
    -- making sure uplink is connected to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting buffer for the energy and checking its existance
    local key = "electric_energy"
    local buffer = cluster.input[key]
    if not buffer then return end

    -- moving energy from uplink to vcluster
    local available_space = math.floor(buffer[3] - buffer[1])
    if available_space <= 0 then return end
    local entity = properties.entity
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local available_energy = math.min(flow_limit, entity.energy)
    local transfered = math.min(available_space, available_energy)
    entity.energy = entity.energy - transfered
    buffer[1] = buffer[1] + transfered
end

-- Downloades electric energy to a given energy downlink from vcluster
local function download_energy(properties)
    -- making sure downlink is connected to a cluster
    local cluster = properties.cluster
    if not cluster then return end

    -- getting buffer for the energy and checking its existance
    local key = "electric_energy"
    local buffer = cluster.output[key]
    if not buffer then return end

    -- moving energy from vcluster to downlink
    local available_amount = math.floor(buffer[1])
    if available_amount <= 0 then return end
    local entity = properties.entity
    local flow_limit = storage.entity_params[entity.name].flow_limit
    local available_space = math.min(flow_limit, entity.electric_buffer_size - entity.energy)
    local transfered = math.min(available_space, available_amount)
    entity.energy = entity.energy + transfered
    buffer[1] = buffer[1] - transfered
end

function Helper.update_item_uplink(properties)
    -- does not operate without item selected
    local item = properties.selected_item
    if not item then return end

    process_vsurface_io(properties)
    process_template_change(properties)
    upload_item(properties)
end

function Helper.update_item_downlink(properties)
    -- does not operate without item selected
    local item = properties.selected_item
    if not item then return end

    process_vsurface_io(properties)
    process_template_change(properties)
    download_item(properties)
end

function Helper.update_fluid_uplink(properties)
    -- does not operate without fluid selected
    local fluid = properties.selected_fluid
    if not fluid then return end

    process_vsurface_io(properties)
    process_template_change(properties)
    upload_fluid(properties)
end


function Helper.update_fluid_downlink(properties)
    -- does not operate without fluid selected
    local fluid = properties.selected_fluid
    if not fluid then return end

    process_vsurface_io(properties)
    process_template_change(properties)
    download_fluid(properties)
end


function Helper.update_energy_uplink(properties)
    process_vsurface_io(properties)
    process_template_change(properties)
    upload_energy(properties)
end


function Helper.update_energy_downlink(properties)
    process_vsurface_io(properties)
    process_template_change(properties)
    download_energy(properties)
end

return Helper