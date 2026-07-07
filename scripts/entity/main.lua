local names = require("scripts.gui.names")
local udlink_manager = require("scripts.entity.udlink-manager")
local mainframe_manager = require("scripts.entity.vmainframe-manager")
local registry = require("scripts.entity.entity-registry")
require("scripts.entity.copy-paste")


local Helper = {}

-- Maps entity names to their on-tick handlers
local entity_router = {
    [names.prefix .. "item-uplink"] = udlink_manager.update_item_uplink,
    [names.prefix .. "item-downlink"] = udlink_manager.update_item_downlink,
    [names.prefix .. "fluid-uplink"] = udlink_manager.update_fluid_uplink,
    [names.prefix .. "fluid-downlink"] = udlink_manager.update_fluid_downlink,
    [names.prefix .. "energy-uplink"] = udlink_manager.update_energy_uplink,
    [names.prefix .. "energy-downlink"] = udlink_manager.update_energy_downlink,
    [names.prefix .. "virtualization-mainframe"] = mainframe_manager.update_vmainframe,
}

-- Subscribing to all build events
local build_filter = {}
for building_name, _ in pairs(entity_router) do
    table.insert(build_filter, {filter = "name", name = building_name})
end
local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_revive
}
local function on_entity_built(event)
    local entity = event.entity
    registry.register_entity(entity, event.tags)
end
for _, event in ipairs(build_events) do
    script.on_event(event, on_entity_built, build_filter)
end

-- Used for on-tick entity processing
function Helper.entity_processor(event)
    local reg = storage.entity_registry
    -- processing every 60-th element each tick
    local offset = event.tick % 60
    for i = #reg.array - offset, 1, -60 do
        local properties = reg.array[i]
        local entity = properties.entity
        if entity.valid then
            local handler = entity_router[entity.name]
            handler(properties)
        else
            -- auto garbage collection
            registry.unregister_entity(properties.unit_number)
        end
    end
end

return Helper