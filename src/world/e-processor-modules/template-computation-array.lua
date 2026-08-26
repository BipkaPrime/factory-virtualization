--[[
Template computation array is required to produce "computation" resource,
which is needed for template compilation. Computation is a flow variable,
meaning that it cannot be stored and is provided as long as the building is 
powered and running. If energy stored in the entity is not sufficient,
it stops working until enough energy is provided.
-------------------------------------------------------------------------------
-- ENTITY CONFIGURATION
-------------------------------------------------------------------------------
For this building to function following conditions must be met:
I. Entity is not located on a vsurface.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. flow_limit. maximum amount of computation this entity can provide
2. computation_cost. entity power usage for one unit of provided computation
3. startup_energy. amount of energy required to "activate" the entity.

Properties that can be assigned during on-tick processing:
1. operational. Used as an indication that entity is contributing computation potential
2. ls_flow. Used to track how much computation this entity is currently producing.
--]]

local TCCManager = require("src.simulation.tcc-manager")
local VSurfaceManager = require("src.world.vsurface-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local ComputationArray = {}

---This building has no "configuration"
---@type EntityConfigField[]
ComputationArray.configuration = {}

---Maps entity names to amount of computation they provide
local computation_limits = {
    [PREFIX .. "template-computation-array-mk1"] = 1000,
    [PREFIX .. "template-computation-array-mk2"] = 1e6,
    [PREFIX .. "template-computation-array-mk3"] = 1e9,
}

---Maps entity names to energy cost (per tick) of one unit of computation
local computation_costs = {
    [PREFIX .. "template-computation-array-mk1"] = 12000,
    [PREFIX .. "template-computation-array-mk2"] = 120,
    [PREFIX .. "template-computation-array-mk3"] = 1.2,
}

---Maps entity names to their idle power usage (per tick)
local idle_power_consumption = {
    [PREFIX .. "template-computation-array-mk1"] = 5e5,
    [PREFIX .. "template-computation-array-mk2"] = 5e6,
    [PREFIX .. "template-computation-array-mk3"] = 5e7,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function ComputationArray.initialize(properties)
    -- Checking that entity is not located on a virtualization surface
    local entity = properties.entity
    if VSurfaceManager.is_vsurface(entity.surface_index) then
        properties.status = Utilities.entity_status.vsurface_no_work
        return Utilities.registry_sections.incorrect
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    local entity_name = properties.entity_name
    local base_flow = computation_limits[entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    local comp_limit = base_flow * quality_mult
    properties.flow_limit = comp_limit
    local comp_cost = computation_costs[entity_name] / quality_mult
    properties.computation_cost = comp_cost

    local idle_power = idle_power_consumption[entity_name]
    -- energy required for one second of operation at maximum load
    properties.startup_energy = 60 * (comp_limit * comp_cost + idle_power)
    -- when pasting computation array from blueprint, energy usage is pasted as well
    entity.power_usage = idle_power
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function ComputationArray.uninitialize(properties)
    if properties.operational then
        TCCManager.decrease_computation_max_available(
            properties.flow_limit
        )
    end
    properties.flow_limit = nil
    properties.computation_cost = nil
    properties.startup_energy = nil
    properties.ls_flow = nil
    properties.operational = nil
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function ComputationArray.update(properties)
    properties.ls_flow = 0
    local entity = properties.entity
    local current_energy = entity.energy
    ---@type number assigned on initialization
    local comp_limit = properties.flow_limit

    -- Trying to turn on the entity if possible
    if not properties.operational and current_energy >= properties.startup_energy then
        TCCManager.increase_computation_max_available(comp_limit)
        properties.operational = true
        properties.status = Utilities.entity_status.operational
    end

    -- Handling entity being operational
    if properties.operational then
        -- getting amount of computation expected from this entity
        local demand_ratio = TCCManager.get_computation_demand_ratio()
        local requested = comp_limit * demand_ratio
        properties.ls_flow = requested

        -- changing power consumption according to requested computation
        local idle_power = idle_power_consumption[properties.entity_name]
        local required_power = requested * properties.computation_cost + idle_power

        -- if energy is insufficient, entity is turned off
        if current_energy > required_power then
            entity.power_usage = required_power
        else
            TCCManager.decrease_computation_max_available(comp_limit)
            properties.operational = false
            entity.power_usage = idle_power
            properties.status = Utilities.entity_status.not_enough_power
        end
    end
    return Utilities.registry_sections.active
end

return ComputationArray