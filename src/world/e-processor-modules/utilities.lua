local Utilities = {}


---Contains localised strings used to display entity status
Utilities.entity_status = {
    no_primary_cluster = {"entity-status.cluster-not-selected"},
    no_io_mode_primary = {"entity-status.no-io-mode-primary"},
    no_selected_item = {"entity-status.no-selected-item"},
    vsurface_no_work = {"entity-status.vsurface-no-work"},
    cluster_not_found = {"entity-status.cluster-not-found"},
    initialized = {"entity-status.initialized"},
    entry_not_found = {"entity-status.entry-not-found"},
    operational = {"entity-status.operational"},
    cluster_deleted = {"entity-status.cluster-deleted"},
    no_selected_fluid = {"entity-status.no-selected-fluid"},
    no_operation_mode = {"entity-status.no-operation-mode"},
    no_overflow_threshold = {"entity-status.no-overflow-threshold"},
    not_enough_power = {"entity-status.not-enough-power"},
    no_source_cluster = {"entity-status.no-source-cluster"},
    no_destination_cluster = {"entity-status.no-destination-cluster"},
    s_cluster_not_found = {"entity-status.s-cluster-not-found"},
    d_cluster_not_found = {"entity-status.d-cluster-not-found"},
    vsurface_only_work = {"entity-status.vsurface-only-work"},
}

---Contains names of all sections in entity registry
---@type table<EntityRegistrySection, EntityRegistrySection>
Utilities.registry_sections = {
    active = "active",
    stalled = "stalled",
    pending = "pending",
    incorrect = "incorrect"
}

---Creates a buffer key for multi-mode entities. Assumes that provided
---configuration is correct. Operation mode is selected, selected item
---is present for "item" mode, selected fluid is present for "fluid" mode.
---@param properties EntityProperties
---@return BufferKeyString
function Utilities.generate_multimode_buffer_key(properties)
    local operation_mode = properties.operation_mode
    if operation_mode == "item" then
        local name = properties.selected_item_name
        local quality = properties.selected_item_quality
        return name .. "//" .. quality
    end
    if operation_mode == "fluid" then
        return properties.selected_fluid
    end
    return "electric_energy"
end

return Utilities