-- This file containes logic regarding Uplinks and Downlinks

local Helpers = {}

-- Updates given item uplink
-- entity must be valid
local function update_item_uplink(entity_properties)
    local entity = entity_properties.entity
    
    -- if this downlink is a lab surface output and has a selected item
    if entity_properties.checkbox_state then
        local inventory = entity.get_inventory(defines.inventory.chest)
        -- checking which item is selected
        local item = entity_properties.selected_item
        if item then
            local removed_count = inventory.remove({name=item.name, quality=item.quality, count=1000000})
        end
    end
end

-- Updates given item downlink
local function update_item_downlink(entity_properties)
    local inventory = entity_properties.entity.get_inventory(defines.inventory.chest)

    -- if this downlink is a lab surface input and has a selected item
    if entity_properties.checkbox_state then
        -- checking which item is selected
        local item = entity_properties.selected_item
        if item then
            local inserted_count = inventory.insert({name=item.name, quality=item.quality, count=1000000})
        end
    end
end

-- Updates given fluid uplink
local function update_fluid_uplink(entity_properties)
    -- if this uplink is a lab surface output and has a selected fluid
    -- we drain the fluid
    local entity = entity_properties.entity
    if entity_properties.checkbox_state then
        -- checking which fluid is selected
        local fluid_name = entity_properties.selected_fluid
        if fluid_name then
            local drained_amount = entity.remove_fluid({name=fluid_name, amount=10000000})
        end
    end
end

-- Updates given fluid downlink
local function update_fluid_downlink(entity_properties)
    -- if this downlink is a lab surface input and has a selected fluid
    -- we fill it with this fluid
    if entity_properties.checkbox_state then
        -- checking which fluid is selected
        local fluid_name = entity_properties.selected_fluid
        if fluid_name then
            local inserted_amount = entity_properties.entity.insert_fluid({name=fluid_name, amount=10000000})
        end
    end
end

-- Updates given energy uplink
local function update_energy_uplink(entity_properties)
    local entity = entity_properties.entity
    -- if this uplink is a lab surface output we drain its energy
    if entity_properties.checkbox_state then
        local drained_amount = entity.energy
        entity.energy = 0
    end
end

-- Updates given energy downlink
local function update_energy_downlink(entity_properties)
    local entity = entity_properties.entity
    -- if this downlink is a lab surface input we fill it with energy
    if entity_properties.checkbox_state then
        local max_buffer = entity.electric_buffer_size
        local curr_buffer = entity.energy
        entity.energy = max_buffer
        local inserted_amount = max_buffer - curr_buffer
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