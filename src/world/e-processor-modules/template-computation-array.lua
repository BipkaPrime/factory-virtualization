--[[
Template computation array is required to produce "computation" resource,
which is needed for template compilation. Computation is a flow variable,
meaning that it cannot be stored and is provided as long as the building is 
powered and running. If energy stored in the entity is not sufficient,
it stops working until enough energy is provided.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Entity is located on allowed surface. Currently any surface named "aquilo"
    with space-age mod, or "nauvis" without.

Optional entity controls this building can have:
1. capability_override. Used to artificially lower flow limit of this entity.

Properties that are assigned on initialization:
1. flow_limit. maximum amount of computation this entity can provide
2. computation_cost. entity power usage for one unit of provided computation
3. startup_energy. amount of energy required to "activate" the entity.
4. surface_index. Used to make calls to tcc-manager.
5. pos_x. Used to make calls to tcc-manager.
6. pos_y. Used to make calls to tcc-manager.
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick processing:
1. operational. Used as an indication that entity is contributing
computation potential.
2. ls_flow. Used to track computation this entity is currently producing.

Entity is considered operational when:
1. Template control center is in close proximity to it.
2. Entity has enough electric energy stored.
--]]

local TCCManager = require("src.simulation.tcc-manager")
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
    -- Checking that surface is allowed for operation of entity
    local entity = properties.entity
    local surface_name = entity.surface.name
    local allowed_surface = TCCManager.get_allowed_surface()
    if allowed_surface ~= surface_name then
        local status = {"entity-status.works-only-on", allowed_surface}
        properties.status = status
        return Utilities.registry_sections.incorrect
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    local entity_name = properties.entity_name
    local base_flow = computation_limits[entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    local override = properties.capability_override or 1
    local comp_limit = base_flow * quality_mult * override
    properties.flow_limit = comp_limit
    local comp_cost = computation_costs[entity_name] / quality_mult
    properties.computation_cost = comp_cost
    local idle_power = idle_power_consumption[entity_name]
    -- energy required for one second of operation at maximum load
    properties.startup_energy = 60 * (comp_limit * comp_cost + idle_power)
    -- when pasting computation array from blueprint, energy usage is pasted as well
    entity.power_usage = idle_power
    properties.surface_index = entity.surface_index
    local position = entity.position
    properties.pos_x = position.x
    properties.pos_y = position.y
    return Utilities.registry_sections.active
end

---Switches entity to not operational state
---@param properties EntityProperties
local function switch_to_not_operational(properties)
    if not properties.operational then return end
    TCCManager.decrease_computation_max_available(properties.flow_limit)
    properties.operational = false
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function ComputationArray.uninitialize(properties)
    switch_to_not_operational(properties)
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

    -- Checking TCC proximity
    local in_proximity = TCCManager.in_proximity_to_tcc(
        properties.surface_index,
        properties.pos_x,
        properties.pos_y
    )
    if not in_proximity then
        -- there is no TCC in proximity: setting entity to not operational
        switch_to_not_operational(properties)
        properties.status = Utilities.entity_status.no_tcc_in_proximity
        return Utilities.registry_sections.stalled
    end

    -- TCC found in proximity: attempting to turn on the entity
    local entity = properties.entity
    local current_energy = entity.energy
    ---@type number assigned on initialization
    local comp_limit = properties.flow_limit
    if not properties.operational and current_energy >= properties.startup_energy then
        TCCManager.increase_computation_max_available(comp_limit)
        properties.operational = true
        properties.status = Utilities.entity_status.operational
    end

    -- Everything ok: normal operation
    if properties.operational then
        -- getting amount of computation expected from this entity
        local demand_ratio = TCCManager.get_computation_demand_ratio()
        local requested = comp_limit * demand_ratio
        properties.ls_flow = requested
        -- calculating target power consumption according to requested computation
        local idle_power = idle_power_consumption[properties.entity_name]
        local required_power = requested * properties.computation_cost + idle_power
        if current_energy > required_power then
            -- there is enough energy: working
            entity.power_usage = required_power
        else
            -- there is not enough energy: setting entity not operational
            switch_to_not_operational(properties)
            entity.power_usage = idle_power
            properties.status = Utilities.entity_status.not_enough_power
        end
    end
    return Utilities.registry_sections.active
end

return ComputationArray