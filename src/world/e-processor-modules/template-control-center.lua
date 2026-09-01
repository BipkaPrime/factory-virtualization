--[[
Template control center is vital for operation of template system.
It serves the purpose of cental hub, does nothing on its own, however
no templates can be used or compiled without working template control center.
Consumes electric energy, if there is not enough, building shuts down.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Entity is located on allowed surface. Currently any surface named "aquilo"
    with space-age mod, or "nauvis" without.

Properties that are assigned on initialization:
1. status. Used to display entity status in the gui
2. capacity. Used to store tcc proximity stat
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick processing:
1. operational. True if entity is registered in tcc-manager

Entity is considered operational when:
1. It is registered as template control center.
2. Has enough electric energy stored.
--]]

local TCCManager = require("src.simulation.tcc-manager")
local Utilities = require("src.world.e-processor-modules.utilities")


local PREFIX = "FV-"
local TemplateCC = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
TemplateCC.configuration = {}

---Maps entity name to their proximity stat
local proximity = {
    [PREFIX .. "template-control-center-mk1"] = 256,
    [PREFIX .. "template-control-center-mk2"] = 512,
    [PREFIX .. "template-control-center-mk3"] = 1024,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function TemplateCC.initialize(properties)
    -- Checking that surface is allowed for operation of tcc
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
    local proximity_base = proximity[properties.entity_name]
    local quality_mult = 1 + 0.5 * entity.quality.level
    properties.capacity = proximity_base * quality_mult
    return Utilities.registry_sections.active
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function TemplateCC.uninitialize(properties)
    if properties.operational then
        TCCManager.unregister_control_center(properties.unit_number)
    end
    properties.capacity = nil
    properties.surface_index = nil
    properties.pos_x = nil
    properties.pos_y = nil
    properties.operational = nil
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function TemplateCC.update(properties)
    local entity = properties.entity
    local power_usage = entity.power_usage
    local current_energy = entity.energy
    if current_energy > power_usage then
        -- there is enough energy: entity is operational
        if not properties.operational then
            -- attempting to register this control center
            local status = TCCManager.register_control_center(
                entity,
                properties.capacity
            )
            properties.operational = status
            if status then
                -- successfully registered
                properties.status = Utilities.entity_status.operational
            else
                -- registration failed (another tcc is registered)
                properties.status = Utilities.entity_status.tcc_reg_failed
                return Utilities.registry_sections.stalled
            end
        end
    else
        -- there is not enough energy: entity is not operational
        if properties.operational then
            TCCManager.unregister_control_center(
                properties.unit_number
            )
            properties.operational = false
            properties.status = Utilities.entity_status.not_enough_power
        end
    end
    return Utilities.registry_sections.active
end

return TemplateCC