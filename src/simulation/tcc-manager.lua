--[[
Template control center is a building that serves a purpose of central hub
needed for template compilation. It's vital for operation of the template system.
This file contains logic necessery to control this system.

Template control manager consists of 3 parts:

I. Hub manager. In order to system to function in any capacity, template control center
entity must exist on proper surface (aquilo), have enough electric energy, etc.
Hub manager is needed to keep track of tcc entity. It's tier, existance, surface it's
located on, etc. If control center entity is not registered (or is unregistered),
computation and all compiled templates temporaty become inaccesible.

II. Computation manager. Computation is a resource required to sustain the existence of
virtualization surfaces as well as for their compilation. It's a flow variable and can't
be stored in any way. Manager allows to control required and available computation. Also
can be used to conveniently get computation-related information.

III. Template storage. Templates are essentially black-box mathematical models of a
production line with defined inputs, outputs, construction costs, etc. Each template
has a display name that is shown to the user and unique identifier that is assigned to
the template at the moment of creation and can't be changed. Templates are used by
virtualization clusters to "craft" template outputs from template inputs. Another
important thing to keep in mind is that templates must be transmitted to the cluster
in order for it to craft. So template storage also has template routing tables.
--]]


local TCCManager = {}

-------------------------------------------------------------------------------
--------------------------- CONTROL CENTER MANAGER ----------------------------
-------------------------------------------------------------------------------

---Used to store template control center data
---@class TCCData
---@field allowed_surface string name of surface tcc can work on
---@field registered boolean|nil true if tcc is currently registered
---@field unit_number integer|nil unit number of registered tcc
---@field surface_index integer|nil identifier of the surface tcc is located on
---@field pos_x number|nil x-coordinate of template control center entity
---@field pos_y number|nil y-coordinate of template control center entity
---@field proximity_dist number|nil maximum distance from which entities
---that require tcc proximity to work can interact with it.


---Gets name of surface allowed for operation of template control center
---and all buildings related to it.
function TCCManager.get_allowed_surface()
    return storage.tcc.allowed_surface
end

---Attempts to register template control center.
---Registration will fail only when there is another registered tcc.
---Assuming that surface is allowed (must be checked by function above).
---@param unit_number integer unique entity identifier
---@param surface_index integer unique surface identifier
---@param entity_x number x-coordinate of entity
---@param entity_y number y-coordinate of entity
---@param proximity_dist number maximum distance
---@return boolean status true if entity was registered
function TCCManager.register_control_center(
    unit_number,
    surface_index,
    entity_x,
    entity_y,
    proximity_dist
)
    local tcc = storage.tcc
    -- another tcc is already registered: return
    if tcc.registered then return false end

    -- everything is ok: registering
    tcc.registered = true
    tcc.unit_number = unit_number
    tcc.surface_index = surface_index
    tcc.pos_x = entity_x
    tcc.pos_y = entity_y
    tcc.proximity_dist = proximity_dist * proximity_dist
    return true
end

---Unregisteres template control center given its unit number.
---@param unit_number integer unique entity identifier
function TCCManager.unregister_control_center(unit_number)
    local tcc = storage.tcc
    -- safety check: unit numbers must match
    if tcc.unit_number ~= unit_number then return end

    tcc.registered = nil
    tcc.unit_number = nil
    tcc.surface_index = nil
    tcc.pos_x = nil
    tcc.pos_y = nil
    tcc.proximity_dist = nil
end

---Checks if given point on a surface is in close proximity to tcc.
---@param surface_index integer unique surface identifier
---@param x number x-coordinate of a point checked
---@param y number y-coordinate of a point checked
---@return boolean status true if point within proximity range
function TCCManager.in_proximity_to_tcc(surface_index, x, y)
    local tcc = storage.tcc
    -- checking that tcc is registered
    if not tcc.registered then return false end
    -- surfaces are different: no proximity
    if tcc.surface_index ~= surface_index then return false end
    -- checking distance from given point to tcc
    local dist = (tcc.pos_x - x)^2 + (tcc.pos_y - y)^2
    return dist <= tcc.proximity_dist
end

---Checks if template control center is currently registered
---@return boolean true if tcc is available
local function is_tcc_registered()
    return storage.tcc.registered
end

-------------------------------------------------------------------------------
----------------------------- COMPUTATION MANAGER -----------------------------
-------------------------------------------------------------------------------

---Used to storage computation resource data
---@class ComputationStorage
---@field max_available number max amount of computation potentially available
---@field curr_demand number current computation demand

---Gets maximum available amount of computation
---@return number max_available
function TCCManager.get_computation_max_available()
    return storage.computation.max_available
end

---Gets current computation demand
---@return number curr_demand
function TCCManager.get_computation_curr_demand()
    return storage.computation.curr_demand
end

---Gets the amount of currently available computation
---@return number available can not be negative
function TCCManager.get_available_computation()
    local computation = storage.computation
    local available = math.max(
        computation.max_available - computation.curr_demand,
        0
    )
    return available
end

---Checks if there is enough computation resource.
---@return boolean status true if computation is sufficient
function TCCManager.is_computation_sufficient()
    -- computation cannot be sufficient if tcc is not registered
    if not is_tcc_registered() then return false end
    local computation = storage.computation
    return computation.curr_demand < computation.max_available
end

---Gets current computation demand ratio: fraction of computation
---currently required from providers.
---@return number fraction from the range [0, 1]
function TCCManager.get_computation_demand_ratio()
    local computation = storage.computation
    local max = computation.max_available
    if max == 0 then return 0 end
    return math.min(computation.curr_demand / max, 1)
end

---Adds provided amount to max available computation
---@param amount number amount of computation to add (must be positive)
function TCCManager.increase_computation_max_available(amount)
    local computation = storage.computation
    computation.max_available = computation.max_available + amount
end

---Removes provided amount from max available computation
---@param amount number amount of computation to remove (must be positive)
function TCCManager.decrease_computation_max_available(amount)
    local computation = storage.computation
    local result = computation.max_available - amount
    if result < 1e-6 then result = 0 end
    computation.max_available = result
end

---Adds provided amount to computation current demand
---@param amount number amount of computation to add (must be positive)
function TCCManager.increase_computation_curr_demand(amount)
    local computation = storage.computation
    computation.curr_demand = computation.curr_demand + amount
end

---Removes provided amount from computation current demand
---@param amount number amount of computation to remove (must be positive)
function TCCManager.decrease_computation_curr_demand(amount)
    local computation = storage.computation
    local result = computation.curr_demand - amount
    if result < 1e-6 then result = 0 end
    computation.curr_demand = result
end

-------------------------------------------------------------------------------
------------------------------ TEMPLATE STORAGE -------------------------------
-------------------------------------------------------------------------------

---@alias cluster_uuid string cluster identifier, assigned at creation
---@alias template_uuid string template identifier, assigned at creation
---@alias template_name string display name of template that is shown to player
---@alias surface_index integer unique surface identifier
---Both uuid and display name must be unique among all templates

---Contains data of one compiled template
---@class TemplateData
---@field input table<BufferKeyString, number> input per second
---@field output table<BufferKeyString, number> output per second
---@field building_cost table<BufferKeyString, number> items needed for
---construction of this template
---@field energy_drain number energy drain of this template

---Contains data of all compiled templates
---@class TemplateStorage
---@field template_lookup table<template_uuid, TemplateData>
---@field name_to_uuid table<template_name, template_uuid>
---@field uuid_to_name table<template_uuid, template_name>
---Template routing tables:
---@field transmit table<template_uuid, table<cluster_uuid, boolean>>
---@field transmit_inv table<cluster_uuid, template_uuid>
---@field receive table<template_uuid, table<cluster_uuid, boolean>>
---@field receive_inv table<cluster_uuid, template_uuid>

--------------------------- CREATE RENAME DELETE ---------------------------

---Generates uuid for template for internal use.
---@param name template_name display name that is shown to player
---@return template_uuid uuid unique template identifier 
local function generate_template_uuid(name)
    local uuid = string.format(
        "%s/%d/%.9f",
        name,
        game.tick,
        math.random()
    )
    return uuid
end

---Saves given template to template storage
---@param template TemplateData
---@param name template_name display name
function TCCManager.add_template(template, name)
    ---@type TemplateStorage
    local templates = storage.templates

    -- making sure that name is not occupied
    local name_to_uuid = templates.name_to_uuid
    local unique_name = name
    local suffix = 1
    while name_to_uuid[unique_name] do
        unique_name = string.format("%s (%d)", name, suffix)
        suffix = suffix + 1
    end

    -- generating template uuid and saving template to storage
    local uuid = generate_template_uuid(unique_name)
    templates.template_lookup[uuid] = template
    name_to_uuid[unique_name] = uuid
    templates.uuid_to_name[uuid] = unique_name
end

---Checks if template can be renamed.
---@param old_name template_name|nil
---@param new_name template_name|nil
---@return boolean status true if template can be renamed
---@return LocalisedString|nil reason why template can not be renamed
function TCCManager.can_rename_template(old_name, new_name)
    -- checking that old name is provided
    if not old_name then
        return false, {"tcc-manager.old-name-missing"}
    end
    -- checking that new name is not empty
    if not new_name or not string.find(new_name, "%S", 1, false) then
        return false, {"tcc-manager.new-name-empty"}
    end
    -- checking that names are different
    if new_name == old_name then
        return false, {"tcc-manager.names-not-different"}
    end
    -- checking that new name is not occupied
    local templates = storage.templates
    local name_to_uuid = templates.name_to_uuid
    if name_to_uuid[new_name] then
        return false, {"tcc-manager.new-name-occupied"}
    end
    -- checking that template with old name exists in storage
    if not name_to_uuid[old_name] then
        return false, {"tcc-manager.old-name-no-data"}
    end
    return true
end

---Changes display name for a given template
---@param old_name template_name|nil
---@param new_name template_name|nil
---@return boolean status true if template was successfully renamed
---@return LocalisedString|nil reason error string if rename failed
function TCCManager.rename_template(old_name, new_name)
    local status, reason = TCCManager.can_rename_template(old_name, new_name)
    if not status then return false, reason end
    ---@cast old_name string
    ---@cast new_name string

    ---@type TemplateStorage
    local templates = storage.templates
    local name_to_uuid = templates.name_to_uuid
    local uuid = name_to_uuid[old_name]

    -- everything is ok: renaming template
    name_to_uuid[new_name] = uuid
    name_to_uuid[old_name] = nil
    templates.uuid_to_name[uuid] = new_name
    return true
end

---Deletes provided template from storage
---@param template_name template_name|nil display name
---@return boolean status true if deletion was successful
---@return LocalisedString|nil reason error string if deletion failed
function TCCManager.delete_template(template_name)
    -- checking that template name is provided
    if not template_name then
        return false, {"tcc-manager.deletion-error-no-name"}
    end

    -- checking that template exists in storage
    ---@type TemplateStorage
    local templates = storage.templates
    local name_to_uuid = templates.name_to_uuid
    local template_uuid = name_to_uuid[template_name]
    if not template_uuid then
        return false, {"tcc-manager.deletion-error-no-data"}
    end

    -- Data is found: erasing it from all tables
    templates.template_lookup[template_uuid] = nil
    templates.uuid_to_name[template_uuid] = nil
    name_to_uuid[template_name] = nil

    -- Erasing template from transmission tables
    local transmit = templates.transmit
    local transmit_inv = templates.transmit_inv
    local clusters = transmit[template_uuid]
    if clusters then
        for cluster_uuid, _ in pairs(clusters) do
            transmit_inv[cluster_uuid] = nil
        end
        transmit[template_uuid] = nil
    end
    -- Erasing template from receive tables
    local receive = templates.receive
    local receive_inv = templates.receive_inv
    clusters = receive[template_uuid]
    if clusters then
        for cluster_uuid, _ in pairs(clusters) do
            receive_inv[cluster_uuid] = nil
        end
        receive[template_uuid] = nil
    end
    return true
end

------------------------------ TEMPLATE ROUTING -------------------------------

---Adds the transmitter of provided template to provided cluster
---Only one template can be transmitted to cluster at a time
---@param template_uuid template_uuid unique template identifier
---@param cluster_uuid cluster_uuid unique cluster identifier
---@return boolean status true if transmitter was added successfully
function TCCManager.add_template_transmitter(template_uuid, cluster_uuid)
    ---@type TemplateStorage
    local templates = storage.templates
    local transmit = templates.transmit
    local transmit_inv = templates.transmit_inv
    -- checking that cluster does not have another bound template
    if transmit_inv[cluster_uuid] then return false end
    -- everything ok: saving this transmitter
    transmit_inv[cluster_uuid] = template_uuid
    transmit[template_uuid] = transmit[template_uuid] or {}
    transmit[template_uuid][cluster_uuid] = true
    return true
end

---Removes a transmitter of template from provided cluster.
---Can be safely called if no template is being transmitted to the cluster. 
---@param cluster_uuid cluster_uuid
function TCCManager.remove_template_transmitter(cluster_uuid)
    ---@type TemplateStorage
    local templates = storage.templates
    local transmit = templates.transmit
    local transmit_inv = templates.transmit_inv
    local template_uuid = transmit_inv[cluster_uuid]
    if not template_uuid then return end
    -- template_uuid found: removing this transmitter
    transmit_inv[cluster_uuid] = nil
    transmit[template_uuid][cluster_uuid] = nil
    if not next(transmit[template_uuid]) then
        transmit[template_uuid] = nil
    end
end

---Adds the reciever of provided template to provided cluster
---Only one template can be transmitted to cluster at a time
---@param template_uuid template_uuid unique template identifier
---@param cluster_uuid cluster_uuid unique cluster identifier
---@return boolean status true if receiver was added successfully
function TCCManager.add_template_receiver(template_uuid, cluster_uuid)
    ---@type TemplateStorage
    local templates = storage.templates
    local receive = templates.receive
    local receive_inv = templates.receive_inv
    -- checking that cluster does not have another bound template
    if receive_inv[cluster_uuid] then return false end
    -- everything ok: saving this receiver
    receive_inv[cluster_uuid] = template_uuid
    receive[template_uuid] = receive[template_uuid] or {}
    receive[template_uuid][cluster_uuid] = true
    return true
end

---Removes a receiver of template from provided cluster.
---Can be safely called if no template is being received by the cluster. 
---@param cluster_uuid cluster_uuid
function TCCManager.remove_template_receiver(cluster_uuid)
    ---@type TemplateStorage
    local templates = storage.templates
    local receive = templates.receive
    local receive_inv = templates.receive_inv
    local template_uuid = receive_inv[cluster_uuid]
    if not template_uuid then return end
    -- template_uuid found: removing this receiver
    receive_inv[cluster_uuid] = nil
    receive[template_uuid][cluster_uuid] = nil
    if not next(receive[template_uuid]) then
        receive[template_uuid] = nil
    end
end

---Removes a cluster from template routing tables
---@param cluster_uuid cluster_uuid unique cluster identifier
function TCCManager.remove_cluster_routing(cluster_uuid)
    TCCManager.remove_template_transmitter(cluster_uuid)
    TCCManager.remove_template_receiver(cluster_uuid)
end

-------------------------------------------------------------------------------
---------------------------- TEMPLATE INFO GETTERS ----------------------------
-------------------------------------------------------------------------------

----------------------------------- BACKEND -----------------------------------

---Checks if given template uuid corresponds to an existing template
---@param template_uuid string unique template identifier
---@return boolean status true if template exists
function TCCManager.does_template_exist(template_uuid)
    return not not storage.templates.template_lookup[template_uuid]
end

---Gets uuid of template assigned to the given cluster.
---@param cluster_uuid cluster_uuid unique cluster identifier
---@return template_uuid|nil template_uuid id of assigned template
---@return TemplateData|nil template assigned template data
function TCCManager.get_assigned_template(cluster_uuid)
    if not is_tcc_registered() then return end
    ---@type TemplateStorage
    local templates = storage.templates
    local transmit_inv = templates.transmit_inv
    local receive_inv = templates.receive_inv
    local transmit_uuid = transmit_inv[cluster_uuid]
    if not transmit_uuid then return end
    local receive_uuid = receive_inv[cluster_uuid]
    if not receive_uuid then return end
    if transmit_uuid == receive_uuid then
        return transmit_uuid, templates.template_lookup[transmit_uuid]
    end
end

------------------------------------- GUI -------------------------------------

---Checks if given template is active. Template is considered active if it
---appears at least in one routing table.
---@param template_name template_name|nil display name
---@return boolean status true if template is found and active
function TCCManager.is_template_active(template_name)
    if not template_name then return false end
    ---@type TemplateStorage
    local templates = storage.templates
    local uuid = templates.name_to_uuid[template_name]
    if not uuid then return false end
    if templates.receive[uuid] or templates.transmit[uuid] then return true end
    return false
end

---Checks if given template is inactive. Template is considered inactive if it
---does not appear in routing tables.
---@param template_name template_name|nil display name
---@return boolean status true if template is found and inactive
function TCCManager.is_template_inactive(template_name)
    if not template_name then return false end
    ---@type TemplateStorage
    local templates = storage.templates
    local uuid = templates.name_to_uuid[template_name]
    if not uuid then return false end
    if templates.receive[uuid] or templates.transmit[uuid] then return false end
    return true
end

---Collects names of all inactive templates that match with provided query.
---Names are returned in random order.
---@param query string|nil search query
---@return string[]
function TCCManager.get_inactive_template_names(query)
    ---@type TemplateStorage
    local templates = storage.templates
    local receive = templates.receive
    local transmit = templates.transmit
    local result = {}

    local has_query = query and string.find(query, "%S", 1, false)
    for name, uuid in pairs(templates.name_to_uuid) do
        -- collecting templates that do not appear in routing tables
        if not receive[uuid] and not transmit[uuid] then
            -- collecting templates that match with query
            ---@diagnostic disable-next-line
            if not has_query or string.find(name, query, 1, true) then
                table.insert(result, name)
            end
        end
    end
    return result
end

---Collects names of all active templates that match with provided query.
---Names are returned in random order.
---@param query string|nil search query
---@return string[]
function TCCManager.get_active_template_names(query)
    ---@type TemplateStorage
    local templates = storage.templates
    local receive = templates.receive
    local transmit = templates.transmit
    local result = {}
    local has_query = query and string.find(query, "%S", 1, false)
    for name, uuid in pairs(templates.name_to_uuid) do
        -- collection templates that appear at least once in routing tables
        if receive[uuid] or transmit[uuid] then
            -- collecting templates that match with query
            ---@diagnostic disable-next-line
            if not has_query or string.find(name, query, 1, true) then
                table.insert(result, name)
            end
        end
    end
    return result
end

---Collects uuids of all clusters given template is transmitted to.
---Uuids are returned in random order.
---@param template_name template_name|nil display name
---@return string[] uuids
function TCCManager.get_transmit_cluster_uuids(template_name)
    if not template_name then return {} end
    ---@type TemplateStorage
    local templates = storage.templates
    local template_uuid = templates.name_to_uuid[template_name]
    -- checking that template uuid was found
    if not template_uuid then return {} end
    local cluster_uuids = templates.transmit[template_uuid]
    -- checking that transmit clusters are found
    if not cluster_uuids then return {} end
    local result = {}
    for uuid, _ in pairs(cluster_uuids) do
        table.insert(result, uuid)
    end
    return result
end

---Collects uuids of all clusters given template is received by
---Uuids are returned in random order.
---@param template_name template_name|nil display name
---@return string[] uuids
function TCCManager.get_receive_cluster_uuids(template_name)
    if not template_name then return {} end
    ---@type TemplateStorage
    local templates = storage.templates
    local template_uuid = templates.name_to_uuid[template_name]
    -- checking that template uuid was found
    if not template_uuid then return {} end
    local cluster_uuids = templates.receive[template_uuid]
    -- checking that receiving clusters are found
    if not cluster_uuids then return {} end
    local result = {}
    for uuid, _ in pairs(cluster_uuids) do
        table.insert(result, uuid)
    end
    return result
end

---Gets template data by name
---@param template_name template_name|nil display name
---@return TemplateData|nil
local function get_template_by_name(template_name)
    if not template_name then return end
    ---@type TemplateStorage
    local templates = storage.templates
    local uuid = templates.name_to_uuid[template_name]
    if not uuid then return end
    return templates.template_lookup[uuid]
end

---Gets inputs and energy drain of given template
---@param template_name template_name|nil display name
---@return table<BufferKeyString, number> input, number energy_drain
function TCCManager.get_template_inputs(template_name)
    local template = get_template_by_name(template_name)
    if not template then return {}, 0 end
    return template.input, template.energy_drain
end

---Gets outputs of given template
---@param template_name template_name|nil display name
---@return table<BufferKeyString, number> input
function TCCManager.get_template_outputs(template_name)
    local template = get_template_by_name(template_name)
    if not template then return {} end
    return template.output
end

---Gets building cost of given template
---@param template_name template_name|nil display name
---@return table<BufferKeyString, number> input
function TCCManager.get_template_building_cost(template_name)
    local template = get_template_by_name(template_name)
    if not template then return {} end
    return template.building_cost
end

------------------------------- DEBUG COMMANDS --------------------------------

---Adds several test templates
commands.add_command("add_test_templates", "", function()
    ---@type TemplateData
    local template = {
        input = {
            ["iron-plate//legendary"] = 1234,
            ["copper-plate//normal"] = 800,
            ["advanced-circuit//epic"] = 500,
            ["water"] = 10000,
            ["electric_energy"] = 1e9,
        },
        output = {
            ["iron-gear-wheel//legendary"] = 1234,
            ["processing-unit//epic"] = 10000,
            ["electric_energy"] = 1e10,
        },
        building_cost = {
            ["assembling-machine-3//epic"] = 12,
            ["stack-inserter//uncommon"] = 123,
            ["electric-furnace//rare"] = 70,
        },
        energy_drain = 1e8,
    }
    for i = 1, 2 do
        TCCManager.add_template(template, "test template")
    end
    for i = 1, 2 do
        TCCManager.add_template(
            {input = {}, output = {}, building_cost = {}, energy_drain = 0},
            "empty_template"
        )
    end
end)

---Adds transmitting and receiving clusters to some templates
commands.add_command("add_test_routing", "", function()
    local uuid_to_name = storage.templates.uuid_to_name
    for uuid, _ in pairs(uuid_to_name) do
        local roll = math.random()
        if roll > 0.5 then
            TCCManager.add_template_transmitter(
                uuid,
                string.format("cluster %.2f", roll)
            )
        end
        local roll = math.random()
        if roll > 0.5 then
            TCCManager.add_template_receiver(
                uuid,
                string.format("cluster %.2f", roll)
            )
        end
    end
end)

---Adds enough computation for everything, sets tcc to registered
commands.add_command("computation_editor", "", function()
    storage.tcc.registered = true
    TCCManager.increase_computation_max_available(1e12)
end)


return TCCManager

--[[



---Checks if given template is accessible by given cluster. If template
---control center is unavailable, always returns false
---@param template_uuid template_uuid unique template identifier
---@param cluster_uuid cluster_uuid unique cluster identifier
---@return boolean status true if template is accessible
function TCCManager.is_template_accessible(template_uuid, cluster_uuid)
    -- TODO: if control center unavailable: return false

    ---@type TemplateStorage
    local templates = storage.templates
    local transmit_inv = templates.transmit_inv
    local receive_inv = templates.receive_inv
    if transmit_inv[cluster_uuid] ~= template_uuid then return false end
    if receive_inv[cluster_uuid] ~= template_uuid then return false end
    return true
end

-------------------------------- INFO GETTERS ---------------------------------

function TCCManager.get_template_name()

end

function TCCManager.get_template_uuid()

end






function TCCManager.get_all_template_names(query)
    ---@type TemplateStorage
    local templates = storage.templates
    local result = {}
    if query then
        for name, _ in pairs(templates.name_to_uuid) do
            if string.find(name, query, 1, true) then
                table.insert(result, name)
            end
        end
    else
        for name, _ in pairs(templates.name_to_uuid) do
            table.insert(result, name)
        end
    end
    -- sorting template names in alphabetical order
    table.sort(result)
    return result
end


---Gets building cost of a given template
---@param template_name string|nil unique template identifier
---@return table<BufferKeyString, number> items key is "name//quality"
function TemplateStorage.get_building_cost(template_name)
    if not template_name then return {} end
    local template = storage.templates[template_name]
    if not template then return {} end
    return template.building_cost
end

---Retrieves a compiled template data from storage
---@param template_name string unique template identifier
---@return TemplateData|nil template compiled template data if found
function TemplateCompiler.get_template(template_name)
    return storage.templates[template_name]
end

---Collects names of all compiled templates
---@return string[] names
function TemplateCompiler.get_all_template_names()
    local result = {}
    for name, _ in pairs(storage.templates) do
        table.insert(result, name)
    end
    return result
end

---Gets all inputs of a given template
---@param template_name string|nil unique template identifier
---@return table<BufferKeyString, number> inputs
function TemplateCompiler.get_inputs(template_name)
    if not template_name then return {} end
    local template = storage.templates[template_name]
    if not template then return {} end
    return template.input
end

---Gets all outputs of a given template
---@param template_name string|nil unique template identifier
---@return table<BufferKeyString, number> outputs
function TemplateCompiler.get_outputs(template_name)
    if not template_name then return {} end
    local template = storage.templates[template_name]
    if not template then return {} end
    return template.output
end

---Gets energy consumption and energy drain of a given template
---@param template_name string|nil unique template identifier
---@return number energy_input, number energy_drain 
function TemplateCompiler.get_energy_consumption(template_name)
    if not template_name then return 0, 0 end
    local template = storage.templates[template_name]
    if not template then return 0, 0 end
    local energy_input = template.input.electric_energy or 0
    local energy_drain = template.energy_drain or 0
    return energy_input, energy_drain
end

---Gets energy production of a given template
---@param template_name string|nil unique template identifier
---@return number energy_production
function TemplateCompiler.get_energy_production(template_name)
    if not template_name then return 0 end
    local template = storage.templates[template_name]
    if not template then return 0 end
    return template.output.electric_energy or 0
end

--]]