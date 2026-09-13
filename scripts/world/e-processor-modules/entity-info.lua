---Used to provide necessory information from entity processor to gui

local EntityProcessor = require("scripts.world.entity-processor")


local EntityInfo = {}


---Gets status of entity from entity processor by unit number.
---@param unit_number integer unique entity identifier
---@return LocalisedString entity_status
function EntityInfo.get_entity_status(unit_number)
    local properties = EntityProcessor.get_entity_properties(unit_number)
    if not properties then return {"entity-status.not-registered"} end
    return properties.status or {"entity-status.unknown"}
end

---Gets entity performance information.
---@param unit_number integer unique entity identifier
---@return number current_performance ls_flow
---@return number maximum_performance flow_limit
function EntityInfo.get_entity_performance(unit_number)
    local properties = EntityProcessor.get_entity_properties(unit_number)
    if not properties then return 0, 0 end
    return properties.ls_flow or 0, properties.flow_limit or 0
end

---Gets building_requests and building_contents tables for given vm.
---@param unit_number integer unique entity identifier
---@return table<BufferKeyString, ItemBuffer> building_requests
---@return table<BufferKeyString, ItemBuffer> building_contents
function EntityInfo.get_vm_tables(unit_number)
    local properties = EntityProcessor.get_entity_properties(unit_number)
    if not properties then return {}, {} end
    local requests = properties.building_contents or {}
    local contents = properties.building_requests or {}
    return requests, contents
end

return EntityInfo