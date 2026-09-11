--[[
Template access interface (TAE) is a building required for template routing.
It's used to make templates (stored in template control center) accessible
to clusters. To make a given template accessible to given cluster two
TAEs are required: one in proximity to TCC in "transmit" mode, another
in "receive" mode connects to cluster. When both buildings are powered
(and there are no problems with TCC), template appears accessible to cluster.
-------------------------------------------------------------------------------
-- ENTITY INITIALIZATION
-------------------------------------------------------------------------------
Initialization requirements for this building:
I. Mandatory entity configuration is provided:
    1. first_cluster. Used to determine the cluster entity will work with
    2. selected_template. Used to determine the template entity will work with
    3. io_mode ("output" = transmit, "input" = receive). Determines operation
II. Selected template must exist and entity can work with it (complexity)
III. In transmit mode entity must be located on surface allowed for tcc.
IV. Selected cluster must exist and entity can be connected in receive mode.

Properties assigned on initialization:
1. status. Used to display entity status in the gui
2. is_output. Determines entity operation
3. surface_index. Used to make calls to tcc-manager
4. pos_x. Used to make calls to tcc-manager
5. pos_y. Used to make calls to tcc-manager
-------------------------------------------------------------------------------
-- ON-TICK UPDATES
-------------------------------------------------------------------------------
Properties that can be assigned during on-tick updates:
1. operational. True if entity is working (transmitting/receiving)

Entity starts in "not operational" state. If entity has enough energy for
operation and is close enough to TCC (transmit mode), it's switched to
"operational" state. When there is not enough energy, or entity is out of
TCC range (transmit mode), it's switched to "not operational" state.
--]]

local ClusterProcessor = require("scripts.simulation.cluster-processor")
local Utilities = require("scripts.world.e-processor-modules.utilities")
local TCCManager = require("scripts.simulation.tcc-manager")


local PREFIX = "FV-"
local TemplateAccess = {}

---List of all copyable properties of this entity
---@type EntityConfigField[]
TemplateAccess.configuration = {
    "first_cluster",
    "selected_template",
    "io_mode",
}

---Maps entity names to their weights inside clusters
local weights = {
    [PREFIX .. "template-access-interface-mk1"] = 0.001,
    [PREFIX .. "template-access-interface-mk2"] = 0.01,
    [PREFIX .. "template-access-interface-mk3"] = 0.1,
}

---Maps entity name to their max template drain stat
local entity_max_drain = {
    [PREFIX .. "template-access-interface-mk1"] = 5e8,
    [PREFIX .. "template-access-interface-mk2"] = 5e9,
    [PREFIX .. "template-access-interface-mk3"] = 5e10,
}

---Attemps entity initialization: checks that all requirments are met.
---If they are, prepares entity properties for on-tick processing.
---@param properties EntityProperties table from entity processor
---@return EntityRegistrySection
function TemplateAccess.initialize(properties)
    -- I. Checking that cluster is selected
    local cluster_uuid = properties.first_cluster
    if not cluster_uuid then
        properties.status = Utilities.entity_status.no_primary_cluster
        return Utilities.registry_sections.incorrect
    end
    -- I. Checking that template is selected
    local template_uuid = properties.selected_template
    if not template_uuid then
        properties.status = Utilities.entity_status.no_selected_template
        return Utilities.registry_sections.incorrect
    end
    -- I. Checking that io mode is selected
    local io_mode = properties.io_mode
    if not io_mode then
        properties.status = Utilities.entity_status.no_transmission_mode
        return Utilities.registry_sections.incorrect
    end
    -- II. Checking that selected template exists
    if not TCCManager.does_template_exist(template_uuid) then
        properties.status = Utilities.entity_status.template_not_found
        return Utilities.registry_sections.incorrect
    end
    -- II. Checking that template complexity is not too high
    local entity = properties.entity
    local max_drain_base = entity_max_drain[properties.entity_name]
    local quality_mult = 1 + 0.2 * entity.quality.level
    local max_drain = max_drain_base * quality_mult
    local drain = TCCManager.get_template_energy_drain(template_uuid)
    if drain > max_drain then
        properties.status = Utilities.entity_status.template_too_complex
        return Utilities.registry_sections.incorrect
    end
    -- III. Checking that surface is allowed for TCC (transmit mode)
    local is_transmit = (io_mode == "output")
    local allowed_surface = TCCManager.get_allowed_surface()
    if is_transmit and allowed_surface ~= entity.surface.name then
        properties.status = Utilities.entity_status.transmit_surface_mismatch
        return Utilities.registry_sections.incorrect
    end
    -- IV. Checking that cluster exists
    if not ClusterProcessor.does_cluster_exist(cluster_uuid) then
        properties.status = Utilities.entity_status.cluster_not_found
        return Utilities.registry_sections.incorrect
    end
    -- IV. Attempting to connect entity in receive mode
    if not is_transmit then
        local status = ClusterProcessor.add_member_to_cluster(
            entity,
            cluster_uuid,
            weights[properties.entity_name]
        )
        if not status then
            properties.status = Utilities.entity_status.cluster_cant_connect
            return Utilities.registry_sections.incorrect
        end
    end

    -- All requirements are met: preparing properties for on-tick updates
    properties.status = Utilities.entity_status.initialized
    properties.is_output = is_transmit
    properties.surface_index = entity.surface_index
    local position = entity.position
    properties.pos_x = position.x
    properties.pos_y = position.y
    return Utilities.registry_sections.active
end

---Switches entity in transmission mode to not operational state
---@param properties EntityProperties
local function switch_transmitter_not_operational(properties)
    if not properties.operational then return end
    TCCManager.remove_template_transmitter(properties.first_cluster)
    properties.operational = false
end

---Switches entity in receiving mode to not operational state
---@param properties EntityProperties
local function switch_receiver_not_operational(properties)
    if not properties.operational then return end
    ClusterProcessor.mark_member_not_operational(
        properties.first_cluster,
        properties.unit_number
    )
    TCCManager.remove_template_receiver(properties.first_cluster)
    properties.operational = false
end

---Clears properties of anything assigned on initialization or during on-tick
---updates. Intended use case: by entity processor when moving properties
---from "active" or "stalled" to "pending" or "incorrect". Does not clear
---"status" field from properties.
---@param properties EntityProperties
function TemplateAccess.uninitialize(properties)
    if properties.is_output then
        switch_transmitter_not_operational(properties)
    else
        switch_receiver_not_operational(properties)
        ClusterProcessor.remove_member_from_cluster(
            properties.first_cluster,
            properties.unit_number
        )
    end
    properties.is_output = nil
    properties.surface_index = nil
    properties.pos_x = nil
    properties.pos_y = nil
    properties.operational = nil
end

---On-tick updater for entity in transmission mode
---@param properties EntityProperties
---@return EntityRegistrySection
local function transmitter_update(properties)
    -- Checking TCC proximity
    local in_proximity = TCCManager.in_proximity_to_tcc(
        properties.surface_index,
        properties.pos_x,
        properties.pos_y
    )
    if not in_proximity then
        -- there is no TCC in proximity: setting entity to not operational
        switch_transmitter_not_operational(properties)
        properties.status = Utilities.entity_status.no_tcc_in_proximity
        return Utilities.registry_sections.stalled
    end

    -- Checking cluster existance
    ---@type string checked on initialization
    local cluster_uuid = properties.first_cluster
    if not ClusterProcessor.does_cluster_exist(cluster_uuid) then
        -- cluster does not exist: setting entity to not operational
        switch_transmitter_not_operational(properties)
        properties.status = Utilities.entity_status.cluster_deleted
        return Utilities.registry_sections.incorrect
    end

    -- Checking template existance
    ---@type string checked on initialization
    local template_uuid = properties.selected_template
    if not TCCManager.does_template_exist(template_uuid) then
        -- template does not exist: setting entity to not operational
        switch_transmitter_not_operational(properties)
        properties.status = Utilities.entity_status.template_deleted
        return Utilities.registry_sections.incorrect
    end

    -- Everything ok: normal operation
    local entity = properties.entity
    local power_usage = entity.power_usage
    local current_energy = entity.energy
    if current_energy > power_usage then
        -- there is enough energy: setting entity operational
        if not properties.operational then
            local status = TCCManager.add_template_transmitter(
                template_uuid,
                cluster_uuid
            )
            properties.operational = status
            -- cannot transmit: another template is already being transmitted
            if not status then
                properties.status = Utilities.entity_status.transmission_conflict
                return Utilities.registry_sections.stalled
            end
            properties.status = Utilities.entity_status.operational
        end
    else
        -- there is not enough energy: setting entity not operational
        switch_transmitter_not_operational(properties)
        properties.status = Utilities.entity_status.not_enough_power
    end
    return Utilities.registry_sections.active
end

---On-tick updater for entity in receiving mode
---@param properties EntityProperties
---@return EntityRegistrySection
local function receiver_update(properties)
    -- Checking TCC proximity for transmit mode
    if properties.is_output then
        local in_proximity = TCCManager.in_proximity_to_tcc(
            properties.surface_index,
            properties.pos_x,
            properties.pos_y
        )
        if not in_proximity then
            -- there is no TCC in proximity: setting entity to not operational
            switch_receiver_not_operational(properties)
            properties.status = Utilities.entity_status.no_tcc_in_proximity
            return Utilities.registry_sections.stalled
        end
    end

    -- Checking cluster existance
    ---@type string checked on initialization
    local cluster_uuid = properties.first_cluster
    if not ClusterProcessor.does_cluster_exist(cluster_uuid) then
        -- cluster does not exist: setting entity to not operational
        switch_receiver_not_operational(properties)
        properties.status = Utilities.entity_status.cluster_deleted
        return Utilities.registry_sections.incorrect
    end

    -- Checking template existance
    ---@type string checked on initialization
    local template_uuid = properties.selected_template
    if not TCCManager.does_template_exist(template_uuid) then
        -- template does not exist: setting entity to not operational
        switch_receiver_not_operational(properties)
        properties.status = Utilities.entity_status.template_deleted
        return Utilities.registry_sections.incorrect
    end

    -- Everything ok: normal operation
    local entity = properties.entity
    local power_usage = entity.power_usage
    local current_energy = entity.energy
    if current_energy > power_usage then
        -- there is enough energy: setting entity operational
        if not properties.operational then
            local status = TCCManager.add_template_receiver(
                template_uuid,
                cluster_uuid
            )
            properties.operational = status
            if not status then
                -- cannot receive: another template is already being received
                properties.status = Utilities.entity_status.reception_conflict
                return Utilities.registry_sections.stalled
            end
            -- can receive: marking it operational in cluster
            ClusterProcessor.mark_member_operational(
                cluster_uuid,
                properties.unit_number
            )
            properties.status = Utilities.entity_status.operational
        end
    else
        -- there is not enough energy: setting entity not operational
        switch_receiver_not_operational(properties)
        properties.status = Utilities.entity_status.not_enough_power
    end
    return Utilities.registry_sections.active
end

---Used for on-tick updates of this entity after initialization.
---@param properties EntityProperties
---@return EntityRegistrySection
function TemplateAccess.update(properties)
    if properties.is_output then
        return transmitter_update(properties)
    else
        return receiver_update(properties)
    end
end

return TemplateAccess