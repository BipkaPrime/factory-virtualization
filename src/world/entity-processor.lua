--[[
This mod introduces several entities that must have data associated with them in storage,
they also need to be tracked and updated once in a while. This file is used for that.
Entity registry is located at storage.entity_registry and consists of 2 parts:
storage.entity_registry = {
    array = {},
    lookup = {},
}
Array is 1-indexed and contains data of all entities in the registry.
Lookup maps unit_number of an entity to index in the array containing corresponding
entity data. Entity data from this registry is also called entity properties.
Only alive entities (not ghosts) can have properties in entity registry.
However, entity processor provides functionality to manipulate entity tags 
for ghosts, where entity properties are stored before entity is built.
When entity is constructed/revived, ghost tags migrate to entity regstry.
--]]


---@alias ItemKeyString string name//quality
---@alias FluidKeyString string fluid_name
---@alias EnergyKeyString "electric_energy"
---Serves as key in tables where items, fluids and energy are stored together
---@alias BufferKeyString ItemKeyString|FluidKeyString|EnergyKeyString

--- Table describing one item stack
---@class ItemBuffer
---@field count number number of items contained
---@field quality string quality of this item
---@field name string name of this item

---Table describing selected item
---@class ItemSelection
---@field name string prototype name of selected item
---@field quality string prototype name of selected quality
---@field count number|nil technical field (to use table as an arg in inventory.insert)

---Table describing selected fluid
---@class FluidSelection
---@field name string name of selected fluid
---@field amount number|nil technical field (to use table as an arg in entity.insert_fluid)

---Abstract class for entity data in processor
---@class EntityPropertiesBase
---@field entity LuaEntity
---@field unit_number number unique entity identifier
---@field name string name of entity
---@field on_vsurface boolean true if entity is located on a vsurface

---Abstract entity that supports item selection
---@class EntityWithItemSelection: EntityPropertiesBase
---@field selected_item ItemSelection|nil table describing selected item
---@field buffer_key ItemKeyString|nil "name//quality"

---Abstract entity that supports fluid selection
---@class EntityWithFluidSelection: EntityPropertiesBase
---@field selected_fluid FluidSelection|nil table describing selected fluid

---Abstract entity that can be an input or an output
---@class EntityWithIOSelection: EntityPropertiesBase
---@field is_output boolean|nil true if entity is an output

---Abstract entity that has chest inventory
---@class EntityWithChestInventory: EntityPropertiesBase
---@field inventory LuaInventory cached on registration

---Abstract entity that can be a member of cluster
---@class SimpleClusterMember: EntityPropertiesBase
---@field selected_template string|nil name of selected template (user input)
---@field cluster table|nil reference to virtualization cluster that includes this entity

---Abstract entity that has item/fluid/energy mode selection
---@class EntityWithModeSelection: EntityWithFluidSelection
---@class EntityWithModeSelection: EntityWithItemSelection
---@field mode "item"|"fluid"|"energy"|nil

---Abstract entity that can connect to 2 clusters
---@class InterClusterEntity: EntityPropertiesBase
---@field source_template string|nil 
---@field destination_template string|nil
---@field source_cluster ClusterData|nil
---@field destination_cluster ClusterData|nil

---Cluster item IO properties
---@class ClusterItemIOProperties: SimpleClusterMember
---@class ClusterItemIOProperties: EntityWithItemSelection
---@class ClusterItemIOProperties: EntityWithIOSelection
---@class ClusterItemIOProperties: EntityWithChestInventory
---@field ls_flow number|nil amount transfered in the last second

---Cluster fluid IO properties
---@class ClusterFluidIOProperties: SimpleClusterMember
---@class ClusterFluidIOProperties: EntityWithFluidSelection
---@class ClusterFluidIOProperties: EntityWithIOSelection
---@field ls_flow number|nil amount transfered in the last second

---Cluster energy IO properties
---@class ClusterEnergyIOProperties: SimpleClusterMember
---@class ClusterEnergyIOProperties: EntityWithIOSelection
---@field ls_flow number|nil amount transfered in the last second

---Template item IO properties
---@class TemplateItemIOProperties: EntityWithItemSelection
---@class TemplateItemIOProperties: EntityWithIOSelection
---@class TemplateItemIOProperties: EntityWithChestInventory
---@field ls_flow number|nil amount transfered in the last second

---Template fluid IO properties
---@class TemplateFluidIOProperties: EntityWithFluidSelection
---@class TemplateFluidIOProperties: EntityWithIOSelection
---@field ls_flow number|nil amount transfered in the last second

---Template energy IO properties
---@class TemplateEnergyIOProperties: EntityWithIOSelection
---@field ls_flow number|nil amount transfered in the last second

---Table with properties of virtualization mainframe
---@class MainframeProperties: SimpleClusterMember
---@field operational boolean|nil true if mainframe has constructed a template and can operate
---@field building_requests table<ItemKeyString, ItemBuffer>|nil items that are being requested for template construction
---@field contained_buildings table<ItemKeyString, ItemBuffer>|nil items that were used for template construction

---Table with properties of inter-cluster bridge
---@class InterClusterBridgeProperties: EntityWithModeSelection
---@class InterClusterBridgeProperties: InterClusterEntity
---@field ls_flow number|nil amount transfered in the last second

---Union of all instances of entity properties
---@alias EntityProperties
---|ClusterItemIOProperties
---|ClusterFluidIOProperties
---|ClusterEnergyIOProperties
---|TemplateItemIOProperties
---|TemplateFluidIOProperties
---|TemplateEnergyIOProperties
---|MainframeProperties
---|InterClusterBridgeProperties

local VSurfaceManager = require("src.world.vsurface-manager")
local ClusterProcessor = require("src.simulation.cluster-processor")
local MainframeManager = require("src.world.mainframe-manager")
local ClusterIO = require("src.world.cluster-io-manager")
local TemplateIO = require("src.world.template-io-manager")
local ClusterBridge = require("src.world.cluster-bridge-manager")

local PREFIX = "FV-"
local ENTITY_TAG_KEY = PREFIX
local EntityProcessor = {}

---Mapping of entity names recognized by this registry to their on-tick handlers
local entity_router = {
    [PREFIX .. "template-item-io-mk1"] = TemplateIO.process_template_item_io,
    [PREFIX .. "template-item-io-mk2"] = TemplateIO.process_template_item_io,
    [PREFIX .. "template-item-io-mk3"] = TemplateIO.process_template_item_io,
    [PREFIX .. "template-fluid-io-mk1"] = TemplateIO.process_template_fluid_io,
    [PREFIX .. "template-fluid-io-mk2"] = TemplateIO.process_template_fluid_io,
    [PREFIX .. "template-fluid-io-mk3"] = TemplateIO.process_template_fluid_io,
    [PREFIX .. "template-energy-io-mk1"] = TemplateIO.process_template_energy_io,
    [PREFIX .. "template-energy-io-mk2"] = TemplateIO.process_template_energy_io,
    [PREFIX .. "template-energy-io-mk3"] = TemplateIO.process_template_energy_io,
    [PREFIX .. "cluster-item-io-mk1"] = ClusterIO.process_cluster_item_io,
    [PREFIX .. "cluster-item-io-mk2"] = ClusterIO.process_cluster_item_io,
    [PREFIX .. "cluster-item-io-mk3"] = ClusterIO.process_cluster_item_io,
    [PREFIX .. "cluster-fluid-io-mk1"] = ClusterIO.process_cluster_fluid_io,
    [PREFIX .. "cluster-fluid-io-mk2"] = ClusterIO.process_cluster_fluid_io,
    [PREFIX .. "cluster-fluid-io-mk3"] = ClusterIO.process_cluster_fluid_io,
    [PREFIX .. "cluster-energy-io-mk1"] = ClusterIO.process_cluster_energy_io,
    [PREFIX .. "cluster-energy-io-mk2"] = ClusterIO.process_cluster_energy_io,
    [PREFIX .. "cluster-energy-io-mk3"] = ClusterIO.process_cluster_energy_io,
    [PREFIX .. "virtualization-mainframe-mk1"] = MainframeManager.process_vm,
    [PREFIX .. "virtualization-mainframe-mk2"] = MainframeManager.process_vm,
    [PREFIX .. "virtualization-mainframe-mk3"] = MainframeManager.process_vm,
    [PREFIX .. "inter-cluster-bridge-mk1"] = ClusterBridge.process_bridge,
    [PREFIX .. "inter-cluster-bridge-mk2"] = ClusterBridge.process_bridge,
    [PREFIX .. "inter-cluster-bridge-mk3"] = ClusterBridge.process_bridge,
}

---Filter used to subscribe to build events
EntityProcessor.build_filter = {}
for name, _ in pairs(entity_router) do
    table.insert(EntityProcessor.build_filter, {filter = "name", name = name})
end

---Copyable fields of template item io
local template_item_io_copyable = {
    "selected_item",
    "is_output",
}

---Copyable fields of template fluid io
local template_fluid_io_copyable = {
    "selected_fluid",
    "is_output",
}

---Copyable fields of template energy io
local template_energy_io_copyable = {
    "is_output",
}

---Copyable fields of cluster item io
local cluster_item_io_copyable = {
    "selected_template",
    "selected_item",
    "is_output",
}

---Copyable fields of cluster fluid io
local cluster_fluid_io_copyable = {
    "selected_template",
    "selected_fluid",
    "is_output",
}

---Copyable fields of cluster energy io
local cluster_energy_io_copyable = {
    "selected_template",
    "is_output",
}

---Copyable fields of virtualization mainframe
local virtualization_mainframe_copyable = {
    "selected_template",
}

---Copyable fields of inter-cluster bridge
local inter_cluster_bridge_copyable = {
    "selected_item",
    "selected_fluid",
    "source_template",
    "destination_template",
    "mode",
}

---Maps entity names to their copyable properties
local entity_copyable_fields = {
    [PREFIX .. "template-item-io-mk1"] = template_item_io_copyable,
    [PREFIX .. "template-item-io-mk2"] = template_item_io_copyable,
    [PREFIX .. "template-item-io-mk3"] = template_item_io_copyable,
    [PREFIX .. "template-fluid-io-mk1"] = template_fluid_io_copyable,
    [PREFIX .. "template-fluid-io-mk2"] = template_fluid_io_copyable,
    [PREFIX .. "template-fluid-io-mk3"] = template_fluid_io_copyable,
    [PREFIX .. "template-energy-io-mk1"] = template_energy_io_copyable,
    [PREFIX .. "template-energy-io-mk2"] = template_energy_io_copyable,
    [PREFIX .. "template-energy-io-mk3"] = template_energy_io_copyable,
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk1"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk2"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-fluid-io-mk3"] = cluster_fluid_io_copyable,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_energy_io_copyable,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_energy_io_copyable,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_energy_io_copyable,
    [PREFIX .. "virtualization-mainframe-mk1"] = virtualization_mainframe_copyable,
    [PREFIX .. "virtualization-mainframe-mk2"] = virtualization_mainframe_copyable,
    [PREFIX .. "virtualization-mainframe-mk3"] = virtualization_mainframe_copyable,
    [PREFIX .. "inter-cluster-bridge-mk1"] = inter_cluster_bridge_copyable,
    [PREFIX .. "inter-cluster-bridge-mk2"] = inter_cluster_bridge_copyable,
    [PREFIX .. "inter-cluster-bridge-mk3"] = inter_cluster_bridge_copyable,
}

-------------------------------------------------------------------------------
-- DATA MANIPULATION SIDE-EFFECTS (Internal hooks and caches)
-------------------------------------------------------------------------------

---Cahes LuaInventory of given entity to properties
---@param properties EntityWithChestInventory
local function cache_inventory_object(properties)
    local entity = properties.entity
    local inventory = entity.get_inventory(defines.inventory.chest)
    ---assuming that entity prototype has chest inventory
    ---@cast inventory LuaInventory
    properties.inventory = inventory
end

---Generates a buffer key for entity with mode selection based on operation mode
---@param properties EntityWithModeSelection
local function generate_universal_buffer_key(properties)
    local mode = properties.mode
    if mode == "item" then
        local item = properties.selected_item
        properties.buffer_key = item and (item.name .. "//" .. item.quality) or nil
    elseif mode == "fluid" then
        local fluid = properties.selected_fluid
        properties.buffer_key = fluid and fluid.name or nil
    else
        properties.buffer_key = "electric_energy"
    end
end

---Creates a buffer key for item IO.
---@param properties EntityWithItemSelection
local function generate_item_buffer_key(properties)
    local item = properties.selected_item
    properties.buffer_key = item and (item.name .. "//" .. item.quality) or nil
end

---Moves entity to new virtualization cluster
---@param properties SimpleClusterMember
local function move_to_new_cluster(properties)
    -- removing entity from old cluster
    local old_cluster = properties.cluster
    local unit_number = properties.unit_number
    ClusterProcessor.remove_from_cluster(old_cluster, unit_number)

    -- adding entity to its new cluster
    local entity = properties.entity
    local template_name = properties.selected_template
    local new_cluster = ClusterProcessor.add_to_cluster(entity, template_name)
    properties.cluster = new_cluster
end

---Function that ensures operation mode is not nil
---@param properties InterClusterBridgeProperties
local function initialize_operation_mode(properties)
    if not properties.mode then properties.mode = "item" end
end

---Removes entity from own cluster
---@param properties SimpleClusterMember
local function remove_from_own_cluster(properties)
    ClusterProcessor.remove_from_cluster(
        properties.cluster,
        properties.unit_number
    )
end

---Removes entity from both clusters it's associated with
---@param properties InterClusterEntity
local function remove_from_both_clusters(properties)
    ClusterProcessor.remove_from_cluster(
        properties.source_cluster,
        properties.unit_number
    )
    ClusterProcessor.remove_from_cluster(
        properties.destination_cluster,
        properties.unit_number
    )
end

-------------------------------------------------------------------------------
-- GENERAL REGISTRY OPERATIONS: ADD/DELETE/LOOKUP
-------------------------------------------------------------------------------

---List of functions to perform when registering template item io
local template_item_io_registration = {
    cache_inventory_object,
}

---List of functions to perform when registering cluster item io
local cluster_item_io_registration = {
    cache_inventory_object
}

---List of functions to perform when registering inter-cluster bridge
local inter_cluster_bridge_registration = {
    initialize_operation_mode
}

---Maps entity names to list of functions to perform on registration
local registration_hooks = {
    [PREFIX .. "template-item-io-mk1"] = template_item_io_registration,
    [PREFIX .. "template-item-io-mk2"] = template_item_io_registration,
    [PREFIX .. "template-item-io-mk3"] = template_item_io_registration,
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_registration,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_registration,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_registration,
    [PREFIX .. "inter-cluster-bridge-mk1"] = inter_cluster_bridge_registration,
    [PREFIX .. "inter-cluster-bridge-mk2"] = inter_cluster_bridge_registration,
    [PREFIX .. "inter-cluster-bridge-mk3"] = inter_cluster_bridge_registration,
}

---List of functions to perform when setting a field for template item io
local template_item_io_field_setting = {
    selected_item = {generate_item_buffer_key},
}

---List of functions to perform when setting a field for cluster item io
local cluster_item_io_field_setting = {
    selected_template = {move_to_new_cluster},
    selected_item = {generate_item_buffer_key},
}

---List of functions to perform when setting a field for cluster fluid io
local cluster_fluid_io_field_setting = {
    selected_template = {move_to_new_cluster},
}

---List of functions to perform when setting a field for cluster energy io
local cluster_energy_io_field_setting = {
    selected_template = {move_to_new_cluster},
}

---List of functions to perform when setting a field for virtualization mainframe
local virtualization_mainframe_field_setting = {
    selected_template = {
        move_to_new_cluster,
        MainframeManager.on_template_change,
    },
}

---List of functions to perform when setting a field for inter-cluster bridge
local inter_cluster_bridge_field_setting = {
    source_template = {ClusterBridge.change_source_cluster},
    destination_template = {ClusterBridge.change_destination_cluster},
    selected_item = {generate_universal_buffer_key},
    selected_fluid = {generate_universal_buffer_key},
    mode = {generate_universal_buffer_key},
}

---Maps entity names to functions to perform when setting a field in properties
local field_setting_hooks = {
    [PREFIX .. "template-item-io-mk1"] = template_item_io_field_setting,
    [PREFIX .. "template-item-io-mk2"] = template_item_io_field_setting,
    [PREFIX .. "template-item-io-mk3"] = template_item_io_field_setting,
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_field_setting,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_field_setting,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_field_setting,
    [PREFIX .. "cluster-fluid-io-mk1"] = cluster_fluid_io_field_setting,
    [PREFIX .. "cluster-fluid-io-mk2"] = cluster_fluid_io_field_setting,
    [PREFIX .. "cluster-fluid-io-mk3"] = cluster_fluid_io_field_setting,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_energy_io_field_setting,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_energy_io_field_setting,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_energy_io_field_setting,
    [PREFIX .. "virtualization-mainframe-mk1"] = virtualization_mainframe_field_setting,
    [PREFIX .. "virtualization-mainframe-mk2"] = virtualization_mainframe_field_setting,
    [PREFIX .. "virtualization-mainframe-mk3"] = virtualization_mainframe_field_setting,
    [PREFIX .. "inter-cluster-bridge-mk1"] = inter_cluster_bridge_field_setting,
    [PREFIX .. "inter-cluster-bridge-mk2"] = inter_cluster_bridge_field_setting,
    [PREFIX .. "inter-cluster-bridge-mk3"] = inter_cluster_bridge_field_setting,
}

---List of functions to perform when removing cluster item io from registry
local cluster_item_io_unregistration = {
    remove_from_own_cluster,
}

---List of functions to perform when removing cluster fluid io from registry
local cluster_fluid_io_unregistration = {
    remove_from_own_cluster,
}

---List of functions to perform when removing cluster energy io from registry
local cluster_energy_io_unregistration = {
    remove_from_own_cluster,
}

---List of functions to perform when removing virtualization mainframe from registry
local virtualization_mainframe_unregistration = {
    remove_from_own_cluster,
}

---List of functions to perform when removing inter-cluster bridge from registry
local inter_cluster_bridge_unregistration = {
    remove_from_both_clusters,
}

---Maps entity names to functions to perform when removing entity from registry
local unregistration_hooks = {
    [PREFIX .. "cluster-item-io-mk1"] = cluster_item_io_unregistration,
    [PREFIX .. "cluster-item-io-mk2"] = cluster_item_io_unregistration,
    [PREFIX .. "cluster-item-io-mk3"] = cluster_item_io_unregistration,
    [PREFIX .. "cluster-fluid-io-mk1"] = cluster_fluid_io_unregistration,
    [PREFIX .. "cluster-fluid-io-mk2"] = cluster_fluid_io_unregistration,
    [PREFIX .. "cluster-fluid-io-mk3"] = cluster_fluid_io_unregistration,
    [PREFIX .. "cluster-energy-io-mk1"] = cluster_energy_io_unregistration,
    [PREFIX .. "cluster-energy-io-mk2"] = cluster_energy_io_unregistration,
    [PREFIX .. "cluster-energy-io-mk3"] = cluster_energy_io_unregistration,
    [PREFIX .. "virtualization-mainframe-mk1"] = virtualization_mainframe_unregistration,
    [PREFIX .. "virtualization-mainframe-mk2"] = virtualization_mainframe_unregistration,
    [PREFIX .. "virtualization-mainframe-mk3"] = virtualization_mainframe_unregistration,
    [PREFIX .. "inter-cluster-bridge-mk1"] = inter_cluster_bridge_unregistration,
    [PREFIX .. "inter-cluster-bridge-mk2"] = inter_cluster_bridge_unregistration,
    [PREFIX .. "inter-cluster-bridge-mk3"] = inter_cluster_bridge_unregistration,
}

---Adds given entity to registry. Is called when any build event is triggered.
---@param entity LuaEntity
---@param tags table|nil build event tags
function EntityProcessor.register_entity(entity, tags)
    if not entity.valid then return end

    -- avoiding duplicates
    local reg = storage.entity_registry
    if reg.lookup[entity.unit_number] then return end

    -- mandatory entity properties
    local name = entity.name
    local on_vsurface = not not VSurfaceManager.get_vsurface_data(entity.surface_index)
    local properties = {
        entity = entity,
        unit_number = entity.unit_number,
        name = name,
        on_vsurface = on_vsurface,
    }

    -- adding event tags to properties
    if tags and tags[ENTITY_TAG_KEY] then
        local relevant_tags = tags[ENTITY_TAG_KEY]
        -- copyable fields for given entity
        local copyable = entity_copyable_fields[name]
        for _, field in ipairs(copyable) do
            properties[field] = relevant_tags[field]
            -- field setting hooks for given entity
            local hooks = field_setting_hooks[name]
            if hooks and hooks[field] then
                -- calling all hooks
                for _, hook in ipairs(hooks[field]) do
                    hook(properties)
                end
            end
        end
    end

    -- performing necessery on-registration actions
    local hooks = registration_hooks[name]
    if hooks then
        for _, hook in ipairs(hooks) do
            hook(properties)
        end
    end

    -- adding table to registry
    table.insert(reg.array, properties)
    reg.lookup[entity.unit_number] = #reg.array
end

---Removes entity from registry. Used for automatic garbage collection.
---@param unit_number number unique entity identifier
local function unregister_entity(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]

    -- performing unregistration hooks
    local properties = reg.array[index]
    local hooks = unregistration_hooks[properties.name]
    if hooks then
        for _, hook in ipairs(hooks) do
            hook(properties)
        end
    end

    -- rewriting element we want to delete with the last one
    local last_element = reg.array[#reg.array]
    reg.array[index] = last_element
    reg.lookup[last_element.unit_number] = index

    -- removing last element from both tables 
    table.remove(reg.array)
    reg.lookup[unit_number] = nil
end

---@param unit_number number unique entity identifier
---@return EntityProperties|nil properties entity data from registry
function EntityProcessor.get_entity_properties(unit_number)
    local reg = storage.entity_registry
    local index = reg.lookup[unit_number]
    if not index then return end
    return reg.array[index]
end

-------------------------------------------------------------------------------
-- ENTITY DATA SETTERS: PUBLIC API (GUI CALLS)
-------------------------------------------------------------------------------

---Abstract setter. Sets specified property for a given entity or entity-ghost
---@param entity LuaEntity entity for which data should be retrieved
---@param field string field in properties that will be set
---@param value nil|boolean|table|string value to write in properties[field]
---@param ignore_hooks boolean|nil true to ignore field setting hooks
local function set_entity_property(entity, field, value, ignore_hooks)
    if not entity.valid then return end
    if entity.name == "entity-ghost" then
        -- entity is a ghost data stored in tags
        local tags = entity.tags or {}
        tags[ENTITY_TAG_KEY] = tags[ENTITY_TAG_KEY] or {}
        tags[ENTITY_TAG_KEY][field] = value
        entity.tags = tags
    else
        -- entity is not a ghost, information in registry
        local properties = EntityProcessor.get_entity_properties(entity.unit_number)
        if not properties then return end
        properties[field] = value
        if ignore_hooks then return end
        local entity_hooks = field_setting_hooks[entity.name]
        if not entity_hooks then return end
        local hooks = entity_hooks[field]
        if not hooks then return end
        for _, hook in ipairs(hooks) do
            ---@diagnostic disable-next-line: param-type-mismatch
            hook(properties)
        end
    end
end

---Sets selected template for given entity or entity-ghost
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear
function EntityProcessor.set_selected_template(entity, template_name)
    set_entity_property(entity, "selected_template", template_name)
end

---Sets selected item for given entity or entity-ghost
---@param entity LuaEntity
---@param name string|nil name of selected item
---@param quality string|nil quality of selected item
function EntityProcessor.set_selected_item(entity, name, quality)
    local item_data = (name and quality and {name = name, quality = quality}) or nil
    set_entity_property(entity, "selected_item", item_data)
end

---Sets selected fluid for given entity or entity-ghost
---@param entity LuaEntity
---@param fluid_name string|nil name of the fluid, or nil to clear
function EntityProcessor.set_selected_fluid(entity, fluid_name)
    local fluid_data = fluid_name and {name = fluid_name} or nil
    set_entity_property(entity, "selected_fluid", fluid_data)
end

---Sets output flag for given entity or entity-ghost
---@param entity LuaEntity
---@param is_output boolean|nil
function EntityProcessor.set_output_flag(entity, is_output)
    set_entity_property(entity, "is_output", is_output)
end

---Sets source template name for given entity
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear
function EntityProcessor.set_source_template(entity, template_name)
    set_entity_property(entity, "source_template", template_name)
end

---Sets destination template name for given entity
---@param entity LuaEntity
---@param template_name string|nil value to set or nil to clear 
function EntityProcessor.set_destination_template(entity, template_name)
    set_entity_property(entity, "destination_template", template_name)
end

---Sets mode of operation for given entity
---@param entity LuaEntity
---@param mode "item"|"fluid"|"energy" mode of operation
function EntityProcessor.set_mode(entity, mode)
    -- when changing mode we also want to cleanup unused information
    -- for instance, when item mode is chosen, selected fluid is cleared
    if mode ~= "item" then
        set_entity_property(entity, "selected_item", nil, true)
    end
    if mode ~= "fluid" then
        set_entity_property(entity, "selected_fluid", nil, true)
    end
    set_entity_property(entity, "mode", mode)
end

-------------------------------------------------------------------------------
-- ENTITY DATA GETTERS: PUBLIC API (GUI CALLS)
-------------------------------------------------------------------------------

---Abstract getter. Gets specified property for a given entity.
---@param entity LuaEntity entity for which data should be retrieved
---@param field string field in properties that is retrieved
---@return any property for table returns reference, not a copy
local function get_entity_property(entity, field)
    if not entity.valid then return end
    if entity.name == "entity-ghost" then
        -- entity is a ghost data stored in tags
        local tags = entity.tags
        if not tags or not tags[ENTITY_TAG_KEY] then return end
        return tags[ENTITY_TAG_KEY][field]
    else
        -- entity is not a ghost, information in registry
        local properties = EntityProcessor.get_entity_properties(entity.unit_number)
        if not properties then return end
        return properties[field]
    end
end

---Gets selected template for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil template_name
function EntityProcessor.get_selected_template(entity)
    return get_entity_property(entity, "selected_template")
end

---Gets selected item for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil name, string|nil quality  
function EntityProcessor.get_selected_item(entity)
    local selected_item = get_entity_property(entity, "selected_item")
    if not selected_item then return end
    return selected_item.name, selected_item.quality
end

---Gets selected fluid for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return string|nil fluid_name
function EntityProcessor.get_selected_fluid(entity)
    local fluid = get_entity_property(entity, "selected_fluid")
    return fluid and fluid.name
end

---Gets output flag for given entity or ghost-entity
---@param entity LuaEntity entity for which data should be retrieved
---@return boolean|nil is_output
function EntityProcessor.get_output_flag(entity)
    return get_entity_property(entity, "is_output")
end

---Gets source template name for given entity
---@param entity LuaEntity
---@return string|nil template_name
function EntityProcessor.get_source_template(entity)
    return get_entity_property(entity, "source_template")
end

---Gets destination template name for given entity
---@param entity LuaEntity
---@return string|nil template_name
function EntityProcessor.get_destination_template(entity)
    return get_entity_property(entity, "destination_template")
end

---Gets mode of operation for a given entity
---If mode is not in properties, defaults to "item"
---@param entity LuaEntity
---@return "item"|"fluid"|"energy" mode
function EntityProcessor.get_mode(entity)
    local mode = get_entity_property(entity, "mode")
    return mode or "item"
end

---List of entities for which item selection is always enabled
local item_selection_always_enabled = {
    [PREFIX .. "template-item-io-mk1"] = true,
    [PREFIX .. "template-item-io-mk2"] = true,
    [PREFIX .. "template-item-io-mk3"] = true,
    [PREFIX .. "cluster-item-io-mk1"] = true,
    [PREFIX .. "cluster-item-io-mk2"] = true,
    [PREFIX .. "cluster-item-io-mk3"] = true,
}

---Decides if item selection should be enabled for given entity.
---Always returns true except for entities with mode set to not "item"
---@return boolean is_enabled true if item selection should be enabled
function EntityProcessor.get_item_selection_enabled(entity)
    local name = (entity.name == "entity-ghost" and entity.ghost_name) or entity.name
    if item_selection_always_enabled[name] then return true end
    local mode = EntityProcessor.get_mode(entity)
    if mode ~= "item" then return false end
    return true
end

---List of entities for which fluid selection is always enabled
local fluid_selection_always_enabled = {
    [PREFIX .. "template-fluid-io-mk1"] = true,
    [PREFIX .. "template-fluid-io-mk2"] = true,
    [PREFIX .. "template-fluid-io-mk3"] = true,
    [PREFIX .. "cluster-fluid-io-mk1"] = true,
    [PREFIX .. "cluster-fluid-io-mk2"] = true,
    [PREFIX .. "cluster-fluid-io-mk3"] = true,
}

---Decides if fluid selection should be enabled for given entity.
---Always returns true except for entities with mode set to not "fluid"
---@return boolean is_enabled true if fluid selection should be enabled
function EntityProcessor.get_fluid_selection_enabled(entity)
    local name = (entity.name == "entity-ghost" and entity.ghost_name) or entity.name
    if fluid_selection_always_enabled[name] then return true end
    local mode = EntityProcessor.get_mode(entity)
    if mode ~= "fluid" then return false end
    return true
end

-------------------------------------------------------------------------------
-- COPY PASTE
-------------------------------------------------------------------------------

---Adds tags to entities when player creates blueprint
---@param event EventData.on_player_setup_blueprint
function EntityProcessor.setup_blueprint_tags(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local blueprint = event.stack
    if not blueprint then return end
    -- maps blueprint entity index to "real world" entity
    local mapping = event.mapping.get()

    for b_entity_index, entity in ipairs(mapping) do
        if not entity or not entity.valid then goto continue end
        -- skipping entities that are not recognized by this registry
        if not entity_router[entity.name] then goto continue end

        -- if registry does not have entity properties we have to skip it
        local properties = EntityProcessor.get_entity_properties(entity.unit_number)
        if not properties then goto continue end

        -- creating a shallow copy with all copyable properties
        local properties_copy = {}
        local copyable_fields = entity_copyable_fields[entity.name]
        for _, field in ipairs(copyable_fields) do
            properties_copy[field] = properties[field]
        end
        blueprint.set_blueprint_entity_tag(b_entity_index, ENTITY_TAG_KEY, properties_copy)

        ::continue::
    end
end

-- TODO: improve user experience???
-- on_blueprint_settings_pasted
-- on_entity_cloned
-- on_entity_settings_pasted
-- on_player_configured_blueprint
-- on_redo_applied (maybe?)
-- on_undo_applied (maybe?)

-------------------------------------------------------------------------------
-- MAIN PROCESSOR
-------------------------------------------------------------------------------

---On-tick entity processor
---@param event EventData.on_tick
function EntityProcessor.process_entities(event)
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
            unregister_entity(properties.unit_number)
        end
    end
end

return EntityProcessor