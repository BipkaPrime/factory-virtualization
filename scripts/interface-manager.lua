-- This file containes logic regarding Virtualization Interfaces

-- scripts/interface-manager.lua
local InterfaceManager = {}

-- Highly optimized logic executed ONCE A SECOND per individual virtualization-interface
local function update_single_interface(entity)
    -- ====================================================================
    -- PLACE YOUR REAL-WORLD INTERFACE CODE HERE
    -- Examples: 
    -- 1. Read input chest contents and push items to the Mainframe cloud
    -- 2. Pull items from the Mainframe cloud and drop them into an output chest
    -- ====================================================================

    -- Debug placeholder to ensure it's firing:
    game.print("Interface " .. entity.unit_number .. " processed at tick " .. game.tick)
end

-- Distributed tick processor called from control.lua every single game tick
function InterfaceManager.process_interfaces(event)
    if not storage.entity_registries then return end
    
    local interface_reg = storage.entity_registries["virtualization-interface"]
    if not (interface_reg and #interface_reg.array > 0) then return end
    
    local entities = interface_reg.array
    local total_count = #entities
    
    -- Calculate which 1/60th slice offset of the flat array to touch this tick (returns 1 to 60)
    local offset = (event.tick % 60) + 1
    
    -- Interleave processing: look at every 60th item to distribute load perfectly
    for i = offset, total_count, 60 do
        local entity = entities[i]
        if entity and entity.valid then
            update_single_interface(entity)
        end
    end
end


return InterfaceManager