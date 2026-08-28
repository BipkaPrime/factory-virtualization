local Utilities = {}


---Contains localised strings used to display entity status
---@enum entity_status
Utilities.entity_status = {
    -- Initialization errors: missing values
    no_primary_cluster = {"entity-status.no-primary-cluster"},
    no_io_mode = {"entity-status.no-io-mode"},
    no_selected_item = {"entity-status.no-selected-item"},
    no_selected_fluid = {"entity-status.no-selected-fluid"},
    no_operation_mode = {"entity-status.no-operation-mode"},
    no_overflow_threshold = {"entity-status.no-overflow-threshold"},
    no_selected_template = {"entity-status.no-selected-template"},
    no_transmission_mode = {"entity-status.no-transmission-mode"},
    no_s_cluster = {"entity-status.no-s-cluster"},
    no_d_cluster = {"entity-status.no-d-cluster"},
    -- Initialization errors: other errors
    template_not_found = {"entity-status.template-not-found"},
    cluster_not_found = {"entity-status.cluster-not-found"},
    s_cluster_not_found = {"entity-status.s-cluster-not-found"},
    d_cluster_not_found = {"entity-status.d-cluster-not-found"},
    cluster_cant_connect = {"entity-status.cluster-cant-connect"},
    s_cluster_cant_connect = {"entity-status.s-cluster-cant-connect"},
    d_cluster_cant_connect = {"entity-status.d-cluster-cant-connect"},
    vsurface_no_work = {"entity-status.vsurface-no-work"},
    vsurface_only_work = {"entity-status.vsurface-only-work"},
    transmit_surface_mismatch = {"entity-status.transmit-surface-mismatch"},
    works_only_on = {"entity-status.works-only-on"},
    -- Update warnings/errors
    not_enough_power = {"entity-status.not-enough-power"},
    entry_not_found = {"entity-status.entry-not-found"},
    s_entry_not_found = {"entity-status.s-entry-not-found"},
    d_entry_not_found = {"entity-status.d-entry-not-found"},
    no_tcc_in_proximity = {"entity-status.no-tcc-in-proximity"},
    transmission_conflict = {"entity-status.transmission-conflict"},
    reception_conflict = {"entity-status.reception-conflict"},
    no_assigned_template = {"entity-status.no-assigned-template"},
    cluster_deleted = {"entity-status.cluster-deleted"},
    s_cluster_deleted = {"entity-status.s-cluster-deleted"},
    d_cluster_deleted = {"entity-status.d-cluster-deleted"},
    tcc_reg_failed = {"entity-status.tcc-reg-failed"},
    template_deleted = {"entity-status.template-deleted"},
    -- Normal operation
    initialized = {"entity-status.initialized"},
    operational = {"entity-status.operational"},
}

---Contains names of all sections in entity registry
---@enum
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