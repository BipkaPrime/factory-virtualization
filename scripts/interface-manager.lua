-- This file containes logic regarding Uplinks and Downlinks

local Helpers = {}

-- Updates given item uplink
local function update_item_uplink(entity)
    -- Debug placeholder to ensure it's firing:
    game.print("Item Uplink " .. entity.unit_number .. " processed at tick " .. game.tick)
end

-- Updates given item uplink
local function update_item_downlink(entity)
    -- Debug placeholder to ensure it's firing:
    game.print("Item Downlink " .. entity.unit_number .. " processed at tick " .. game.tick)
end

-- Table that maps entity names to functions used for their processing
local router = {
    ["item-uplink"] = update_item_uplink,
    ["item-downlink"] = update_item_downlink,
}

-- Distributed processor called on_tick
function Helpers.process_interfaces(event)
    for entity_name, handler in pairs(router) do
        local section = storage.entity_registry[entity_name]
        local elements = section.array
        local total_count = #elements
        if total_count > 0 then
            -- Interleave processing: look at every 60th item
            local offset = (event.tick % 60) + 1
            for i = offset, total_count, 60 do
                local entity = elements[i].entity
                handler(entity)
            end
        end
    end
end


return Helpers