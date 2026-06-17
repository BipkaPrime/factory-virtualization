-- This file containes logic regarding Uplinks and Downlinks

local Helpers = {}

-- Updates given item uplink
-- entity must be valid
local function update_item_uplink(entity_properties)
    -- Debug placeholder to ensure it's firing:
    -- game.print("Selected_item " .. entity_properties.selected_item .. " processed at tick " .. game.tick)
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

-- Table that maps entity names to functions used for their processing
local router = {
    ["item-uplink"] = update_item_uplink,
    ["item-downlink"] = update_item_downlink,
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