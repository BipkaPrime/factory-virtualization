-- This file containes logic regarding Uplinks and Downlinks

local Helpers = {}

-- Updates given item uplink. Entity is assumed to be valid because
-- only entities from entity registry are processed. This DOES mean that
-- if entity added by this mod was desroyed by a script without raising the event, game will crash.
local function update_item_uplink(entity_properties)
    local entity = entity_properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    -- checking if this uplink is a lab surface output
    if entity_properties.checkbox_state then
        -- checking which item is selected
        local item = entity_properties.selected_item
        if item then
            -- if something is selected, we remove it from the uplink
            local removed_count = inventory.remove({name=item.name, quality=item.quality, count=1000000})
            -- we need to check if the uplink is on a lab that is currently compiling
            local venv = storage.compiling_surfaces[entity.surface_index]
            if venv then
                -- creating a section in output for this item if it doesn't exist 
                venv.output.items[item.name] = venv.output.items[item.name] or {}
                -- creating a section in this item for quality if it doesn't exist
                venv.output.items[item.name][item.quality] = venv.output.items[item.name][item.quality] or 0
                -- adding items removed from uplink to venv
                venv.output.items[item.name][item.quality] = venv.output.items[item.name][item.quality] + removed_count
            end
        end
    end
end

-- Updates given item downlink. Entity is assumed to be valid because
-- only entities from entity registry are processed. This DOES mean that
-- if entity added by this mod was desroyed by a script without raising the event, game will crash.
local function update_item_downlink(entity_properties)
    local entity = entity_properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    -- checking if this downlink is a lab surface input
    if entity_properties.checkbox_state then
        -- checking which item is selected
        local item = entity_properties.selected_item
        if item then
            -- if item is selected, we insert it into the downlink
            local inserted_count = inventory.insert({name=item.name, quality=item.quality, count=1000000})
            -- we need to check if the downlink is on a lab that is currently compiling
            local venv = storage.compiling_surfaces[entity.surface_index]
            if venv then
                -- creating a section in input for this item if it doesn't exist
                venv.input.items[item.name] = venv.input.items[item.name] or {}
                -- creating a section in this item for quality if it doesn't exist
                venv.input.items[item.name][item.quality] = venv.input.items[item.name][item.quality] or 0
                -- adding items spawned in this downlink to venv
                venv.input.items[item.name][item.quality] = venv.input.items[item.name][item.quality] + inserted_count
            end
        end
    end
end

-- Updates given fluid uplink. Entity is assumed to be valid because
-- only entities from entity registry are processed. This DOES mean that
-- if entity added by this mod was desroyed by a script without raising the event, game will crash.
local function update_fluid_uplink(entity_properties)
    local entity = entity_properties.entity
    -- checking if this uplink is a lab surface output
    if entity_properties.checkbox_state then
        -- checking which fluid is selected
        local fluid_name = entity_properties.selected_fluid
        if fluid_name then
            -- if fluid is selected, we drain it from the uplink
            local drained_amount = entity.remove_fluid({name=fluid_name, amount=10000000})
            -- we need to check if the uplink is on a lab that is currently compiling
            local venv = storage.compiling_surfaces[entity.surface_index]
            if venv then
                -- creating a section in output for this fluid if it doesn't exist
                venv.output.fluids[fluid_name] = venv.output.fluids[fluid_name] or 0
                -- adding fluid removed from this uplink to venv
                venv.output.fluids[fluid_name] = venv.output.fluids[fluid_name] + drained_amount
            end
        end
    end
end

-- Updates given fluid downlink. Entity is assumed to be valid because
-- only entities from entity registry are processed. This DOES mean that
-- if entity added by this mod was desroyed by a script without raising the event, game will crash.
local function update_fluid_downlink(entity_properties)
    local entity = entity_properties.entity
    -- checking if this downlink is a lab surface input
    if entity_properties.checkbox_state then
        -- checking which fluid is selected
        local fluid_name = entity_properties.selected_fluid
        if fluid_name then
            -- if fluid is selected, we fill the downlink
            local inserted_amount = entity.insert_fluid({name=fluid_name, amount=10000000})
            -- we need to check if the downlink is on a lab that is currently compiling
            local venv = storage.compiling_surfaces[entity.surface_index]
            if venv then
                -- creating a section in input for this fluid if it doesn't exist
                venv.input.fluids[fluid_name] = venv.input.fluids[fluid_name] or 0
                -- adding inserted_amount to venv
                venv.input.fluids[fluid_name] = venv.input.fluids[fluid_name] + inserted_amount
            end
        end
    end
end

-- Updates given energy uplink. Entity is assumed to be valid because
-- only entities from entity registry are processed. This DOES mean that
-- if entity added by this mod was desroyed by a script without raising the event, game will crash.
local function update_energy_uplink(entity_properties)
    local entity = entity_properties.entity
    -- checking if this uplink is a lab surface output
    if entity_properties.checkbox_state then
        local drained_amount = entity.energy
        entity.energy = 0
        -- we need to check if the uplink is on a lab that is currently compiling
        local venv = storage.compiling_surfaces[entity.surface_index]
        if venv then
            -- adding drained_amount to venv output
            venv.output.energy = venv.output.energy + drained_amount
        end
    end
end

-- Updates given energy downlink. Entity is assumed to be valid because
-- only entities from entity registry are processed. This DOES mean that
-- if entity added by this mod was desroyed by a script without raising the event, game will crash.
local function update_energy_downlink(entity_properties)
    local entity = entity_properties.entity
    -- checking if this downlink is a lab surface input
    if entity_properties.checkbox_state then
        -- filling downlink with energy
        local max_buffer = entity.electric_buffer_size
        local curr_buffer = entity.energy
        entity.energy = max_buffer
        local inserted_amount = max_buffer - curr_buffer

        -- we need to check if the uplink is on a lab that is currently compiling
        local venv = storage.compiling_surfaces[entity.surface_index]
        if venv then
            -- adding inserted_amount to venv input
            venv.input.energy = venv.input.energy + inserted_amount
        end
    end
end

-- Table that maps entity names to functions used for their processing
local router = {
    ["item-uplink"] = update_item_uplink,
    ["item-downlink"] = update_item_downlink,
    ["fluid-uplink"] = update_fluid_uplink,
    ["fluid-downlink"] = update_fluid_downlink,
    ["energy-uplink"] = update_energy_uplink,
    ["energy-downlink"] = update_energy_downlink,
}

-- Distributed processor called on_tick
function Helpers.process_udlinks(event)
    for entity_name, handler in pairs(router) do
        local section = storage.entity_registry[entity_name]
        local elements = section.array
        local total_count = #elements
        if total_count > 0 then
            -- Interleave processing: look at every 60th item
            local offset = (event.tick % 60) + 1
            for i = offset, total_count, 60 do
                local entity_properties = elements[i]
                handler(entity_properties)
            end
        end
    end
end


return Helpers