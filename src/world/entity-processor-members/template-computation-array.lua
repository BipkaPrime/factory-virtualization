--[[
Template computation array is required for template compulation.
It produces "computation", which is a flow variable, meaning that
computation can not be stored and is provided as long as the building is 
powered and running. If energy stored in the entity is not sufficient,
it stops working until enough energy is provided.
-------------------------------------------------------------------------------
-- ON-TICK PROCESSING
-------------------------------------------------------------------------------
Properties that are assigned on initialization:
1. Computation limit: number, maximum amount of computation this entity can provide
2. Computation cost: number, energy cost of one unit of provided computation
3. Startup energy: number, amount of energy required to "activate" the entity.

Properties that can be assigned during on-tick processing:
1. Operational. Used as an indication that entity is contributing computation potential
2. Ls flow. Used to track how much computation this entity is currently producing.
--]]

local ComputationManager = require("src.simulation.computation-manager")


local PREFIX = "FV-"
local ComputationArray = {}

---This building has no "configuration"
ComputationArray.copyable = {}

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

---Checks that all requirements for operation of template computation array are met.
---Currently there are no requirements, initialization will always be successful.
---@param properties EntityProperties table from entity processor
---@return boolean status true if initialization was successful
function ComputationArray.attempt_entity_initialization(properties)
    -- TODO: add vsurface check

    local entity_name = properties.entity_name
    local computation_limit = computation_limits[entity_name]
    properties.computation_limit = computation_limit
    local computation_cost = computation_costs[entity_name]
    properties.computation_cost = computation_cost
    local idle_power = idle_power_consumption[entity_name]
    -- energy required for one second of operation at maximum load
    properties.startup_energy = 60 * (computation_limit * computation_cost + idle_power)
    -- when pasting computation array from blueprint, energy usage is pasted as well
    properties.entity.power_usage = idle_power
    return true
end

---Clears properties of anything assigned on initialization or during on-tick processing.
---Should be called when stopping on-tick processing of entity to clear fields that were
---assigned on initialization or during on-tick processing
---@param properties EntityProperties table from entity processor
function ComputationArray.on_processing_stopped(properties)
    properties.ls_flow = nil
    if properties.operational then
        ComputationManager.decrease_potential(
            properties.computation_limit
        )
    end
    properties.operational = nil
    properties.computation_limit = nil
    properties.computation_cost = nil
    properties.startup_energy = nil
end

---Used for on-tick processing of template computation arrays.
---@param properties EntityProperties
function ComputationArray.process_entity(properties)
    local entity = properties.entity
    local current_energy = entity.energy

    -- trying to turn on the entity if possible
    if not properties.operational then
        local startup_power = properties.startup_energy
        if current_energy >= startup_power then
            ComputationManager.increase_potential(
                properties.computation_limit
            )
            properties.operational = true
        else
            properties.ls_flow = 0
        end
    end

    -- handling entity being operational
    if properties.operational then
        -- getting amount of computation expected from this entity
        local demand = ComputationManager.get_demand_ratio()
        local requested = properties.computation_limit * demand
        properties.ls_flow = requested

        -- changing power consumption according to requested computation
        local idle_power = idle_power_consumption[properties.entity_name]
        local required_power = requested * properties.computation_cost + idle_power

        -- if energy is insufficient, entity is turned off
        if current_energy > required_power then
            entity.power_usage = required_power
        else
            ComputationManager.decrease_potential(
                properties.computation_limit
            )
            properties.operational = false
            entity.power_usage = idle_power
        end
    end
end

return ComputationArray