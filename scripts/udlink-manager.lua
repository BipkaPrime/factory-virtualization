-- This file contains on-tick handlers for uplinks and downlinks.

local Helper = {}


-- Updates given item uplink. Entity is assumed to be valid
function Helper.update_item_uplink(properties)
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)

    -- checking if item is selected
    local item = properties.selected_item
    if not item then return end

    -- checking if this uplink is a vsurface output
    if properties.vsurface_io then
        local removed_count = inventory.remove({name=item.name, quality=item.quality, count=1000000})
        -- we need to check if vsurface is compiling
        local venv = storage.compiling_surfaces[entity.surface_index]
        if venv then
            local section = venv.output.items
            -- creating a section in output for this item if it doesn't exist
            section[item.name] = section[item.name] or {}
            -- creating a section in this item for quality if it doesn't exist
            section[item.name][item.quality] = section[item.name][item.quality] or 0
            -- adding items removed from uplink to venv
            section[item.name][item.quality] = section[item.name][item.quality] + removed_count
        end
    end
end

-- Updates given item downlink. Entity is assumed to be valid
function Helper.update_item_downlink(properties)
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    -- checking if item is selected
    local item = properties.selected_item
    if not item then return end
    -- checking if this downlink is a vsurface input
    if properties.vsurface_io then
        local inserted_count = inventory.insert({name=item.name, quality=item.quality, count=1000000})
        -- we need to check if vsurface is compiling
        local venv = storage.compiling_surfaces[entity.surface_index]
        if venv then
            local section = venv.input.items
            -- creating a section in input for this item if it doesn't exist
            section[item.name] = section[item.name] or {}
            -- creating a section in this item for quality if it doesn't exist
            section[item.name][item.quality] = section[item.name][item.quality] or 0
            -- adding items spawned in this downlink to venv
            section[item.name][item.quality] = section[item.name][item.quality] + inserted_count
        end
    end
end

-- Updates given fluid uplink. Entity is assumed to be valid
function Helper.update_fluid_uplink(properties)
    local entity = properties.entity

    -- checking if fluid is selected
    local fluid = properties.selected_fluid
    if not fluid then return end

    -- checking if this uplink is a vsurface output
    if properties.vsurface_io then
        local drained_amount = entity.remove_fluid({name=fluid.name, amount=10000000})
        -- we need to check if vsurface is compiling
        local venv = storage.compiling_surfaces[entity.surface_index]
        if venv then
            local section = venv.output.fluids
            -- creating a section in output for this fluid if it doesn't exist
            section[fluid.name] = section[fluid.name] or 0
            -- adding fluid removed from this uplink to venv
            section[fluid.name] = section[fluid.name] + drained_amount
        end
    end
end

-- Updates given fluid downlink. Entity is assumed to be valid
function Helper.update_fluid_downlink(properties)
    local entity = properties.entity

    -- checking if fluid is selected
    local fluid = properties.selected_fluid
    if not fluid then return end

    -- checking if this downlink is a vsurface input
    if properties.vsurface_io then
        local inserted_amount = entity.insert_fluid({name=fluid.name, amount=10000000})
        -- we need to check if vsurface is compiling
        local venv = storage.compiling_surfaces[entity.surface_index]
        if venv then
            local section = venv.input.fluids
            -- creating a section in input for this fluid if it doesn't exist
            section[fluid.name] = section[fluid.name] or 0
            -- adding inserted_amount to venv
            section[fluid.name] = section[fluid.name] + inserted_amount
        end
    end
end

-- Updates given energy uplink. Entity is assumed to be valid
function Helper.update_energy_uplink(properties)
    local entity = properties.entity

    -- checking if this uplink is a vsurface output
    if properties.vsurface_io then
        local drained_amount = entity.energy
        entity.energy = 0
        -- we need to check if vsurface is compiling
        local venv = storage.compiling_surfaces[entity.surface_index]
        if venv then
            -- adding drained_amount to venv output
            venv.output.energy = venv.output.energy + drained_amount
        end
    end
end

-- Updates given energy downlink. Entity is assumed to be valid
function Helper.update_energy_downlink(properties)
    local entity = properties.entity

    -- checking if this downlink is a vsurface input
    if properties.vsurface_io then
        -- filling downlink with energy
        local max_buffer = entity.electric_buffer_size
        local curr_buffer = entity.energy
        entity.energy = max_buffer
        local inserted_amount = max_buffer - curr_buffer

        -- we need to check if vsurface is compiling
        local venv = storage.compiling_surfaces[entity.surface_index]
        if venv then
            -- adding inserted_amount to venv input
            venv.input.energy = venv.input.energy + inserted_amount
        end
    end
end

return Helper